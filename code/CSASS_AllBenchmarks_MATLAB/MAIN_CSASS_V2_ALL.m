function MAIN_CSASS_V2_ALL(mode,hvReferences)
% Fixed V2, 2160 total = 210 cached + 1950 new. Default: run.
% Modes: plan/preflight/summarize/collect/hv. No automatic failed-trial retry.
if nargin<1 || isempty(mode),mode='run';end
mode=lower(char(mode));
assert(ismember(mode,{'run','plan','preflight','summarize','collect','hv'}),...
    'Use run, plan, preflight, summarize, collect, or hv.');
if nargin>=2
    assert(strcmp(mode,'hv'),'V2_AllBenchmarks:Arguments','A second argument is permitted only for hv postprocessing.');
else
    hvReferences=[1.1,3,20];
end
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'));
protocol=v2all_preflight(root);tasks=v2all_tasks(root);
inventory=v2all_inventory(root,tasks);
fprintf('\nV2_ALL: total2160 = cached210 + new1950. New completed%d, never started%d, retained unfinished%d.\n',...
    inventory.Completed,inventory.Pending,inventory.Retained);
fprintf('CF1-CF10 and LIRCMOP1-LIRCMOP14; D10/20/50; fixed seeds1:30 per group.\n');
fprintf('Seven completed D10 groups are cached and never dispatched.\n');
fprintf('N100 FE500 Pmax20 K10; six process workers; one compute thread/trial.\n');
if strcmp(mode,'plan'),fprintf('Plan only. No pool or optimization started.\n');return;end
if strcmp(mode,'preflight'),return;end
if strcmp(mode,'collect'),v2all_collect(root);return;end
out=fullfile(root,'outputs','V2_AllBenchmarks');if ~isfolder(out),mkdir(out);end
[file,lock]=acquire_lock(out);
lockGuard=onCleanup(@()close_lock(lock,file)); %#ok<NASGU>
if strcmp(mode,'summarize'),v2all_summarize(root,true);return;end
if strcmp(mode,'hv'),v2all_recompute_hv(root,hvReferences);return;end
% Recheck under exclusive coordinator lock; no old partial record is retried.
inventory=v2all_inventory(root,tasks);
assert(inventory.Retained==0,'V2_AllBenchmarks:RetainedTrial',...
    ['Existing started/failed/incomplete trials are retained, not automatically rerun. ',...
    'Review these IDs first: %s'],strjoin(inventory.RetainedIDs,', '));
pending=tasks(inventory.PendingMask);
state=struct('Status','running','SessionID',char(java.util.UUID.randomUUID),...
    'PID',feature('getpid'),'StartedUTC',utc_now(),'Planned',1950,'Cached',210,'TotalPlanned',2160,...
    'AlreadyCompleted',inventory.Completed,'NewCompleted',0,'FailedThisSession',0,...
    'PendingNew',numel(pending),'NeverStarted',numel(pending),'CurrentID','','ElapsedSeconds',0,...
    'SourceLockSHA256',v2all_io('sha',fullfile(root,'source_lock.json')),...
    'ProtocolSHA256',v2all_io('sha',fullfile(root,'protocol.json')),'Message','');
