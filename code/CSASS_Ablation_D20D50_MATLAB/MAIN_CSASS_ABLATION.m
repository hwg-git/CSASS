function MAIN_CSASS_ABLATION(mode,extra)
% D20/D50 only:1800 fixed slots,60 groups. Default run. No automatic retry.
% First run selects full-V2 reuse. Cancel stops; run_independent is explicit.
if nargin<1||isempty(mode),mode='run';end
mode=lower(char(mode));
assert(ismember(mode,{'run','run_independent','plan','preflight','summarize','collect','hv','import'}),...
 'Ablation_D20D50:Mode','Use run, run_independent, plan, preflight, summarize, collect, hv, or import.');
if nargin>=2
 assert(ismember(mode,{'hv','import'}),'Ablation_D20D50:Arguments','Second argument is only for hv/import.');
elseif strcmp(mode,'import'),extra=[];
else,extra=[1.1,3,20];end
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'));
cfg=abl2050_preflight(root);tasks=abl2050_tasks(root);inv=abl2050_inventory(root,tasks);
fprintf('\nD20/D50 ablation:1800 fixed slots,60 groups, no D10 cache. Completed%d (%d computed,%d imported), pending%d, retained%d.\n',...
 inv.Completed,inv.ComputedCompleted,inv.ImportedCompleted,inv.Pending,inv.Retained);
fprintf('Six problems; five modes; D20/50; seeds1:30; N100 FE500 Pmax20 K10.\n');
if ismember(mode,{'plan','preflight'}),return;end
if strcmp(mode,'collect'),abl2050_collect(root);return;end
out=fullfile(root,'outputs','Ablation_D20D50');if ~isfolder(out),mkdir(out);end
[file,lock]=acquire_lock(out);lockGuard=onCleanup(@()close_lock(lock,file)); %#ok<NASGU>
if strcmp(mode,'summarize'),abl2050_summarize(root,true);return;end
if strcmp(mode,'hv'),abl2050_recompute_hv(root,extra);return;end
if strcmp(mode,'import')
 receipt=abl2050_autoimport(root,extra,'select');disp(receipt);
 if strcmp(receipt.Status,'cancelled'),return;end
 abl2050_summarize(root,true);return;
end
start=tic;state=struct('Status','initializing','SessionID',char(java.util.UUID.randomUUID),...
 'PID',feature('getpid'),'StartedUTC',utc_now(),'UpdatedUTC',utc_now(),...
 'Planned',1800,'Cached',0,'TotalPlanned',1800,'Completed',inv.Completed,...
 'AlreadyCompleted',inv.Completed,'ImportedCompleted',inv.ImportedCompleted,...
 'ComputedCompleted',inv.ComputedCompleted,'SessionCompleted',0,'FailedThisSession',0,...
 'Pending',inv.Pending,'NeverStarted',inv.Pending,'CurrentID','','RunningIDs',{{}},...
 'ElapsedSeconds',0,'FreeMemoryGB',NaN,'FreeDiskGB',NaN,'ResourceWaitSeconds',0,...
 'SourceLockSHA256',abl2050_io('sha',fullfile(root,'source_lock.json')),...
 'ProtocolSHA256',abl2050_io('sha',fullfile(root,'protocol.json')),'Message','','Errors',{{}});
