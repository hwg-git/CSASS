function MAIN_MISSING8(mode)
% MAIN_MISSING8 runs the fixed3600 opponent reruns. Same algorithm sources as full campaign.
% Other modes: plan, preflight, summarize, collect, selftest. No implicit retry.
if nargin<1||isempty(mode),mode='run';end
mode=lower(char(mode));
assert(ismember(mode,{'run','plan','preflight','summarize','collect','selftest'}),'Unknown mode.');
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'),'-begin');
protocol=m8_preflight(root);tasks=m8_tasks(root);
if strcmp(mode,'collect'),m8_collect(root);return;end
inv=m8_inventory(root,tasks,false);
fprintf('\nMISSING8: completed %d/3600, never started %d, retained unfinished %d.\n',inv.Completed,inv.Pending,inv.Retained);
fprintf('CF2/3/4/6, LIRCMOP5/6/9/10; D10/20/50; five opponents; 30 runs per group. No CSASS reruns.\n');
fprintf('N100 FE500; seeds1:30; six local process workers, one compute thread each.\n');
if ismember(mode,{'plan','preflight'}),return;end
if strcmp(mode,'selftest')
    disp(m8_selftest(root));return;
end
out=fullfile(root,'outputs','Missing8_Opponents');if ~isfolder(out),mkdir(out);end
[file,lock]=acquire_lock(out);lockGuard=onCleanup(@()close_lock(lock,file)); %#ok<NASGU>
if strcmp(mode,'summarize'),m8_summarize(root,true);return;end
inv=m8_inventory(root,tasks,true);
if inv.Retained>0,fprintf(2,'Retaining %d started/failed/incomplete trials; only never-started trials will run.\n',inv.Retained);end
pending=tasks(inv.PendingMask);
state=struct('Status','running','SessionID',char(java.util.UUID.randomUUID),'PID',feature('getpid'),...
    'StartedUTC',utc_now(),'Planned',3600,'AlreadyCompleted',inv.Completed,'NewCompleted',0,...
    'FailedThisSession',0,'PendingNew',numel(pending),'NeverStarted',numel(pending),...
    'ElapsedSeconds',0,'CurrentID','','SourceCodeLockSHA256',m8_io('sha',fullfile(root,'source_lock.json')),...
    'Message','');
