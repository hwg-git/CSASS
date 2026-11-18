function report=rt_selftest(root)
% Static paths + synthetic arrays/MEX smoke only. No benchmark optimization.
% Never calls Solve, Evaluation, csass_run_v2 or a benchmark objective.
if nargin<1 || isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
jroot=java.io.File(char(root));root=char(jroot.getCanonicalPath());
oldPath=path;oldRNG=rng;oldThreads=maxNumCompThreads;
restore=onCleanup(@()restore_state(oldPath,oldRNG,oldThreads)); %#ok<NASGU>
maxNumCompThreads(1);
restoredefaultpath;addpath(root,fullfile(root,'code'));
assert(ispc && usejava('jvm'),'The frozen LIBSVM assets require Windows x64 and JVM.');
assert(strcmp(computer('arch'),'win64'),'Only Windows x64 MEX assets are packaged.');
current=fullfile(root,'engines','current_csass');
frozen=fullfile(root,'engines','frozen_opponents');
validation=fullfile(root,'validation','selftests');if ~isfolder(validation),mkdir(validation);end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
token=char(java.util.UUID.randomUUID());
reportFile=fullfile(validation,['selftest_',stamp,'_',token(1:8),'.json']);
report=struct('Status','running','CreatedUTC',rt_now(),'ReportFile',reportFile, ...
 'MATLAB',version,'BenchmarkOptimizationTrials',0,'BenchmarkTrueEvaluations',0, ...
 'SyntheticModelFits',0,'NoTrialDirectoriesTouched',true, ...
 'Scope','Path/static dependency checks, synthetic selector/metric fixtures and one tiny LIBSVM fit.');
