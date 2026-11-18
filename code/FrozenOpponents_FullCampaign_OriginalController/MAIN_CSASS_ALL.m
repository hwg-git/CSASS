function MAIN_CSASS_ALL(mode,shardIndex,shardCount)
% Default: formal30,12960 tasks;6 process workers,1 compute thread per trial.
% MAIN_CSASS_ALL('resume6'): after the OLD run has stopped, archive interrupted
% (not completed/not failed) trials and orphan claims, then restart SAME IDs.
% MAIN_CSASS_ALL('drain'): from a SECOND MATLAB session, request this NEW
% controller to finish its current tasks and stop submitting more. Not supported
% by the older two-worker controller that is already running.
% MAIN_CSASS_ALL('plan'): print task counts and desired workers, no optimization.
% MAIN_CSASS_ALL('selftest6'): isolated recovery-file tests, no optimization.
% Original modes smoke,csass_smoke,formal,csass30,preflight,summarize remain.
if nargin<1||isempty(mode),mode='formal';end
if nargin<2,shardIndex=1;end
if nargin<3,shardCount=1;end
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'));
if strcmp(mode,'selftest6'),selftest6(root);return;end
resumeInterrupted=strcmp(mode,'resume6');planOnly=strcmp(mode,'plan');drainCommand=strcmp(mode,'drain');
if resumeInterrupted||planOnly||drainCommand,mode='formal';end
cfg=portable_config(root,mode);cfg.ShardIndex=shardIndex;cfg.ShardCount=shardCount;
cfg.Workers=6;cfg.UseParallel=true;cfg.WriteExcel=true;
if shardCount>1,cfg.UseParallel=false;end
assert(shardIndex>=1&&shardIndex<=shardCount&&fix(shardCount)==shardCount);
drainFile=fullfile(cfg.Output,'DRAIN_AFTER_CURRENT.json');
if drainCommand
 assert(isfolder(cfg.Output),'No existing output directory.');
 portable_write_json(drainFile,struct('RequestedUTC',utcnow(),'Request','Finish active trials,then stop.'));
 fprintf('Drain request written. Only the NEW six-worker controller reads this flag.\n');return;
end
tasks=portable_tasks(cfg);tasks=tasks(mod([tasks.Index]-1,shardCount)==shardIndex-1);
if planOnly
 done=0;incomplete=0;
 for i=1:numel(tasks)
  d=fullfile(cfg.Output,'runs',tasks(i).ID);
  if isfile(fullfile(d,'completed.json')),done=done+1;elseif isfolder(d),incomplete=incomplete+1;end
 end
 fprintf('FORMAL30 plan: total%d,completed%d,incomplete%d,unstarted%d,requested workers6.\n',numel(tasks),done,incomplete,numel(tasks)-done-incomplete);
 fprintf('No task,pool or output change performed.\n');return;
end
if strcmp(mode,'summarize'),portable_summarize(root,cfg,0);return;end
% Verify current client pool idle BEFORE any recovery moves. Never cancel another
% session's work or remove records just to make startup succeed.
existing=[];
if exist('gcp','file')==2,existing=gcp('nocreate');end
if ~isempty(existing)
 require_idle(existing);
 if resumeInterrupted
  fprintf('Closing the idle old pool before archiving interrupted data.\n');delete(existing);existing=[];
 end
end
portable_preflight(root,cfg);
if strcmp(mode,'preflight'),fprintf('Preflight passed; no optimization.\n');return;end
sessionID=newid();history=fullfile(cfg.Output,'control_history',sessionID);mkdir(history);
coordinator=fullfile(cfg.Output,'locks',sprintf('coordinator_%dof%d',shardIndex,shardCount));
if isfolder(coordinator)
 assert(resumeInterrupted,'Coordinator lock exists. Stop the old run first; use resume6 only after confirming no other session writes this output.');
 answer=input('Coordinator lock exists. If ALL previous controllers using this output have stopped, type STOPPED: ','s');
 assert(strcmp(answer,'STOPPED'),'No files moved; previous coordinator ownership not confirmed.');
 safe_move(coordinator,fullfile(history,'previous_coordinator_lock'),cfg.Output);
