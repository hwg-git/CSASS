function MAIN_CSASS_V2_D10(mode,extra)
% Local serial D10 ablation: 900 total =360 cached +540 new fixed trials.
% A single MATLAB process/thread; never opens a parallel pool or retries.
if nargin<1 || isempty(mode),mode='run';end
mode=lower(char(mode));
assert(ismember(mode,{'run','plan','preflight','summarize','collect','hv','import'}),...
    'V2_Ablation_D10:Mode','Use run, plan, preflight, summarize, collect, hv, or import.');
if nargin>=2
    assert(ismember(mode,{'hv','import'}),'V2_Ablation_D10:Arguments','Second argument is only for hv/import.');
elseif strcmp(mode,'import'),extra=[];
else,extra=[1.1,3,20];end
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'));
protocol=v2d10_preflight(root);tasks=v2d10_tasks(root);inv=v2d10_inventory(root,tasks);
fprintf('LOCAL V2 D10: 900 total=360 cached+540 fixed new slots; completed%d, pending%d, retained%d.\n',...
    inv.Completed,inv.Pending,inv.Retained);
fprintf('One MATLAB process; one compute thread; no parallel pool. Five modes, six problems, seeds1:30.\n');
fprintf('Completed new slots: %d computed, %d verified imports.\n',inv.ComputedCompleted,inv.ImportedCompleted);
if ismember(mode,{'plan','preflight'}),return;end
if strcmp(mode,'collect'),v2d10_collect(root);return;end
out=fullfile(root,'outputs','V2_Ablation_D10');if ~isfolder(out),mkdir(out);end
[file,lock]=acquire_lock(out);lockGuard=onCleanup(@()close_lock(lock,file)); %#ok<NASGU>
if strcmp(mode,'summarize'),v2d10_summarize(root,true);return;end
if strcmp(mode,'hv'),v2d10_recompute_hv(root,extra);return;end
if strcmp(mode,'import')
    if isempty(extra)
        sourcePath=uigetdir(pwd,'Select full-V2 package root or outputs/V2_AllBenchmarks');
        if isequal(sourcePath,0),fprintf('Import cancelled.\n');return;end
    else
        assert(ischar(extra) || (isstring(extra)&&isscalar(extra)),'V2_Ablation_D10:ImportPath','Source must be a folder path.');
        sourcePath=char(extra);
    end
    receipt=v2d10_import_main(root,sourcePath);disp(receipt);v2d10_summarize(root,true);return;
end
inv=v2d10_inventory(root,tasks);
assert(inv.Retained==0,'V2_Ablation_D10:RetainedTrial',...
    'Existing unfinished/failed trials will not be retried. Review retained IDs: %s',strjoin(inv.RetainedIDs,', '));
pending=tasks(inv.PendingMask);timer=tic;
state=struct('Status','starting','SessionID',char(java.util.UUID.randomUUID),...
    'PID',feature('getpid'),'StartedUTC',utc_now(),'UpdatedUTC',utc_now(),...
    'PlannedNew',540,'CachedCompleted',360,'AlreadyCompletedNew',inv.Completed,...
    'ImportedCompleted',inv.ImportedCompleted,'SessionCompleted',0,...
    'CompletedNew',inv.Completed,'CompletedCombined',360+inv.Completed,...
    'TotalPlanned',900,'Pending',numel(pending),'CurrentID','','CurrentMode','',...
    'ElapsedSeconds',0,'ResourceWaitSeconds',0,'FreeMemoryGB',NaN,'FreeDiskGB',NaN,...
    'Workers',1,'ComputeThreads',1,'ParallelPoolStarted',false,'Message','','Errors',{{}},...
    'SourceLockSHA256',v2d10_io('sha',fullfile(root,'source_lock.json')),...
    'ProtocolSHA256',v2d10_io('sha',fullfile(root,'protocol.json')));