statusPath=fullfile(out,'status.json');abl2050_io('writejson',statusPath,state);
interruptGuard=onCleanup(@()mark_interrupted(statusPath,state.SessionID)); %#ok<NASGU>
futures=[];futureGuards={};futureIDs={};pool=[];ownedPool=false;
next=1;newCompleted=0;failed=0;stopDispatch=false;stopReason='';errors={};
resourcePaused=false;resourceWait=[];lastResourceStatus=-Inf;allComplete=false;
try
 assert(exist('ranksum','file')==2&&license('test','Statistics_Toolbox'),...
  'Ablation_D20D50:StatisticsToolbox','Statistics and Machine Learning Toolbox with ranksum is required before dispatch.');
 % Reuse completes before creating a pool. Busy/incomplete source is fatal
 % for this start, rather than silently recomputing overlapping adaptive runs.
 state.Status='verifying_reuse';state.Message='Verify local imports or select source; cancellation stops before scientific dispatch.';
 state.UpdatedUTC=utc_now();abl2050_io('writejson',statusPath,state);
 if inv.Completed==1800 && inv.Retained==0
  reuse=struct('Status','all_local_complete');
  % Every local file is independently hashed in the final audit below.
 elseif strcmp(mode,'run_independent')
  reuse=abl2050_autoimport(root,[],'independent');
 else
  reuse=abl2050_autoimport(root,[],'resume');
 end
 state.ReuseStatus=reuse.Status;
 if strcmp(reuse.Status,'cancelled')
  state.Status='cancelled_before_run';state.Message='Source selection cancelled. No independent policy written; no pool or experiment started.';
  state.EndedUTC=utc_now();state.UpdatedUTC=utc_now();abl2050_io('writejson',statusPath,state);return;
 end
 inv=abl2050_inventory(root,tasks);
 assert(inv.Retained==0,'Ablation_D20D50:RetainedTrial',...
  'Unfinished/failed records retained; no automatic retry. Review: %s',strjoin(inv.RetainedIDs,', '));
 pending=tasks(inv.PendingMask);state.AlreadyCompleted=inv.Completed;state.Completed=inv.Completed;
 state.ImportedCompleted=inv.ImportedCompleted;state.ComputedCompleted=inv.ComputedCompleted;
 state.Pending=numel(pending);state.NeverStarted=numel(pending);
 state.Status='running';state.Message='Reuse choice verified; fixed unfinished task manifest ready.';
 state.UpdatedUTC=utc_now();abl2050_io('writejson',statusPath,state);
 if ~isempty(pending)
  assert(license('test','Distrib_Computing_Toolbox')&&exist('parpool','file')==2,...
   'Ablation_D20D50:ParallelToolbox','Parallel Computing Toolbox is required for six process workers.');
  [canStart,state]=wait_before_pool(out,state,statusPath,start,cfg);
  if ~canStart,return;end
  pool=gcp('nocreate');
  if ~isempty(pool)
   assert(pool_idle(pool),'Ablation_D20D50:BusyPool','Existing pool is busy; no other jobs will be cancelled.');
   if isa(pool,'parallel.ThreadPool')||pool.NumWorkers~=6||~isprop(pool,'Cluster')||~isa(pool.Cluster,'parallel.cluster.Local')
    delete(pool);pool=[];
   end
  end
  if isempty(pool),pool=start_process_pool();ownedPool=true;end
  assert(~isa(pool,'parallel.ThreadPool')&&pool.NumWorkers==6&&...
   isprop(pool,'Cluster')&&isa(pool.Cluster,'parallel.cluster.Local'),...
   'Ablation_D20D50:PoolType','Exactly six local process workers required.');
  addAttachedFiles(pool,{fullfile(root,'code')});futures=parallel.FevalFuture.empty(0,1);
  fprintf('ACTUAL CONCURRENCY:6 local process workers;1 compute thread per trial. Remaining%d.\n',numel(pending));
 end
 poolGuard=onCleanup(@()close_owned_idle_pool(pool,ownedPool)); %#ok<NASGU>
 while (~stopDispatch&&next<=numel(pending))||~isempty(futures)
  if ~stopDispatch&&toc(start)>=cfg.MaxWallHours*3600
   stopDispatch=true;stopReason='session_wall_limit';state.Status='draining';
   state.Message='72-hour session ceiling reached; started trials finish naturally.';
  end
  % Once low resources are detected, drain current trials first. Only then
  % wait up to30 minutes, without launching or killing any other process.
  if ~stopDispatch&&resourcePaused&&isempty(futures)
   if isempty(resourceWait),resourceWait=tic;end
   [ram,disk]=resource_snapshot(out);state.FreeMemoryGB=ram;state.FreeDiskGB=disk;
   state.ResourceWaitSeconds=toc(resourceWait);
   if ram>2&&disk>5
    resourcePaused=false;resourceWait=[];state.Status='running';
    state.Message='Resource threshold recovered; continue fixed pending tasks.';
   elseif toc(resourceWait)>=1800
    stopDispatch=true;stopReason='resource_wait_limit';
    state.Message='Resources remained insufficient for30 minutes after queue drained; unfinished tasks retained.';
   else
    state.Status='awaiting_resources';state.ElapsedSeconds=toc(start);state.UpdatedUTC=utc_now();
    state.Message=sprintf('Queue drained; waiting for RAM>2GiB/disk>5GiB (now %.3f/%.3f).',ram,disk);
    state.RunningIDs={};abl2050_io('writejson',statusPath,state);
    pause(min([15,max(0,1800-toc(resourceWait)),max(0,cfg.MaxWallHours*3600-toc(start))]));continue;
   end
  end
  readyToRead=~isempty(futures)&&any(arrayfun(@(f)strcmp(f.State,'finished'),futures));
  while ~stopDispatch&&~resourcePaused&&~readyToRead&&next<=numel(pending)&&numel(futures)<6
   [ram,disk]=resource_snapshot(out);state.FreeMemoryGB=ram;state.FreeDiskGB=disk;
   if ram<=2||disk<=5
    resourcePaused=true;resourceWait=[];state.Status='draining_resources';
    state.Message=sprintf('Pause dispatch; RAM %.3fGiB, disk %.3fGiB. Let started trials finish.',ram,disk);
    state.RunningIDs=futureIDs;state.UpdatedUTC=utc_now();abl2050_io('writejson',statusPath,state);break;
   end
   task=pending(next);
   try,f=parfeval(pool,@abl2050_trial,1,root,task);
   catch e
    stopDispatch=true;stopReason='dispatch_error';errors{end+1}=getReport(e,'extended','hyperlinks','off'); %#ok<AGROW>
    state.Status='draining';state.Message='Dispatch error; in-flight tasks finish naturally.';break;
   end
   next=next+1;futures(end+1)=f;futureIDs{end+1}=task.ID; %#ok<AGROW>
   futureGuards{end+1}=onCleanup(@()cancel_one(f)); %#ok<AGROW>
   state.CurrentID=task.ID;state.RunningIDs=futureIDs;state.NeverStarted=numel(pending)-next+1;
   state.UpdatedUTC=utc_now();abl2050_io('writejson',statusPath,state);
  end
  if isempty(futures)
   if resourcePaused&&~stopDispatch,continue;else,break;end
  end
  index=find(arrayfun(@(f)strcmp(f.State,'finished'),futures),1);
  if isempty(index)
   if resourcePaused&&toc(start)-lastResourceStatus>=15
    state.RunningIDs=futureIDs;state.ElapsedSeconds=toc(start);state.UpdatedUTC=utc_now();
    abl2050_io('writejson',statusPath,state);lastResourceStatus=toc(start);
   end
   pause(0.25);continue;
  end
  expectedID=futureIDs{index};f=futures(index);
  futures(index)=[];futureIDs(index)=[];futureGuards(index)=[];
  try
   r=fetchOutputs(f);t=tasks(strcmp({tasks.ID},expectedID));
   assert(isscalar(t)&&isstruct(r)&&strcmp(r.status,'completed')&&strcmp(r.ID,expectedID)&&...
    strcmp(r.Mode,t.Mode)&&r.D==t.D&&r.Seed==t.Seed&&r.FE==500,...
    'Ablation_D20D50:TrialIdentity','Unexpected returned task result/status/mode/budget.');
   assert(isfile(fullfile(out,'runs',expectedID,'completed.json')),'Ablation_D20D50:Marker','Missing completion marker.');
   newCompleted=newCompleted+1;state.CurrentID=expectedID;
   fprintf('[%d/%d this session; %d/1800 total] %s | IGD10000=%g HV1.1=%g feasibleND=%d\n',...
    newCompleted,numel(pending),inv.Completed+newCompleted,expectedID,r.IGD10000,r.HVr1p1,r.FeasibleND);
  catch e
   failed=failed+1;stopDispatch=true;if isempty(stopReason),stopReason='trial_error';end
   errors{end+1}=sprintf('%s: %s',expectedID,getReport(e,'extended','hyperlinks','off')); %#ok<AGROW>
   state.Status='draining';state.Message='Trial failed; no new dispatch. Started tasks finish and preserve records.';
   fprintf(2,'FAILED %s: %s\n',expectedID,e.message);
  end
  state.SessionCompleted=newCompleted;state.FailedThisSession=failed;state.Completed=inv.Completed+newCompleted;
  state.ComputedCompleted=inv.ComputedCompleted+newCompleted;state.Pending=1800-state.Completed;
  state.NeverStarted=numel(pending)-next+1;state.RunningIDs=futureIDs;
  state.ElapsedSeconds=toc(start);state.UpdatedUTC=utc_now();abl2050_io('writejson',statusPath,state);
  if newCompleted>0&&failed==0&&~resourcePaused&&mod(newCompleted,30)==0
   try
    a=abl2050_summarize(root,mod(newCompleted,300)==0);
    if mod(newCompleted,300)==0,assert(a.ExcelWritten,'Ablation_D20D50:Excel','Full summary did not write results.xlsx.');end
   catch e
    stopDispatch=true;stopReason='summary_error';state.Status='draining';
    errors{end+1}=getReport(e,'extended','hyperlinks','off'); %#ok<AGROW>
    state.Message='Summary/audit failed; no new dispatch; started tasks finish naturally.';
    abl2050_io('writejson',statusPath,state);
   end
  end
 end
 final=abl2050_inventory(root,tasks);state.Completed=final.Completed;state.Pending=final.Pending;
 state.ImportedCompleted=final.ImportedCompleted;state.ComputedCompleted=final.ComputedCompleted;
 state.RetainedUnfinished=final.Retained;state.RunningIDs={};state.ElapsedSeconds=toc(start);
 allComplete=~stopDispatch&&final.Completed==1800&&final.Retained==0;
 if allComplete
  state.Status='final_audit';state.Message='All1800 records complete; running final artifact/statistical audit.';
  state.UpdatedUTC=utc_now();abl2050_io('writejson',statusPath,state);
  a=abl2050_summarize(root,true);
  assert(strcmp(a.Status,'pass')&&a.AllExperimentsComplete&&a.FullArtifactHashAudit&&a.ExcelWritten,...
   'Ablation_D20D50:FinalAudit','Final independent audit or Excel export incomplete.');
  state.Status='completed';state.Message='1800 fixed records complete; final audit passed. Packaging saved results next.';
 else
  if isempty(stopReason),stopReason='incomplete_inventory';end
  state.Status=['stopped_',stopReason];state.Message=sprintf('Queue drained. Completed%d/1800; retained%d; pending%d. No retry.',final.Completed,final.Retained,final.Pending);
 end
 state.Errors=errors;state.EndedUTC=utc_now();state.UpdatedUTC=utc_now();abl2050_io('writejson',statusPath,state);