statusPath=fullfile(out,'status.json');m8_io('writejson',statusPath,state);
interruptGuard=onCleanup(@()mark_interrupted(statusPath,state.SessionID)); %#ok<NASGU>
futures=[];futureGuards={};futureIDs={};pool=[];ownedPool=false;start=tic;
next=1;newCompleted=0;failed=0;stopDispatch=false;stopReason='';errors={};
try
    m8_dependencies(root);
    if ~isempty(pending)
        assert(license('test','Distrib_Computing_Toolbox')&&exist('parpool','file')==2,...
            'Parallel Computing Toolbox is required; no automatic serial fallback.');
        pool=gcp('nocreate');
        if ~isempty(pool)
            assert(pool_idle(pool),'Existing pool is busy. This script will not cancel other jobs.');
            % Fresh worker processes avoid cached classes from another package.
            delete(pool);pool=[];
        end
        if isempty(pool),pool=start_process_pool();ownedPool=true;end
        assert(~isa(pool,'parallel.ThreadPool')&&pool.NumWorkers==6&&isa(pool.Cluster,'parallel.cluster.Local'));
        addAttachedFiles(pool,{fullfile(root,'code')});
        futures=parallel.FevalFuture.empty(0,1);
        fprintf('ACTUAL CONCURRENCY: 6 local process workers; 1 compute thread per trial.\n');
    end
    poolGuard=onCleanup(@()close_owned_idle_pool(pool,ownedPool)); %#ok<NASGU>
    while (~stopDispatch&&next<=numel(pending))||~isempty(futures)
        if ~stopDispatch&&toc(start)>=protocol.MaxWallHours*3600
            stopDispatch=true;stopReason='session_wall_limit';state.Status='draining';
            state.Message='24-hour session cap: stop dispatch; current trials finish naturally.';fprintf('%s\n',state.Message);
        end
        ready=~isempty(futures)&&any(arrayfun(@(f)strcmp(f.State,'finished'),futures));
        while ~stopDispatch&&~ready&&next<=numel(pending)&&numel(futures)<6
            t=pending(next);
            try,f=parfeval(pool,@m8_trial,1,root,t);
            catch e
                stopDispatch=true;stopReason='dispatch_error';errors{end+1}=getReport(e,'extended','hyperlinks','off'); %#ok<AGROW>
                state.Status='draining';state.Message='Dispatch failed; current tasks finish naturally.';
                fprintf(2,'%s\n%s\n',state.Message,e.message);break;
            end
            next=next+1;futures(end+1)=f;futureGuards{end+1}=onCleanup(@()cancel_one(f));futureIDs{end+1}=t.ID; %#ok<AGROW>
        end
        if isempty(futures),break;end
        index=find(arrayfun(@(f)strcmp(f.State,'finished'),futures),1);
        if isempty(index),pause(0.25);continue;end
        expectedID=futureIDs{index};f=futures(index);
        futures(index)=[];futureGuards(index)=[];futureIDs(index)=[];
        try
            r=fetchOutputs(f);
            assert(strcmp(r.Status,'completed')&&strcmp(r.ID,expectedID)&&r.FE==500);
            assert(isfile(fullfile(out,'runs',r.ID,'completed.json')));
            newCompleted=newCompleted+1;state.CurrentID=r.ID;
            fprintf('[%d/%d this session; %d/3600 total] %s | IGD=%g HV1.1=%g feasibleND=%d time=%.2fs\n',...
                newCompleted,numel(pending),inv.Completed+newCompleted,r.ID,r.IGD10000,r.HVr1p1,r.FeasibleND,r.RuntimeSeconds);
        catch e
            failed=failed+1;stopDispatch=true;if isempty(stopReason),stopReason='trial_error';end
            errors{end+1}=sprintf('%s: %s',expectedID,getReport(e,'extended','hyperlinks','off')); %#ok<AGROW>
            state.Status='draining';state.CurrentID=expectedID;
            state.Message='Trial failed; no new tasks dispatched; current tasks finish and records remain.';
            fprintf(2,'FAILED %s: %s\n',expectedID,e.message);
        end
        state.NewCompleted=newCompleted;state.FailedThisSession=failed;
        state.PendingNew=numel(pending)-newCompleted;state.NeverStarted=numel(pending)-next+1;
        state.ElapsedSeconds=toc(start);m8_io('writejson',statusPath,state);
        if newCompleted>0&&failed==0&&mod(newCompleted,30)==0
            try
                summary=m8_summarize(root,false);
                assert(summary.AuditFailedRuns==0,'Summary detected invalid completed records.');
            catch e
                stopDispatch=true;stopReason='summary_error';state.Status='draining';
                state.Message='Summary audit failed; current tasks finish naturally.';
                errors{end+1}=getReport(e,'extended','hyperlinks','off'); %#ok<AGROW>
                fprintf(2,'%s\n%s\n',state.Message,e.message);m8_io('writejson',statusPath,state);
            end
        end
    end
    final=m8_inventory(root,tasks,true);
    state.NewCompleted=newCompleted;state.FailedThisSession=failed;state.PendingNew=3600-final.Completed;
    state.NeverStarted=final.Pending;state.RetainedUnfinished=final.Retained;state.ElapsedSeconds=toc(start);
    try
        summary=m8_summarize(root,true);
        assert(summary.AuditFailedRuns==0,'Summary detected invalid completed records.');
    catch e
        stopDispatch=true;if isempty(stopReason),stopReason='summary_error';end
        errors{end+1}=getReport(e,'extended','hyperlinks','off'); %#ok<AGROW>
    end
    if ~stopDispatch&&final.Completed==3600&&final.Retained==0
        audit=m8_audit_saved_sets(root);
        assert(strcmp(audit.Status,'pass'),'Saved-set audit failed; preserve all data and inspect final_audit.json.');
        state.Status='completed';state.Message='All3600 completed and final audit finished.';
        state.CompletedUTC=utc_now();state.Errors=errors;m8_io('writejson',statusPath,state);
        fprintf('Completed 3600/3600. Tables and saved sets: %s\n',out);
        m8_collect(root);
    else
        if isempty(stopReason),stopReason='incomplete_inventory';end
        state.Status=['stopped_',stopReason];state.Message=sprintf('Completed%d/3600; retained%d; never started%d. No automatic retries.',final.Completed,final.Retained,final.Pending);
        fprintf(2,'%s\n',state.Message);
    end
    state.CompletedUTC=utc_now();state.Errors=errors;m8_io('writejson',statusPath,state);
    fprintf('To package the saved data: MAIN_MISSING8(''collect'')\n');
catch e
    for i=1:numel(futures),cancel_one(futures(i));end
    state.Status='stopped_on_controller_error';state.ElapsedSeconds=toc(start);state.Message=getReport(e,'extended','hyperlinks','off');
    try,m8_io('writejson',statusPath,state);catch,end
    rethrow(e);
end
end
function [file,lock]=acquire_lock(out)
file=java.io.RandomAccessFile(fullfile(out,'coordinator.lock'),'rw');
try,lock=file.getChannel().tryLock();catch e,file.close();error('Missing8_Opponents:Busy','%s',e.message);end
if isempty(lock),file.close();error('Missing8_Opponents:Busy','Another controller owns the output.');end
end
function pool=start_process_pool()
profiles=parallel.clusterProfiles;
if any(strcmp(profiles,'Processes')),profile='Processes';else,profile='local';end
c=parcluster(profile);assert(isa(c,'parallel.cluster.Local'),'Local process cluster required.');
if c.NumWorkers<6,c.NumWorkers=6;end
pool=parpool(c,6);
end
function yes=pool_idle(p)
yes=isempty(p.FevalQueue.RunningFutures)&&isempty(p.FevalQueue.QueuedFutures);
end
function cancel_one(f)
try,if isvalid(f)&&~strcmp(f.State,'finished'),cancel(f);end,catch,end
end
function close_owned_idle_pool(p,owned)
if owned&&~isempty(p),try,if pool_idle(p),delete(p);end,catch,end,end
end
function close_lock(lock,file)
try,if lock.isValid(),lock.release();end,catch,end
try,file.close();catch,end
end
function mark_interrupted(path,session)
try
    s=m8_io('json',path);
    if strcmp(s.SessionID,session)&&ismember(s.Status,{'running','draining'})
        s.Status='interrupted';s.Message='Interrupted; partial trials retained, no automatic repeat.';
        s.InterruptedUTC=utc_now();m8_io('writejson',path,s);
    end
catch,end
end
function s=utc_now()
s=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
