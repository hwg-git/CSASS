function row=rt_trial(root,out,t,env,sessionID)
% New orchestration; frozen scientific files are unmodified.
rd=fullfile(out,'runs',char(t.ID));
assert(~isfolder(rd),'Never overwrite an attempted run.'); mkdir(rd);
rt_json(fullfile(rd,'started.json'),struct('Task',t,'SessionID',sessionID,'StartedUTC',rt_now(), ...
    'PackageSHA256',env.PackageSHA256,'PID',feature('getpid')));
oldPath=path; oldRNG=rng;
restore=onCleanup(@()restore_state(oldPath,oldRNG)); %#ok<NASGU>
current=fullfile(root,'engines','current_csass');
frozen=fullfile(root,'engines','frozen_opponents');
H=[]; b=[]; trialClock=tic;
try
    assert(maxNumCompThreads==1,'Thread count changed during campaign.');
    capturedOutput='';
    if strcmp(t.Algorithm,'CSASS')
        addpath(fullfile(current,'code')); v2all_engine_setup(current);
        p=csass_v2.problem(char(t.Problem),t.D);
        opts=struct('N',100,'MaxFE',500,'Pmax',20,'K',10,'Seed',t.Seed, ...
            'Mode','adaptive','RBFKernel','multiquadric','RBFShape',1,'ReferencePoints',2000, ...
            'OutputDirectory','','Verbose',false);
        % The frozen core starts its timer before LHS and stops after final S.
        % Its auxiliary metrics and provenance occur AFTER that internal toc.
        result=csass_run_v2(p,opts);
        runtime=result.runtimeSeconds;
        H=result.history; F=result.finalF; X=result.finalX; initialN=size(result.initialX,1);
        assert(result.FE==500 && numel(result.stages)==40);
        clockMethod='Frozen csass_run_v2 runtimeSeconds: before LHS to final feasible ND set';
        nativeF=zeros(0,p.M); nativeCV=zeros(0,1);
    else
        addpath(fullfile(frozen,'code')); portable_setup(frozen,char(t.Algorithm));
        b=PortableLedgerProblem(char(t.Problem),t.D,100,500);
        b.LedgerCSV=''; % All evaluation records stay in memory during timing.
        a=feval(char(t.Algorithm),'save',1,'outputFcn',@(~,~)[]);
        rng(t.Seed,'twister');
        started=tic;
        capturedOutput=evalc('a.Solve(b);'); % Buffer native messages; do not render during timing.
        H=b.H;
        ids=csass.environment(H.F,H.CV,100);
        ids=ids(H.CV(ids)==0);
        F=H.F(ids,:); X=H.X(ids,:);
        if ~isempty(F)
            nd=~any(csass.dominance(F,zeros(size(F,1),1)),1);
            F=F(nd,:); X=X(nd,:);
        end
        runtime=toc(started); % Same stop boundary as CSASS, not a.Solve alone.
        initialN=b.InitialN;
        assert(b.FE==500 && b.N==100 && size(H.X,1)==500);
        nativeF=zeros(0,size(F,2)); nativeCV=zeros(0,1);
        if ~isempty(a.result)
            native=a.result{end,2}; nativeF=native.objs;
            nativeCV=sum(max(0,native.cons),2);
        end
        result=struct('history',H,'finalF',F,'finalX',X,'nativeFinalF',nativeF, ...
            'nativeFinalCV',nativeCV,'runtimeSeconds',runtime,'InitialN',initialN, ...
            'TruncatedRows',b.TruncatedRows,'FE',b.FE);
        clockMethod='External tic before Solve; toc after common final selection and feasible ND extraction';
    end
    assert(initialN==100 && size(H.X,1)==500 && isequal(H.EvaluationID,(1:500)'));
    assert(all(isfinite(H.F),'all') && all(isfinite(H.G),'all'));
    assert(isequal(H.CV,sum(max(0,H.G),2)) && isfinite(runtime) && runtime>0);
    % Common postprocessing outside all recorded algorithm runtime intervals.
    addpath(fullfile(current,'code')); v2all_engine_setup(current);
    PFfile=fullfile(current,'references','PF10000',[char(t.Problem),'.csv']);
    PF=readmatrix(PFfile); z=csass_v2.metrics(F,PF,[1.1,1.1]);
    fid=fopen(fullfile(rd,'algorithm_console.txt'),'w','n','UTF-8'); assert(fid>=0);
    fprintf(fid,'%s',capturedOutput); fclose(fid);
    save(fullfile(rd,'diagnostic_result.mat'),'result','t','env','clockMethod','-v7.3');
    write_matrix(fullfile(rd,'final_objectives.csv'),F,'f');
    write_matrix(fullfile(rd,'final_decisions.csv'),X,'x');
    names=[{'EvaluationID','Stage'},cellstr(compose('x%d',1:size(H.X,2))), ...
        cellstr(compose('f%d',1:size(H.F,2))),cellstr(compose('g%d',1:size(H.G,2))),{'CV'}];
    L=array2table([H.EvaluationID,H.Stage,H.X,H.F,H.G,H.CV],'VariableNames',names);
    writetable(L,fullfile(rd,'precision_ledger.csv'));
    row=struct('ID',char(t.ID),'Problem',char(t.Problem),'D',t.D,'Algorithm',char(t.Algorithm), ...
        'Seed',t.Seed,'Status','completed','FE',500,'InitialN',initialN,'FeasibleND',size(F,1), ...
        'RuntimeSeconds',runtime,'TrialWallSeconds',toc(trialClock),'IGD',z.IGD,'HV11',z.HV);
    writetable(struct2table(row),fullfile(rd,'result_row.csv'));
    rt_json(fullfile(rd,'configuration.json'),struct('Task',t,'SessionID',sessionID, ...
        'Timing',clockMethod,'Threads',1,'ConcurrentTrials',1,'DiskLoggingInsideTimer',false, ...
        'Includes','Initialization, true evaluations, fitting, search, in-memory bookkeeping, final extraction', ...
        'Excludes','MATLAB startup, path setup, object construction, IGD/HV, plotting, disk exports', ...
        'ReferenceFrontSHA256',rt_sha256(PFfile),'ReferenceRequest',10000,'ReferenceActual',size(PF,1), ...
        'HVReference',[1.1,1.1],'PackageSHA256',env.PackageSHA256));
    files={'diagnostic_result.mat','final_objectives.csv','final_decisions.csv','precision_ledger.csv','result_row.csv','configuration.json','started.json','algorithm_console.txt'};
    A=struct('File',{},'SHA256',{});
    for k=1:numel(files), A(k)=struct('File',files{k},'SHA256',rt_sha256(fullfile(rd,files{k}))); end
    complete=row; complete.Row=row; complete.Artifacts=A; complete.PackageSHA256=env.PackageSHA256;
    complete.FinishedUTC=rt_now();
    % JSON encodes Inf as null; result_row.csv and MAT retain the true Inf.
    complete.IGDIsFinite=isfinite(row.IGD);
    rt_json(fullfile(rd,'complete.json'),complete); % Last commit marker only.
catch err
    % Export any in-memory record after the failed timer; never replace a run.
    if ~isempty(b), H=b.H; end
    if ~isempty(H), save(fullfile(rd,'failed_history.mat'),'H','t','-v7.3'); end
    failure=struct('ID',char(t.ID),'Status','failed','Message',err.message, ...
        'Identifier',err.identifier,'Report',getReport(err,'extended','hyperlinks','off'), ...
        'UTC',rt_now(),'SessionID',sessionID,'NoAutomaticRetry',true);
    rt_json(fullfile(rd,'failed.json'),failure); rethrow(err);
end
end

function write_matrix(file,A,prefix)
names=cellstr(compose([prefix,'%d'],1:size(A,2)));
writetable(array2table(A,'VariableNames',names),file);
end
function restore_state(p,r)
path(p); rng(r);
end