catch e
 for i=1:numel(futures),cancel_one(futures(i));end
 state.Status='stopped_on_error';state.Errors=[errors,{getReport(e,'extended','hyperlinks','off')}];
 state.Message=state.Errors{end};state.ElapsedSeconds=toc(start);state.UpdatedUTC=utc_now();state.EndedUTC=utc_now();
 try,abl2050_io('writejson',statusPath,state);catch,end
 rethrow(e);
end
% collect takes its own coordinator lock. Release this one only after every
% trial/audit is finished; collection failures never trigger optimization.
clear poolGuard;clear lockGuard;
if allComplete
 try
  archive=abl2050_collect(root);state.CollectionStatus='completed';state.ReturnZIP=archive;
  state.Message='All fixed experiments, final audit, Excel, and result ZIP complete.';
  state.UpdatedUTC=utc_now();abl2050_io('writejson',statusPath,state);
  abl2050_io('writejson',fullfile(out,'delivery.json'),struct('Status','completed_and_collected','ZIP',archive,...
   'Total',1800,'Imported',state.ImportedCompleted,'Computed',state.ComputedCompleted,'GeneratedUTC',utc_now()));
  fprintf('RESULT ZIP: %s\n',archive);
 catch e
  state.CollectionStatus='failed';state.Status='experiments_complete_collection_failed';
  state.Message=getReport(e,'extended','hyperlinks','off');state.UpdatedUTC=utc_now();
  abl2050_io('writejson',statusPath,state);fprintf(2,'Experiments complete; collect failed. Retry collect only: %s\n',e.message);
 end