end
claim=java.io.File(coordinator);assert(claim.mkdir(),'Another coordinator acquired this output.');
portable_write_json(fullfile(coordinator,'owner.json'),struct('SessionID',sessionID,'PID',feature('getpid'),'StartedUTC',utcnow()));
release=onCleanup(@()close_coordinator(coordinator,history,sessionID,cfg.Output));
if resumeInterrupted
 archive_interrupted(cfg.Output,tasks,history);
 if isfile(drainFile),safe_move(drainFile,fullfile(history,'previous_drain_request.json'),cfg.Output);end
end
pending=tasks(false(size(tasks)));skipped=0;retained=0;
for i=1:numel(tasks)
 d=fullfile(cfg.Output,'runs',tasks(i).ID);
 if isfile(fullfile(d,'completed.json')),skipped=skipped+1;
 elseif isfolder(d),retained=retained+1;fprintf('RETAIN incomplete/failed: %s\n',tasks(i).ID);
 else,pending(end+1)=tasks(i);end
end
fprintf('\n%s: total%d,already complete%d,pending%d,retained incomplete/failed%d.\n',mode,numel(tasks),skipped,numel(pending),retained);
fprintf('Execution target:6 process workers;1 compute thread per trial. Science/seed/budget/output unchanged.\n');
pool=existing;ownedPool=false;guards={};futures=[];inflight=pending(false(size(pending)));
if cfg.UseParallel&&numel(pending)>1&&license('test','Distrib_Computing_Toolbox')&&exist('parpool','file')==2
 target=min(cfg.Workers,numel(pending));
 if ~isempty(pool)&&(isa(pool,'parallel.ThreadPool')||pool.NumWorkers~=target)
  require_idle(pool);fprintf('Replacing idle pool of%d workers with%d PROCESS workers.\n',pool.NumWorkers,target);
  delete(pool);pool=[];
 end
 if isempty(pool),pool=parpool('local',target);ownedPool=true;end
 assert(~isa(pool,'parallel.ThreadPool'),'A process pool is required.');
 addAttachedFiles(pool,{fullfile(root,'code')});
elseif cfg.UseParallel&&numel(pending)>1
 fprintf('Parallel toolbox not installed/licensed: SERIAL fallback. Two-session sharding remains available.\n');pool=[];
else,pool=[];
end
poolGuard=onCleanup(@()close_owned_pool(pool,ownedPool,cfg.CloseOwnedPool));
lanes=1;if ~isempty(pool),lanes=min([cfg.Workers,pool.NumWorkers,numel(pending)]);end
portable_write_json(fullfile(history,'execution_settings.json'),struct('RequestedWorkers',6,'ActualConcurrentTasks',lanes,'ThreadsPerTrial',1,'SkippedCompleted',skipped,'RetainedUnfinished',retained,'Pending',numel(pending),'Mode',mode,'NoScienceChanges',true,'StartedUTC',utcnow()));
fprintf('ACTUAL CONCURRENCY: %d tasks.\n',lanes);
start=tic;next=1;finished=0;failed=0;draining=false;
try
 if isempty(pool)
  for k=1:numel(pending)
   if isfile(drainFile),draining=true;break;end
   assert(toc(start)<cfg.MaxWallHours*3600,'Configured wall-time limit reached.');
   r=portable_run_task(root,pending(k),cfg);finished=finished+1;failed=failed+~strcmp(r.Status,'completed');
   log_result(r,finished,numel(pending));rollup(root,cfg,shardIndex,finished,numel(pending));
   if cfg.StopOnError&&~strcmp(r.Status,'completed'),error('Task failed; original failure.json retained.');end
  end
 else
  futures=parallel.FevalFuture.empty(0,1);
  while (~draining&&next<=numel(pending))||~isempty(futures)
   assert(toc(start)<cfg.MaxWallHours*3600,'Configured wall-time limit reached.');
   if isfile(drainFile)&&~draining,draining=true;fprintf('DRAIN: stop submitting;wait for active trials to finish.\n');end
   while ~draining&&next<=numel(pending)&&numel(futures)<lanes
    f=parfeval(pool,@portable_run_task,1,root,pending(next),cfg);
    futures(end+1)=f;inflight(end+1)=pending(next);
    % One guard per live future: captures that future,not an old empty array.
    guards{end+1}=onCleanup(@()cancel_one(f));next=next+1;
   end
   if isempty(futures),break;end
   [idx,r]=fetchNext(futures,1);
   if ~isempty(idx)
    futures(idx)=[];inflight(idx)=[];guards(idx)=[];
    finished=finished+1;failed=failed+~strcmp(r.Status,'completed');
    log_result(r,finished,numel(pending));rollup(root,cfg,shardIndex,finished,numel(pending));
    if cfg.StopOnError&&~strcmp(r.Status,'completed'),error('Task failed; original failure.json retained.');end
   end
   for j=1:numel(inflight)
    p=fullfile(cfg.Output,'runs',inflight(j).ID,'started.json');
    if isfile(p)
     q=portable_read_json(p);assert(posixtime(datetime('now','TimeZone','UTC'))-q.Unix<cfg.MaxTaskSeconds,'Task time limit reached.');
    end
   end
  end
 end
 portable_summarize(root,cfg,shardIndex);
 if draining&&isfile(drainFile),safe_move(drainFile,fullfile(history,'consumed_drain_request.json'),cfg.Output);end
 portable_write_json(fullfile(history,'completion.json'),struct('Handled',finished,'Failures',failed,'Drained',draining,'RetainedUnfinished',retained,'FinishedUTC',utcnow()));
 fprintf('Queue finished/drained: newly handled%d,failures%d,retained unfinished%d.\n',finished,failed,retained);