statusPath=fullfile(out,'status.json');v2all_io('writejson',statusPath,state);
interruptGuard=onCleanup(@()mark_interrupted(statusPath,state.SessionID)); %#ok<NASGU>
futures=[];futureGuards={};futureIDs={};pool=[];ownedPool=false;start=tic;
next=1;newCompleted=0;failed=0;stopDispatch=false;stopReason='';errors={};
try
    if ~isempty(pending)
        assert(license('test','Distrib_Computing_Toolbox') && exist('parpool','file')==2,...
            'V2_AllBenchmarks:ParallelToolbox','Parallel Computing Toolbox is required; no serial fallback.');
        pool=gcp('nocreate');
        if ~isempty(pool)
            assert(pool_idle(pool),'V2_AllBenchmarks:BusyPool',...
                'Existing pool has running or queued work. Wait; this controller will not cancel other jobs.');
            if isa(pool,'parallel.ThreadPool') || pool.NumWorkers~=6 ||...
                    ~isprop(pool,'Cluster') || ~isa(pool.Cluster,'parallel.cluster.Local')
                delete(pool);pool=[];
            end
        end
        if isempty(pool),pool=start_process_pool();ownedPool=true;end
        assert(~isa(pool,'parallel.ThreadPool') && pool.NumWorkers==6 &&...
            isprop(pool,'Cluster') && isa(pool.Cluster,'parallel.cluster.Local'),...
            'V2_AllBenchmarks:PoolType','A six-worker local PROCESS pool is required.');
        addAttachedFiles(pool,{fullfile(root,'code')});
        futures=parallel.FevalFuture.empty(0,1);
        fprintf('ACTUAL CONCURRENCY: 6 local process workers; 1 compute thread per trial.\n');
    end
    poolGuard=onCleanup(@()close_owned_idle_pool(pool,ownedPool)); %#ok<NASGU>
    while (~stopDispatch && next<=numel(pending)) || ~isempty(futures)
        if ~stopDispatch && toc(start)>=protocol.MaxWallHours*3600
            stopDispatch=true;stopReason='session_wall_limit';
            state.Status='draining';state.Message='Session wall limit reached; stop dispatching and let current trials finish.';
            fprintf('%s\n',state.Message);
        end
        % Drain already-finished futures before dispatching another task, so
        % a completed worker failure is observed before additional starts.
        readyToRead=~isempty(futures) && any(arrayfun(@(f)strcmp(f.State,'finished'),futures));
        while ~stopDispatch && ~readyToRead && next<=numel(pending) && numel(futures)<6
            task=pending(next);
            try,f=parfeval(pool,@v2all_trial,1,root,task);
            catch e
                stopDispatch=true;stopReason='dispatch_error';
                errors{end+1}=getReport(e,'extended','hyperlinks','off'); %#ok<AGROW>
                state.Status='draining';state.Message='Dispatch error; existing in-flight trials will finish naturally.';
                fprintf(2,'%s\n%s\n',state.Message,e.message);break;
            end
            next=next+1;futures(end+1)=f;
            futureGuards{end+1}=onCleanup(@()cancel_one(f)); %#ok<AGROW>
            futureIDs{end+1}=task.ID; %#ok<AGROW>
        end
        if isempty(futures),break;end
        % One worker error does not cancel other running trials.
        index=find(arrayfun(@(f)strcmp(f.State,'finished'),futures),1);
        if isempty(index),pause(0.25);continue;end
        expectedID=futureIDs{index};f=futures(index);
        futures(index)=[];futureGuards(index)=[];futureIDs(index)=[];
        try
            r=fetchOutputs(f);
            assert(isstruct(r) && isfield(r,'status') && strcmp(r.status,'completed'),...
                'V2_AllBenchmarks:TrialFailed','Trial did not return completed status.');
            assert(isfield(r,'ID') && strcmp(r.ID,expectedID),...
                'V2_AllBenchmarks:TrialIdentity','Unexpected returned trial ID.');
            assert(isfield(r,'FE') && r.FE==500 && isfile(fullfile(out,'runs',r.ID,'completed.json')),...
                'V2_AllBenchmarks:CompletionMarker','Missing completion marker or wrong FE for %s.',expectedID);
            newCompleted=newCompleted+1;state.CurrentID=r.ID;
            fprintf('[%d/%d new; %d/1950 new total; +210 cached] %s | IGD10000=%g HV(r=1.1)=%g feasibleND=%d\n',...
                newCompleted,numel(pending),inventory.Completed+newCompleted,...
                r.ID,r.IGD10000,r.HVr1p1,r.FeasibleND);
        catch e
            failed=failed+1;stopDispatch=true;
            if isempty(stopReason),stopReason='trial_error';end
            errors{end+1}=sprintf('%s: %s',expectedID,getReport(e,'extended','hyperlinks','off')); %#ok<AGROW>
            state.Status='draining';state.CurrentID=expectedID;
            state.Message='Trial failure: no more tasks dispatched; current tasks finish and keep their records.';
            fprintf(2,'FAILED %s. %s\n%s\n',expectedID,state.Message,e.message);
        end
        state.NewCompleted=newCompleted;state.FailedThisSession=failed;
        state.PendingNew=numel(pending)-newCompleted;state.NeverStarted=numel(pending)-next+1;
        state.ElapsedSeconds=toc(start);v2all_io('writejson',statusPath,state);
        if newCompleted>0 && failed==0 && mod(newCompleted,30)==0
            try,v2all_summarize(root,mod(newCompleted,300)==0);
            catch e
                stopDispatch=true;stopReason='summary_error';state.Status='draining';
                errors{end+1}=getReport(e,'extended','hyperlinks','off'); %#ok<AGROW>
                state.Message='Summary check failed; no new tasks dispatched; current tasks finish naturally.';
                fprintf(2,'%s\n%s\n',state.Message,e.message);
                v2all_io('writejson',statusPath,state);
            end
        end
    end
    finalInventory=v2all_inventory(root,tasks);
    state.NewCompleted=newCompleted;state.FailedThisSession=failed;
    state.PendingNew=1950-finalInventory.Completed;state.NeverStarted=finalInventory.Pending;
    state.ElapsedSeconds=toc(start);state.RetainedUnfinished=finalInventory.Retained;
    try,v2all_summarize(root,true);
    catch e
        stopDispatch=true;if isempty(stopReason),stopReason='summary_error';end
        errors{end+1}=getReport(e,'extended','hyperlinks','off'); %#ok<AGROW>
    end
    if ~stopDispatch && finalInventory.Completed==1950 && finalInventory.Retained==0
        state.Status='completed';state.CompletedUTC=utc_now();
        state.Message='All1950 new V2 trials completed; full2160 summary includes210 unchanged cached trials.';
        fprintf('Completed all1950 new /2160 combined. Outputs: %s\n',out);
    else
        if isempty(stopReason),stopReason='incomplete_inventory';end
        state.Status=['stopped_',stopReason];state.CompletedUTC=utc_now();
        state.Message=sprintf('Dispatch stopped; in-flight queue drained. Completed%d/1950, retained%d, never started%d. No automatic retry.',...
            finalInventory.Completed,finalInventory.Retained,finalInventory.Pending);
        fprintf(2,'%s\n',state.Message);
    end
    state.Errors=errors;v2all_io('writejson',statusPath,state);
    fprintf('Use MAIN_CSASS_V2_ALL(''collect'') to return all saved results and diagnostics.\n');