statusPath=fullfile(out,'status.json');v2d10_io('writejson',statusPath,state);
interruptGuard=onCleanup(@()mark_interrupted(statusPath,state.SessionID)); %#ok<NASGU>
completed=0;stopReason='';
try
    assert(exist('ranksum','file')==2 && license('test','Statistics_Toolbox'),...
        'V2_Ablation_D10:StatisticsToolbox','Statistics and Machine Learning Toolbox with ranksum is required.');
    oldThreads=maxNumCompThreads;maxNumCompThreads(1);
    threadGuard=onCleanup(@()maxNumCompThreads(oldThreads)); %#ok<NASGU>
    for i=1:numel(pending)
        task=pending(i);state.CurrentID=task.ID;state.CurrentMode=task.Mode;state.CurrentStartedUTC='';
        if toc(timer)>=protocol.MaxWallHours*3600,stopReason='session_wall_limit';break;end
        % Check physical RAM and this output volume before EVERY new trial.
        % No process is killed and no scientific setting changes while waiting.
        waitTimer=tic;
        while true
            [freeRAM,freeDisk]=resource_snapshot(out);
            state.FreeMemoryGB=freeRAM;state.FreeDiskGB=freeDisk;
            state.ResourceWaitSeconds=toc(waitTimer);state.ElapsedSeconds=toc(timer);state.UpdatedUTC=utc_now();
            if freeRAM>protocol.MinimumFreeMemoryGB && freeDisk>protocol.MinimumFreeDiskGB,break;end
            state.Status='awaiting_resources';
            state.Message=sprintf('Waiting: physical RAM %.3f GB (need >1), output disk %.3f GB (need >3). No trial started.',freeRAM,freeDisk);
            v2d10_io('writejson',statusPath,state);
            if toc(timer)>=protocol.MaxWallHours*3600,stopReason='session_wall_limit';break;end
            if toc(waitTimer)>=1800,stopReason='resource_wait_limit';break;end
            pause(min([15,max(0,1800-toc(waitTimer)),max(0,protocol.MaxWallHours*3600-toc(timer))]));
        end
        if ~isempty(stopReason),break;end
        if toc(timer)>=protocol.MaxWallHours*3600,stopReason='session_wall_limit';break;end
        state.Status='running';state.CurrentStartedUTC=utc_now();state.UpdatedUTC=utc_now();
        state.Message='Running one frozen trial; no concurrent scientific task.';
        v2d10_io('writejson',statusPath,state);
        r=v2d10_trial(root,task);
        assert(isstruct(r) && isfield(r,'status') && strcmp(r.status,'completed') &&...
            strcmp(r.ID,task.ID) && strcmp(r.Mode,task.Mode) && r.FE==500,...
            'V2_Ablation_D10:TrialIdentity','Unexpected trial result/status/mode/budget: %s',task.ID);
        assert(isfile(fullfile(out,'runs',task.ID,'completed.json')),...
            'V2_Ablation_D10:CompletionMarker','Missing completed marker for %s',task.ID);
        completed=completed+1;state.SessionCompleted=completed;
        state.CompletedNew=inv.Completed+completed;state.CompletedCombined=360+state.CompletedNew;
        state.Pending=numel(pending)-completed;state.ElapsedSeconds=toc(timer);state.UpdatedUTC=utc_now();
        state.Message='Trial completed and retained.';v2d10_io('writejson',statusPath,state);
        fprintf('[%d/%d this session; %d/540 new +360 cached] %s | IGD10000=%g HV1.1=%g feasibleND=%d\n',...
            completed,numel(pending),state.CompletedNew,r.ID,r.IGD10000,r.HVr1p1,r.FeasibleND);
        clear r;
        if mod(completed,30)==0
            state.Status='summarizing';state.UpdatedUTC=utc_now();v2d10_io('writejson',statusPath,state);
            v2d10_summarize(root,mod(completed,90)==0);
        end
    end
    final=v2d10_inventory(root,tasks);state.CompletedNew=final.Completed;
    state.CompletedCombined=360+final.Completed;state.Pending=final.Pending;
    state.RetainedUnfinished=final.Retained;state.ImportedCompleted=final.ImportedCompleted;
    state.ComputedCompleted=final.ComputedCompleted;state.ElapsedSeconds=toc(timer);state.UpdatedUTC=utc_now();
    if isempty(stopReason) && final.Completed==540 && final.Retained==0
        state.Status='summarizing';state.Message='All fixed trials completed; final independent artifact/statistics audit.';
        v2d10_io('writejson',statusPath,state);v2d10_summarize(root,true);
        state.Status='completed';state.Message='540 fixed new slots and360 cached records complete;900 combined in30 groups.';
    else
        if isempty(stopReason),stopReason='incomplete_inventory';end
        % A protective stop preserves the last rolling reports and all raw
        % records; a full audit is performed only on normal completion or by
        % the explicit summarize command when resources are available.
        state.Status=['stopped_',stopReason];
        state.Message=sprintf('Stopped before starting another trial; completed%d/540, pending%d, retained%d. No automatic retry.',final.Completed,final.Pending,final.Retained);
    end
    state.EndedUTC=utc_now();state.UpdatedUTC=utc_now();state.ElapsedSeconds=toc(timer);
    v2d10_io('writejson',statusPath,state);fprintf('%s\n',state.Message);
catch e
    state.Status='stopped_on_error';state.UpdatedUTC=utc_now();state.EndedUTC=utc_now();state.ElapsedSeconds=toc(timer);
    state.Message=getReport(e,'extended','hyperlinks','off');state.Errors={state.Message};
    try,v2d10_io('writejson',statusPath,state);catch,end
    rethrow(e);
end
end
function [memoryGB,diskGB]=resource_snapshot(out)
[~,system]=memory;
assert(isfield(system,'PhysicalMemory') && isfield(system.PhysicalMemory,'Available'),...
    'V2_Ablation_D10:MemoryProbe','Cannot determine available Windows physical memory; no new trial started.');
memoryGB=double(system.PhysicalMemory.Available)/2^30;
diskGB=double(java.io.File(out).getUsableSpace())/2^30;
assert(isfinite(memoryGB) && memoryGB>=0 && isfinite(diskGB) && diskGB>=0,...
    'V2_Ablation_D10:ResourceProbe','Resource probe returned invalid values.');
end
function [file,lock]=acquire_lock(out)
file=java.io.RandomAccessFile(fullfile(out,'coordinator.lock'),'rw');
try,lock=file.getChannel().tryLock();
catch e,file.close();error('V2_Ablation_D10:ControllerBusy','Cannot acquire coordinator lock: %s',e.message);end
if isempty(lock),file.close();error('V2_Ablation_D10:ControllerBusy','Another controller/postprocessor owns this output.');end
end
function close_lock(lock,file)
try,if lock.isValid(),lock.release();end,catch,end
try,file.close();catch,end
end
function mark_interrupted(path,sessionID)
try
    s=v2d10_io('json',path);
    if strcmp(s.SessionID,sessionID) && ismember(s.Status,{'starting','running','awaiting_resources','summarizing'})
        s.Status='interrupted';s.Message='Serial controller interrupted; all trial records retained; no automatic retry.';
        s.UpdatedUTC=utc_now();s.InterruptedUTC=utc_now();v2d10_io('writejson',path,s);
    end
catch
end
end
function s=utc_now()
s=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
