function summary=PUBLIC_OPPONENTS_FULL(releaseRoot,action)
% New release wrapper around the retained five-opponent full-campaign protocol.
% This is not the historical controller. The older CSASS branch is never run.
% Historical PF2000 task metrics are retained; use the release postprocessing
% on saved final sets for the manuscript's common PF10000 metrics.
if nargin<2||isempty(action),action='plan';end
action=lower(char(action));summary=[];
assert(ismember(action,{'help','plan','preflight','run','status','summarize'}), ...
    'Use help, plan, preflight, run, status or summarize.');
if strcmp(action,'help')
    fprintf('Five frozen opponents,24 problems,D10/20/50,seeds1:30 =10800 trials.\n');
    fprintf('Explicit run is required; six process workers,one compute thread per trial.\n');return;
end
root=fullfile(releaseRoot,'code','FrozenOpponents_FullCampaign_OriginalController');
oldPath=path;pathGuard=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(fullfile(root,'code'),'-begin');
assert(strcmpi(which('portable_config'),fullfile(root,'code','portable_config.m')),'Conflicting portable_config on MATLAB path.');
c=portable_config(root,'formal');
c.Algorithms=c.Algorithms(~strcmp(c.Algorithms,'CSASS'));
c.Output=fullfile(releaseRoot,'reproduced','opponents_full');
assert(isequal(c.Algorithms,{'ANSGAIII','HeEMOEA','MOL2SMEA','PCSAEA','CTAEA'}));
assert(c.N==100&&c.MaxFE==500&&c.Pmax==20&&c.K==10&&c.NativeReferencePopulation==91);
assert(isequal(c.Dimensions,[10,20,50])&&isequal(c.Seeds,1:30));
assert(c.ReferencePoints==2000&&c.HVReference==1.1&&c.Workers==6);
tasks=portable_tasks(c);assert(numel(tasks)==10800&&~any(strcmp({tasks.Algorithm},'CSASS')));
[pending,complete,retained]=inventory(tasks,c.Output);
summary=struct('Planned',10800,'Completed',complete,'Pending',numel(pending),'Retained',retained,'Output',c.Output);
if ismember(action,{'plan','status'})
    disp(summary);fprintf('No benchmark evaluation,worker startup or output change.\n');return;
end
if strcmp(action,'summarize')
    assert(isfolder(c.Output),'No reproduction output to summarize.');
    portable_summarize(root,c,0);return;
end
% The retained preflight preserves its historical source/protocol checks and
% reference generation; it creates metadata but does not run optimization.
portable_preflight(root,c);
portable_write_json(fullfile(c.Output,'public_wrapper_protocol.json'), ...
    struct('Wrapper','Public five-opponent release wrapper,not historical controller', ...
    'ExcludedAlgorithm','CSASS','Algorithms',{c.Algorithms},'Planned',10800, ...
    'PublishedDataUntouched',true,'ScientificSettings','Unchanged retained portable_config formal settings', ...
    'MetricNote','Task metrics use frozen historical PF2000;recompute paper metrics on final sets using PF10000', ...
    'ManifestNote','Historical CSASS fingerprint/variant fields are unused provenance;no CSASS task is scheduled'));
if strcmp(action,'preflight'),fprintf('Preflight complete; no optimization started.\n');return;end
assert(license('test','Distrib_Computing_Toolbox')&&exist('parpool','file')==2, ...
    'Six-process reproduction requires Parallel Computing Toolbox.');
if isempty(pending),fprintf('No never-started tasks; completed and retained records unchanged.\n');portable_summarize(root,c,0);return;end
lock=fullfile(c.Output,'locks','public_coordinator');claim=java.io.File(lock);
assert(claim.mkdir(),'Coordinator lock exists. No second controller or automatic recovery is allowed.');
lockGuard=onCleanup(@()release_lock(lock)); %#ok<NASGU>
pool=gcp('nocreate');owned=false;
if ~isempty(pool)
    assert(isa(pool.Cluster,'parallel.cluster.Local')&&~isa(pool,'parallel.ThreadPool')&&pool.NumWorkers==6, ...
        'Start a fresh MATLAB session or provide an idle six-worker local process pool.');
    assert(isempty(pool.FevalQueue.RunningFutures)&&isempty(pool.FevalQueue.QueuedFutures), ...
        'Existing pool is busy; no jobs were cancelled.');
else
    pool=parpool('local',6);owned=true;