else
 fprintf('%s\nUse MAIN_CSASS_ABLATION(''collect'') to package saved diagnostics.\n',state.Message);
end
end
function [ok,s]=wait_before_pool(out,s,statusPath,start,cfg)
wait=tic;ok=false;
while true
 [ram,disk]=resource_snapshot(out);s.FreeMemoryGB=ram;s.FreeDiskGB=disk;s.ResourceWaitSeconds=toc(wait);
 if ram>2&&disk>5,ok=true;s.Status='running';return;end
 s.Status='awaiting_resources';s.ElapsedSeconds=toc(start);s.UpdatedUTC=utc_now();
 s.Message=sprintf('Before pool startup: RAM %.3fGiB/disk %.3fGiB; require >2/>5. No trial started.',ram,disk);
 if toc(wait)>=1800,s.Status='stopped_resource_wait_limit';
 elseif toc(start)>=cfg.MaxWallHours*3600,s.Status='stopped_session_wall_limit';end
 abl2050_io('writejson',statusPath,s);
 if startsWith(s.Status,'stopped_'),return;end
 pause(min([15,max(0,1800-toc(wait)),max(0,cfg.MaxWallHours*3600-toc(start))]));
end
end
function [ram,disk]=resource_snapshot(out)
[~,system]=memory;ram=double(system.PhysicalMemory.Available)/2^30;
disk=double(java.io.File(out).getUsableSpace())/2^30;
assert(isfinite(ram)&&ram>=0&&isfinite(disk)&&disk>=0,'Ablation_D20D50:ResourceProbe','Invalid resource probe; no new dispatch.');
end
function [file,lock]=acquire_lock(out)
file=java.io.RandomAccessFile(fullfile(out,'coordinator.lock'),'rw');
try,lock=file.getChannel().tryLock();
catch e,file.close();error('Ablation_D20D50:ControllerBusy','Cannot acquire coordinator lock: %s',e.message);end
if isempty(lock),file.close();error('Ablation_D20D50:ControllerBusy','Another controller/postprocessor owns this output.');end
end
function pool=start_process_pool()
profiles=parallel.clusterProfiles;if any(strcmp(profiles,'Processes')),profile='Processes';else,profile='local';end
cluster=parcluster(profile);assert(isa(cluster,'parallel.cluster.Local'),'Ablation_D20D50:PoolType','Local process cluster required.');
if cluster.NumWorkers<6,cluster.NumWorkers=6;end
pool=parpool(cluster,6);
end
function yes=pool_idle(pool)
yes=isempty(pool.FevalQueue.RunningFutures)&&isempty(pool.FevalQueue.QueuedFutures);
end
function cancel_one(f)
try,if isvalid(f)&&~strcmp(f.State,'finished'),cancel(f);end,catch,end
end
function close_owned_idle_pool(pool,owned)
if owned&&~isempty(pool),try,if pool_idle(pool),delete(pool);end,catch,end,end
end
function close_lock(lock,file)
try,if lock.isValid(),lock.release();end,catch,end
try,file.close();catch,end
end
function mark_interrupted(path,id)
try
 s=abl2050_io('json',path);
 if strcmp(s.SessionID,id)&&ismember(s.Status,{'initializing','verifying_reuse','running','draining','draining_resources','awaiting_resources','final_audit'})
  s.Status='interrupted';s.Message='Controller interrupted; only session futures cancelled; all records retained.';
  s.UpdatedUTC=utc_now();abl2050_io('writejson',path,s);
 end
catch
end
end
function s=utc_now()
s=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end