try
    M=jsondecode(fileread(fullfile(root,'dependency_manifest.json')));
    for i=1:numel(M)
        file=fullfile(root,strrep(M(i).RelativePath,'/',filesep));
        assert(strcmp(rt_sha256(file),M(i).SHA256),'Frozen dependency changed: %s',M(i).RelativePath);
    end
    report.FrozenDependencyHashCount=numel(M);

    % Namespaced selectors are compared on fixed arrays, not benchmark points.
    addpath(fullfile(current,'code'));v2all_engine_setup(current);
    addpath(fullfile(frozen,'code'));portable_setup(frozen,'HeEMOEA');
    check_exact('csass_v2.environment',fullfile(current,'engines','V2','matlab','+csass_v2','environment.m'));
    check_exact('csass.environment',fullfile(frozen,'scientific_baseline','matlab','+csass','environment.m'));
    fixtures={ ...
        struct('Name','feasible_front_truncation','F',[0 8;1 6;2 5;3 4;4 3;5 2;6 1;8 0;5 8;9 9;2 2;0 0], ...
               'CV',[zeros(10,1);0.2;1],'N',5), ...
        struct('Name','equal_objectives','F',ones(7,2),'CV',zeros(7,1),'N',3), ...
        struct('Name','all_infeasible','F',[1 4;2 3;3 2;4 1],'CV',[4;1;3;2],'N',3), ...
        struct('Name','empty_input','F',zeros(0,2),'CV',zeros(0,1),'N',100)};
    selector=struct('Name',{},'CurrentIDs',{},'OpponentHelperIDs',{},'Equal',{});
    for i=1:numel(fixtures)
        f=fixtures{i};a=csass_v2.environment(f.F,f.CV,f.N);b=csass.environment(f.F,f.CV,f.N);
        assert(isequal(a,b),'Synthetic final-selector mismatch: %s',f.Name);
        selector(i)=struct('Name',f.Name,'CurrentIDs',a(:)','OpponentHelperIDs',b(:)','Equal',true);
    end
    report.SelectorFixtures=selector;
    PF=[0 1;0.5 0.5;1 0];empty=csass_v2.metrics(zeros(0,2),PF,[1.1 1.1]);
    assert(isinf(empty.IGD)&&empty.IGD>0&&empty.HV==0&&empty.FeasibleCount==0, ...
        'Empty-set metric convention must be IGD=Inf and HV=0.');
    report.EmptySetMetrics=struct('IGDIsPositiveInf',true,'HV',empty.HV,'FeasibleCount',0);

    algs={'HeEMOEA','MOL2SMEA','PCSAEA'};
    folders={'HeE-MOEA','MO-L2SMEA','PC-SAEA'};
    checks=struct('Algorithm',{},'ResolvedFunctions',{},'ForeignProtocolPaths',{}, ...
        'StaticRequiredFileCount',{},'StaticRequiredFiles',{},'StaticProducts',{});
    for i=1:3
        % Intentionally insert the other protocol paths before setup. The
        % unchanged setup must remove them, not silently resolve a helper there.
        restoredefaultpath;addpath(root,fullfile(root,'code'),fullfile(frozen,'code'));
        for q=1:3
            if q~=i,addpath(genpath(fullfile(frozen,'protocol_algorithms',folders{q})));end
        end
        portable_setup(frozen,algs{i});
        active=fullfile(frozen,'protocol_algorithms',folders{i});
        parts=strsplit(path,pathsep);foreign={};
        for k=1:numel(parts)
            if is_under(parts{k},fullfile(frozen,'protocol_algorithms')) && ~is_under(parts{k},active)
                foreign{end+1}=parts{k}; %#ok<AGROW>
            end
        end
        assert(isempty(foreign),'Other algorithm protocol paths survived portable_setup.');
        resolved=struct('Name',{},'Path',{});
        common={ ...
            'PROBLEM',fullfile(frozen,'vendor','PlatEMO','Problems','PROBLEM.m'); ...
            'SOLUTION',fullfile(frozen,'vendor','PlatEMO','Problems','SOLUTION.m'); ...
            'ALGORITHM',fullfile(frozen,'vendor','PlatEMO','Algorithms','ALGORITHM.m'); ...
            'PortableLedgerProblem',fullfile(frozen,'code','PortableLedgerProblem.m'); ...
            'NDSort',fullfile(frozen,'vendor','PlatEMO','Algorithms','Utility functions','NDSort.m'); ...
            'UniformPoint',fullfile(frozen,'vendor','PlatEMO','Algorithms','Utility functions','UniformPoint.m'); ...
            'OperatorGA',fullfile(frozen,'vendor','PlatEMO','Algorithms','Utility functions','OperatorGA.m'); ...
            'TournamentSelection',fullfile(frozen,'vendor','PlatEMO','Algorithms','Utility functions','TournamentSelection.m')};
        for k=1:size(common,1)
            actual=check_exact(common{k,1},common{k,2});
            resolved(end+1)=struct('Name',common{k,1},'Path',actual); %#ok<AGROW>
        end
        if i==1
            required={'HeEMOEA','TrainModel','NSGA2ESelection','svmtrain','svmpredict'};
        elseif i==2
            required={'MOL2SMEA','ConstructLinearKRGOS','dace_fit','srgtsKRGFit'};
        else
            required={'PCSAEA','RBFNNPC','EnvironmentalSelection','DataProcess'};
        end
        for k=1:numel(required)
            actual=which(required{k});
            assert(~isempty(actual)&&is_under(actual,active),'Wrong/absent algorithm dependency: %s -> %s',required{k},actual);
            resolved(end+1)=struct('Name',required{k},'Path',actual); %#ok<AGROW>
        end
        [files,products]=matlab.codetools.requiredFilesAndProducts(which(algs{i}));
        assert(~isempty(files),'Static dependency analysis returned no files for %s.',algs{i});
        % Dynamic feval/toolbox/MEX dependencies can exceed this static list;
        % direct path assertions above and the smoke below complement it.
        checks(i)=struct('Algorithm',algs{i},'ResolvedFunctions',resolved, ...
            'ForeignProtocolPaths',{foreign},'StaticRequiredFileCount',numel(files), ...
            'StaticRequiredFiles',{files},'StaticProducts',products);
        if i==1
            assert(exist('svmtrain','file')==3 && exist('svmpredict','file')==3, ...
                'Expected packaged LIBSVM MEX binaries.');
            syntheticX=[0 0;1 0;0 1;1 1];syntheticY=[0;1;2;3];
            % Tiny deterministic linear epsilon-SVR, not a problem evaluation,
            % not a CSASS/control trial, and not counted in the 480-trial manifest.
            report.SyntheticMEXSmokeAttempted=true;
            mexOutput=evalc('model=svmtrain(syntheticY,syntheticX,''-s 3 -t 0 -q''); [prediction,accuracy,decision]=svmpredict(syntheticY,syntheticX,model,''-q'');');
            assert(numel(prediction)==4 && all(isfinite(prediction(:))) && all(isfinite(accuracy(:))) && all(isfinite(decision(:))), ...
                'LIBSVM synthetic smoke returned nonfinite or malformed output.');
            report.SyntheticModelFits=1;
            report.LIBSVMSmoke=struct('Status','pass','SyntheticRows',4,'SyntheticDimensions',2, ...
                'Options','-s 3 -t 0 -q','Predictions',prediction(:)', ...
                'Accuracy',accuracy,'DecisionValues',decision,'CapturedOutput',mexOutput, ...
                'BenchmarkEvaluations',0,'BenchmarkOptimizationTrials',0);
        end
    end
    report.OpponentChecks=checks;
    report.Status='pass';report.FinishedUTC=rt_now();
    report.Limits='Static dependency closure and synthetic checks only; no claim that a 500-FE optimization trial has passed or all JIT paths are warm.';
    rt_json(reportFile,report);
    fprintf('SELFTEST PASS: zero benchmark evaluations, zero benchmark trials; one tiny synthetic LIBSVM fit.\n');
    fprintf('Saved: %s\n',reportFile);
catch err
    report.Status='failed';report.FinishedUTC=rt_now();
    report.Error=struct('Identifier',err.identifier,'Message',err.message,'Report',getReport(err,'extended','hyperlinks','off'));
    rt_json(reportFile,report);rethrow(err);
end
end

function actual=check_exact(name,expected)
actual=which(name);assert(~isempty(actual),'Missing dependency: %s',name);
ja=java.io.File(actual);je=java.io.File(expected);
assert(strcmpi(char(ja.getCanonicalPath()),char(je.getCanonicalPath())), ...
    'PATH conflict for %s: %s',name,actual);
end

function yes=is_under(file,parent)
if isempty(file),yes=false;return;end
jf=java.io.File(char(file));jp=java.io.File(char(parent));
f=lower(char(jf.getCanonicalPath()));p=lower(char(jp.getCanonicalPath()));
yes=strcmp(f,p)||startsWith(f,[p,filesep]);
end

function restore_state(p,r,t)
path(p);rng(r);maxNumCompThreads(t);
end