end
poolGuard=onCleanup(@()close_owned_pool(pool,owned)); %#ok<NASGU>
addAttachedFiles(pool,{fullfile(root,'code')});
futures=parallel.FevalFuture.empty(0,1);guards={};active=pending(false(size(pending)));
next=1;handled=0;failures=0;stopDispatch=false;reason='';start=tic;
fprintf('ACTUAL CONCURRENCY: six local process workers;one compute thread per trial.\n');
fprintf('Completed%d,retained%d,pending%d. No automatic retries.\n',complete,retained,numel(pending));
try
    while (~stopDispatch&&next<=numel(pending))||~isempty(futures)
        if toc(start)>=c.MaxWallHours*3600,stopDispatch=true;reason='Configured wall-time limit reached;active tasks drain.';end
        while ~stopDispatch&&next<=numel(pending)&&numel(futures)<6
            f=parfeval(pool,@portable_run_task,1,root,pending(next),c);
            futures(end+1)=f;active(end+1)=pending(next); %#ok<AGROW>
            guards{end+1}=onCleanup(@()cancel_one(f));next=next+1; %#ok<AGROW>
        end
        if isempty(futures),break;end
        idx=[];r=[];
        try
            [idx,r]=fetchNext(futures,1);
        catch e
            stopDispatch=true;reason=e.message;
            failedIndex=find(arrayfun(@(f)strcmp(f.State,'finished')&&~isempty(f.Error),futures),1);
            if isempty(failedIndex),rethrow(e);end
            idx=failedIndex;failures=failures+1;
            err=futures(idx).Error;
            fprintf(2,'WORKER ERROR %s: %s\n',active(idx).ID,getReport(err,'extended','hyperlinks','off'));
            portable_write_json(fullfile(c.Output,['worker_failure_',active(idx).ID,'.json']), ...
                struct('Task',active(idx),'Error',getReport(err,'extended','hyperlinks','off'),'Retained',true));
        end
        if ~isempty(idx)
            futures(idx)=[];active(idx)=[];guards(idx)=[];handled=handled+1;
            if ~isempty(r)
                fprintf('[%d/%d] %s %s IGD=%g HV=%g\n',handled,numel(pending),r.ID,r.Status,r.IGD,r.HV);
                if ~strcmp(r.Status,'completed'),failures=failures+1;stopDispatch=true;reason='Trial failed;failure record retained.';end
            end
            if mod(handled,30)==0,portable_summarize(root,c,0);end
        end
        for k=1:numel(active)
            marker=fullfile(c.Output,'runs',active(k).ID,'started.json');
            if isfile(marker)
                s=portable_read_json(marker);
                assert(posixtime(datetime('now','TimeZone','UTC'))-s.Unix<c.MaxTaskSeconds, ...
                    'Task time limit exceeded;partial records retained.');
            end
        end
    end
catch e
    if ~isempty(futures),cancel(futures);end
    try,portable_summarize(root,c,0);catch, end
    rethrow(e);
end
portable_summarize(root,c,0);
[pending,complete,retained]=inventory(tasks,c.Output);
summary=struct('Planned',10800,'Completed',complete,'Pending',numel(pending),'Retained',retained, ...
    'HandledThisSession',handled,'FailuresThisSession',failures,'StopReason',reason,'Output',c.Output);
portable_write_json(fullfile(c.Output,'public_wrapper_status.json'),summary);disp(summary);
end

function [pending,done,retained]=inventory(tasks,out)
pending=tasks(false(size(tasks)));done=0;retained=0;
for i=1:numel(tasks)
    folder=fullfile(out,'runs',tasks(i).ID);marker=fullfile(folder,'completed.json');
    if isfile(marker)
        r=portable_read_json(marker);
        assert(strcmp(r.TaskID,tasks(i).ID)&&r.FE==500&&strcmp(r.Status,'completed'),'Invalid completion record.');
        done=done+1;
    elseif isfolder(folder)||isfolder(fullfile(out,'locks',tasks(i).ID))||isfile(fullfile(out,['worker_failure_',tasks(i).ID,'.json']))
        retained=retained+1;
    else,pending(end+1)=tasks(i); %#ok<AGROW>
    end
end
end
function release_lock(folder)
if isfolder(folder),rmdir(folder);end
end
function close_owned_pool(pool,owned)
try,if owned&&~isempty(pool)&&isvalid(pool),delete(pool);end;catch,end
end
function cancel_one(f)
try,if isvalid(f)&&~strcmp(f.State,'finished'),cancel(f);end;catch,end
end
