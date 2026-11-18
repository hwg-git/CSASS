function output = MAIN_CSASS_RUNTIME(action)
% Controlled Table 9 runtime experiment. No optimization until action='run'.
% MAIN_CSASS_RUNTIME('preflight'|'run'|'status'|'collect'|'stop')
if nargin<1, action='preflight'; end
root=fileparts(mfilename('fullpath'));
oldPath=path; restorePath=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(fullfile(root,'code'));
out=fullfile(root,'outputs','Runtime_Table9_480');
output=[];
switch lower(char(action))
    case 'preflight'
        output=rt_preflight(root); % No benchmark evaluations.
    case 'selftest'
        output=rt_selftest(root); % Synthetic fixtures only, zero benchmark FE.
    case {'status','summarize'}
        output=rt_summarize(root,out);
    case 'collect'
        output=rt_collect(root,out);
        fprintf('RESULT PACKAGE: %s\n',output);
    case 'stop'
        assert(isfolder(out),'No experiment output exists.');
        rt_json(fullfile(out,'STOP_AFTER_CURRENT.json'),struct('RequestedUTC',rt_now()));
        fprintf('The current trial will finish; no next trial will start.\n');
    case 'run'
        output=run_campaign(root,out);
    otherwise
        error('Use preflight, selftest, run, status, collect, or stop.');
end
end

function report=run_campaign(root,out)
% Path and thread changes apply only to this call and are restored on exit.
originalPath=path; restorePath=onCleanup(@()path(originalPath)); %#ok<NASGU>
restoredefaultpath; addpath(root,fullfile(root,'code'));
oldThreads=maxNumCompThreads; maxNumCompThreads(1);
restoreThreads=onCleanup(@()maxNumCompThreads(oldThreads)); %#ok<NASGU>
env=rt_preflight(root);
assert(env.OtherMATLABProcesses==0, ...
    'Another MATLAB process is open. Close other experiments/MATLAB sessions before timing.');
assert(~isempty(env.CPUModel),'CPU metadata unavailable; timing must have an identifiable machine.');
selftest=rt_selftest(root); % No optimization warm-up; synthetic checks only.
assert(strcmp(selftest.Status,'pass'));
if ~isfolder(out), mkdir(out); end
if ~isfolder(fullfile(out,'runs')), mkdir(fullfile(out,'runs')); end
lock=fullfile(out,'coordinator.lock');
% Java mkdir is atomic; MATLAB mkdir alone also succeeds for an existing dir.
lockFile=java.io.File(lock);
assert(lockFile.mkdir(),'Coordinator lock exists. Do not start a second coordinator. See README.');
unlock=onCleanup(@()release_lock(lock)); %#ok<NASGU>
rt_json(fullfile(lock,'owner.json'),struct('PID',feature('getpid'),'Host',env.Host,'StartedUTC',rt_now()));
envFile=fullfile(out,'environment.mat');
identityFields={'Host','CPUModel','PhysicalCores','LogicalProcessors','MATLAB','Architecture','BLAS','LAPACK','Threads','PowerPlan','PackageSHA256'};
if isfile(envFile)
    prior=load(envFile,'environment');
    for k=1:numel(identityFields)
        f=identityFields{k};
        assert(isequaln(env.(f),prior.environment.(f)), ...
            'Resume environment mismatch: %s. Keep this campaign on the original setup.',f);
    end
else
    environment=env; %#ok<NASGU>
    save(envFile,'environment','-v7');
    rt_json(fullfile(out,'environment.json'),env);
end
sessionID=[datestr(now,'yyyymmdd_HHMMSS'),'_',char(java.util.UUID.randomUUID())];
sessionDir=fullfile(out,'sessions'); if ~isfolder(sessionDir), mkdir(sessionDir); end
env.SessionID=sessionID; rt_json(fullfile(sessionDir,[sessionID,'.json']),env);
rt_json(fullfile(sessionDir,[sessionID,'_selftest.json']),selftest);
T=readtable(fullfile(root,'manifest.csv'),'TextType','string');
done=false(height(T),1); retained=strings(0,1);
for i=1:height(T)
    rd=fullfile(out,'runs',char(T.ID(i)));
    if isfile(fullfile(rd,'complete.json'))
        rt_verify_complete(rd,table2struct(T(i,:)),env.PackageSHA256);
        done(i)=true;
    elseif isfolder(rd)
        retained(end+1,1)=T.ID(i); %#ok<AGROW>
    end
end
fprintf('FIXED MANIFEST: 480 trials; completed %d; retained %d; pending %d.\n',sum(done),numel(retained),height(T)-sum(done)-numel(retained));
fprintf('SERIAL EXECUTION: one trial, one compute thread. N=100; FE=500; D=10.\n');
if ~isempty(retained)
    writetable(table(retained,'VariableNames',{'RetainedID'}),fullfile(out,'retained_trials.csv'));
    error('Incomplete/failed records retained. No automatic retries. Send collected data for review.');
end
stopFile=fullfile(out,'STOP_AFTER_CURRENT.json');
% A stop request is consumed on an explicit new run invocation and archived.
if isfile(stopFile)
    movefile(stopFile,fullfile(sessionDir,['stop_before_',sessionID,'.json']));
end
sessionClock=tic; handled=0;
for i=1:height(T)
    if done(i), continue; end
    if isfile(stopFile), fprintf('STOP_AFTER_CURRENT honored; completed trials retained.\n'); break; end
    t=table2struct(T(i,:));
    try
        row=rt_trial(root,out,t,env,sessionID);
    catch err
        rt_summarize(root,out);
        fprintf(2,'STOPPED on %s: %s\nNo automatic retries; previous results retained.\n',char(t.ID),err.message);
        rethrow(err);
    end
    done(i)=true; handled=handled+1;
    fprintf('[%d/480 total] %s | %.3f s | FE=%d | feasibleND=%d | IGD=%g HV1.1=%g\n', ...
        sum(done),row.ID,row.RuntimeSeconds,row.FE,row.FeasibleND,row.IGD,row.HV11);
    if mod(handled,4)==0
        rt_summarize(root,out);
        etaHours=(toc(sessionClock)/handled)*sum(~done)/3600;
        fprintf('Observed session ETA approximately %.2f hours; postprocessing included in ETA.\n',etaHours);
    end
end
report=rt_summarize(root,out);
if all(done)
    for i=1:height(T)
        rt_verify_complete(fullfile(out,'runs',char(T.ID(i))),table2struct(T(i,:)),env.PackageSHA256);
    end
    audit=struct('Status','pass','Trials',480,'Groups',16,'RunsPerGroup',30,'TrueEvaluationsPerRun',500, ...
        'Serial',true,'ComputeThreads',1,'PackageSHA256',env.PackageSHA256,'FinishedUTC',rt_now());
    rt_json(fullfile(out,'final_audit.json'),audit);
    fprintf('ALL 480 TRIALS COMPLETE AND ARTIFACT HASH AUDIT PASSED.\n');
    zipPath=rt_collect(root,out); fprintf('RESULT PACKAGE: %s\n',zipPath);
else
    fprintf('Paused safely after %d completed trials. Resume with MAIN_CSASS_RUNTIME(''run'').\n',sum(done));
end
end

function release_lock(lock)
% Only remove the two exact controller-owned files/directory, never results.
owner=fullfile(lock,'owner.json');
if isfile(owner), delete(owner); end
if isfolder(lock), rmdir(lock); end
end