catch e
 if ~isempty(futures),try,cancel(futures);catch,end;end
 try,portable_summarize(root,cfg,shardIndex);catch reportError,fprintf(2,'Rollup failed;raw records retained: %s\n',reportError.message);end
 rethrow(e);
end
end

function require_idle(p)
assert(isprop(p,'FevalQueue'),'Cannot verify this existing pool is idle on this MATLAB release. Close it manually only after all its work has finished.');
assert(isempty(p.FevalQueue.RunningFutures)&&isempty(p.FevalQueue.QueuedFutures),'Pool still has running/queued jobs. Wait for cancellation/completion before resume6. No data moved.');
end
function cancel_one(f)
try,if isvalid(f)&&~strcmp(f.State,'finished'),cancel(f);end;catch,end
end
function close_owned_pool(p,owned,closeIt)
try,if owned&&closeIt&&~isempty(p)&&isvalid(p),delete(p);end;catch,end
end
function close_coordinator(lock,history,id,output)
try
 if isfolder(lock)&&isfile(fullfile(lock,'owner.json'))
  owner=portable_read_json(fullfile(lock,'owner.json'));
  if strcmp(owner.SessionID,id),safe_move(lock,fullfile(history,'closed_coordinator_lock'),output);end
 end
catch e,fprintf(2,'Coordinator lock retained for review: %s\n',e.message);end
end
function records=archive_interrupted(output,tasks,history)
records=repmat(struct('ID','','Action','','SavedPath','','RawRows',0),0,1);
for i=1:numel(tasks)
 id=tasks(i).ID;assert(~isempty(regexp(id,'^[A-Za-z0-9_]+$','once')));
 d=fullfile(output,'runs',id);lock=fullfile(output,'locks',id);
 if isfile(fullfile(d,'completed.json')),continue;end
 if isfile(fullfile(d,'failure.json'))
  fprintf('Recorded program failure retained,NOT retried: %s\n',id);continue;
 end
 if isfolder(d)
  n=0;raw=fullfile(d,'partial_truth.csv');if isfile(raw),a=readmatrix(raw,'NumHeaderLines',1);n=size(a,1);end
  dest=fullfile(history,'interrupted_attempts',id);safe_move(d,dest,output);
  records(end+1)=struct('ID',id,'Action','archive_interrupted_then_retry_same_seed','SavedPath',dest,'RawRows',n);
  fprintf('ARCHIVED interrupted %s (%d raw rows);same seed will restart.\n',id,n);
 end
 if isfolder(lock)
  dest=fullfile(history,'previous_trial_locks',id);safe_move(lock,dest,output);
  records(end+1)=struct('ID',id,'Action','archive_orphan_or_interrupted_claim','SavedPath',dest,'RawRows',0);
 end