catch e
    % Unexpected controller faults affect only futures created in this session.
    for i=1:numel(futures),cancel_one(futures(i));end
    state.Status='stopped_on_controller_error';state.ElapsedSeconds=toc(start);
    state.Message=getReport(e,'extended','hyperlinks','off');
    try,v2all_io('writejson',statusPath,state);catch,end
    rethrow(e);
end
end
function [file,lock]=acquire_lock(out)
file=java.io.RandomAccessFile(fullfile(out,'coordinator.lock'),'rw');
try,lock=file.getChannel().tryLock();
catch e,file.close();error('V2_AllBenchmarks:ControllerBusy','Cannot acquire coordinator lock: %s',e.message);end
if isempty(lock),file.close();error('V2_AllBenchmarks:ControllerBusy','Another controller/postprocessor owns this output.');end
end
function pool=start_process_pool()
profiles=parallel.clusterProfiles;
if any(strcmp(profiles,'Processes')),profile='Processes';else,profile='local';end
cluster=parcluster(profile);
assert(isa(cluster,'parallel.cluster.Local'),'V2_AllBenchmarks:ClusterType',...
    'The Processes/local profile must point to a local process cluster.');
if cluster.NumWorkers<6,cluster.NumWorkers=6;end
pool=parpool(cluster,6);
end
function yes=pool_idle(pool)
yes=isempty(pool.FevalQueue.RunningFutures) && isempty(pool.FevalQueue.QueuedFutures);
end
function cancel_one(f)
try,if isvalid(f) && ~strcmp(f.State,'finished'),cancel(f);end,catch,end
end
function close_owned_idle_pool(pool,owned)
if owned && ~isempty(pool)
    try,if pool_idle(pool),delete(pool);end,catch,end
end
end
function close_lock(lock,file)
try,if lock.isValid(),lock.release();end,catch,end
try,file.close();catch,end
end
function mark_interrupted(path,sessionID)
try
    s=v2all_io('json',path);
    if strcmp(s.SessionID,sessionID) && ismember(s.Status,{'running','draining'})
        s.Status='interrupted';s.Message='Controller interrupted; only session futures cancelled. Trial records retained.';
        s.InterruptedUTC=utc_now();v2all_io('writejson',path,s);
    end
catch
end
end
function s=utc_now()
s=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