end
portable_write_json(fullfile(history,'recovery_actions.json'),struct('Reason','Explicit user resume6 after stopping prior controller','Actions',records,'NoCompletedOrFailedTrialMoved',true));
end
function safe_move(src,dst,output)
baseFile=java.io.File(output);srcFile=java.io.File(src);dstFile=java.io.File(dst);
base=char(baseFile.getCanonicalPath());from=char(srcFile.getCanonicalPath());to=char(dstFile.getCanonicalPath());
prefix=[lower(base),filesep];assert(strncmp(lower(from),prefix,numel(prefix))&&strncmp(lower(to),prefix,numel(prefix)),'Recovery move outside intended output directory.');
assert(~isfile(dst)&&~isfolder(dst),'Preserve existing recovery destination.');
parent=fileparts(dst);if ~isfolder(parent),mkdir(parent);end
[ok,msg]=movefile(src,dst);assert(ok,'Recovery move failed: %s',msg);
end
function rollup(root,c,shard,finished,total)
portable_write_json(fullfile(c.Output,sprintf('execution_progress_shard%d.json',shard)),struct('HandledThisSession',finished,'PendingThisSession',total,'UpdatedUTC',utcnow()));
if mod(finished,30)~=0&&finished~=total,return;end
v=c;v.WriteExcel=c.WriteExcel&&(mod(finished,120)==0||finished==total);portable_summarize(root,v,shard);
end
function log_result(r,n,total)
fprintf('[%d/%d] %s %s IGD=%g HV=%g time=%.2fs\n',n,total,r.ID,r.Status,r.IGD,r.HV,r.RuntimeSeconds);
end
function id=newid()
u=char(java.util.UUID.randomUUID());id=[datestr(now,'yyyymmdd_HHMMSS'),'_',u(1:8)];
end
function t=utcnow(),t=char(datetime('now','TimeZone','UTC'));end
function selftest6(root)
% Artificial files only,isolated from outputs and real optimization tasks.
output=fullfile(root,'validation',['control_fixture_',newid()]);mkdir(fullfile(output,'runs'));mkdir(fullfile(output,'locks'));history=fullfile(output,'history');mkdir(history);
names={'fixture_complete','fixture_partial','fixture_failed','fixture_orphan'};
tasks=repmat(struct('ID',''),1,4);
for i=1:4,tasks(i).ID=names{i};end
for i=1:3,mkdir(fullfile(output,'runs',names{i}));end
portable_write_json(fullfile(output,'runs',names{1},'completed.json'),struct('ArtificialFixture',true));
portable_write_json(fullfile(output,'runs',names{2},'started.json'),struct('ArtificialFixture',true));
portable_write_csv(fullfile(output,'runs',names{2},'partial_truth.csv'),{'EvaluationID'},[1;2]);
portable_write_json(fullfile(output,'runs',names{3},'failure.json'),struct('ArtificialFixture',true));
mkdir(fullfile(output,'locks',names{2}));mkdir(fullfile(output,'locks',names{4}));
archive_interrupted(output,tasks,history);
assert(isfile(fullfile(output,'runs',names{1},'completed.json'))&&isfile(fullfile(output,'runs',names{3},'failure.json')));
assert(~isfolder(fullfile(output,'runs',names{2}))&&isfile(fullfile(history,'interrupted_attempts',names{2},'partial_truth.csv')));
assert(~isfolder(fullfile(output,'locks',names{4})));
coordinator=fullfile(output,'locks','coordinator_fixture');mkdir(coordinator);
portable_write_json(fullfile(coordinator,'owner.json'),struct('SessionID','fixture_owner'));
close_coordinator(coordinator,history,'fixture_owner',output);
assert(~isfolder(coordinator)&&isfile(fullfile(history,'closed_coordinator_lock','owner.json')));
failed=false;try,safe_move(fullfile(output,'runs',names{1}),fileparts(output),output);catch,failed=true;end;assert(failed,'Containment guard failed.');
c=portable_config(root,'formal');t=portable_tasks(c);assert(numel(t)==12960&&numel(unique([t.Seed]))==30);
portable_write_json(fullfile(output,'selftest_result.json'),struct('Status','pass','ArtificialFilesOnly',true,'OptimizationTrials',0,'CompleteAndFailedPreserved',true,'InterruptedAndOrphanArchived',true,'OwnedCoordinatorArchived',true,'ContainmentChecked',true,'FormalTasks',12960,'DesiredWorkers',6));
fprintf('SELFTEST6_PASS: zero optimization;recovery records preserved;12960 tasks.\n');
end
