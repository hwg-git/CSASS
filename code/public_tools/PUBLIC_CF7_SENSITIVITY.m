function summary=PUBLIC_CF7_SENSITIVITY(releaseRoot,action)
% Release packaging wrapper; the frozen optimization core is unchanged.
% This file is not the original historical campaign controller.
% Reproduced outputs are separate from the published, frozen data.
if nargin<2 || isempty(action), action='plan'; end
action=lower(char(action)); summary=[];
grid=[20,10;40,10;60,10;80,10;100,10;20,5;20,15;20,20;20,30];
assert(ismember(action,{'plan','preflight','run','status','summarize'}), ...
    'Sensitivity action must be plan, preflight, run, status or summarize.');
engineRoot=fullfile(releaseRoot,'code','CSASS_AllBenchmarks_MATLAB');
out=fullfile(releaseRoot,'reproduced','sensitivity_cf7');
if strcmp(action,'plan')
    disp(array2table(grid,'VariableNames',{'Pmax','K'}));
    fprintf('CF7 D10; N100; exact FE500; seeds1:30; nine groups,270 runs.\n');
    fprintf('One process, one compute thread; explicit run starts a NEW reproduction.\n');
    fprintf('The publication data reuse30 default runs; this wrapper reruns all270.\n');
    fprintf('Published data are not changed. No optimization started.\n'); return;
end
if ismember(action,{'status','summarize'})
    summary=read_summaries(out,grid);
    disp(summary);
    fprintf('%d/270 completed reproduction trials.\n',height(summary)); return;
end
oldPath=path; restorePath=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(fullfile(engineRoot,'code'),'-begin'); v2all_engine_setup(engineRoot);
lock=jsondecode(fileread(fullfile(engineRoot,'source_lock.json')));
checked=0;
for i=1:numel(lock.Files)
    rel=char(lock.Files(i).Path);
    if startsWith(rel,'engines/V2/matlab/') || startsWith(rel,'benchmarks/')
        file=fullfile(engineRoot,strrep(rel,'/',filesep));
        assert(isfile(file) && strcmpi(v2all_io('sha',file),lock.Files(i).SHA256), ...
            'Frozen source mismatch: %s',rel);
        checked=checked+1;
    end
end
assert(checked>=49,'Incomplete core/benchmark source lock.');
assert(isfile(fullfile(engineRoot,'references','PF10000','CF7.csv')));
fprintf('Frozen source check passed (%d files); CF7 PF10000 available.\n',checked);
if strcmp(action,'preflight'), fprintf('No optimization started.\n'); return; end
if ~isfolder(out), mkdir(out); end
lockDir=fullfile(out,'coordinator.lock');
coordinator=java.io.File(lockDir);
assert(coordinator.mkdir(),'Sensitivity coordinator lock exists; no concurrent controller allowed.');
lockGuard=onCleanup(@()release_lock(lockDir)); %#ok<NASGU>
oldThreads=maxNumCompThreads; maxNumCompThreads(1);
threadGuard=onCleanup(@()maxNumCompThreads(oldThreads)); %#ok<NASGU>
for g=1:size(grid,1)
    for seed=1:30
        id=sprintf('CF7_D10_P%03d_K%03d_seed%02d',grid(g,1),grid(g,2),seed);
        dest=fullfile(out,'runs',id); marker=fullfile(dest,'completed.json');
        if isfile(marker)
            saved=jsondecode(fileread(marker));
            assert(strcmp(saved.ID,id)&&saved.FE==500&&saved.Pmax==grid(g,1)&&saved.K==grid(g,2)&&saved.Seed==seed);
            continue;
        end
        assert(~isfolder(dest),'Retained partial trial %s. No automatic retry or overwrite.',id);
        mkdir(dest);
        o=struct('N',100,'MaxFE',500,'Pmax',grid(g,1),'K',grid(g,2), ...
            'Seed',seed,'Mode','adaptive','RBFKernel','multiquadric', ...
            'RBFShape',1,'RBFRidge',0,'KrigingMaxFunEvals',120,'KrigingMaxIter',80, ...
            'KrigingThetaMin',1e-3,'KrigingThetaMax',100,'KrigingNugget',1e-10, ...
            'CrossoverProbability',1,'CrossoverEta',20,'MutationExpected',1,'MutationEta',20, ...
            'FeasibilityTolerance',0,'DuplicateTolerance',1e-10,'R2VarianceTolerance',0, ...
            'ReferencePoints',10000,'HVReference',[1.1,1.1],'OutputDirectory','','Verbose',false);
        task=struct('ID',id,'Problem','CF7','D',10,'Seed',seed,'N',100,'FE',500,'Pmax',grid(g,1),'K',grid(g,2));
        v2all_io('writejson',fullfile(dest,'started.json'),task);
        v2all_io('writejson',fullfile(dest,'configuration.json'),struct('Task',task,'Options',o,'Wrapper','Public release wrapper; frozen core unchanged'));
        try
            p=csass_v2.problem('CF7',10);
            result=csass_run_v2(p,o);
            assert(result.FE==500&&size(result.history.X,1)==500);
            assert(numel(result.stages)==ceil(400/o.K));
            z=v2all_metrics(engineRoot,result.finalF,'CF7');
            r=task; fields=fieldnames(z);
            for k=1:numel(fields), r.(fields{k})=z.(fields{k}); end
            r.Status='completed';r.RuntimeSeconds=result.runtimeSeconds;
            r.TrueFeasibleEvaluations=sum(result.history.CV==0);
            v2all_csv(fullfile(dest,'final_objectives.csv'),{'f1','f2'},result.finalF);
            v2all_csv(fullfile(dest,'final_decisions.csv'),cellstr(compose('x%d',1:10)),result.finalX);
            H=result.history;
            headers=[{'EvaluationID','Stage'},cellstr(compose('x%d',1:10)),{'f1','f2'},cellstr(compose('g%d',1:size(H.G,2))),{'CV'}];
            v2all_csv(fullfile(dest,'precision_ledger.csv'),headers,[H.EvaluationID,H.Stage,H.X,H.F,H.G,H.CV]);
            export_stage_logs(result,dest);
            save(fullfile(dest,'diagnostic_result.mat'),'result','-v7.3');
            v2all_io('writejson',fullfile(dest,'result.json'),r);
            v2all_io('writejson',marker,r);
            fprintf('%s IGD10000=%g HV1.1=%g feasibleND=%d\n',id,r.IGD10000,r.HVr1p1,r.FeasibleND);
        catch err
            v2all_io('writejson',fullfile(dest,'failure.json'),struct('Task',task,'Error',getReport(err,'extended','hyperlinks','off')));
            rethrow(err);
        end
    end
end
summary=read_summaries(out,grid);
assert(height(summary)==270);
writetable(summary,fullfile(out,'run_metrics.csv'));
fprintf('270 reproduced sensitivity trials saved in %s\n',out);
end

function t=read_summaries(out,grid)
rows=struct([]);
for g=1:size(grid,1)
    for seed=1:30
        id=sprintf('CF7_D10_P%03d_K%03d_seed%02d',grid(g,1),grid(g,2),seed);
        file=fullfile(out,'runs',id,'completed.json');
        if isfile(file)
            s=jsondecode(fileread(file));
            if s.FeasibleND==0,igd=Inf;else,igd=s.IGD10000;assert(isscalar(igd)&&isfinite(igd));end
            row=struct('ID',string(s.ID),'Problem',"CF7",'D',10,'Pmax',s.Pmax,'K',s.K,'Seed',s.Seed,'FE',s.FE, ...
                'IGD10000',igd,'HVr1p1',s.HVr1p1,'FeasibleND',s.FeasibleND);
            if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
        end
    end
end
if isempty(rows), t=table();else,t=struct2table(rows);end
end
function release_lock(folder)
if isfolder(folder), rmdir(folder); end
end

function export_stage_logs(result,dest)
% K varies, including a shortened final batch; never assume40 stages or10 points.
n=numel(result.stages);M=result.problem.M;selection=zeros(n,13);pred=zeros(0,10);training=zeros(0,3);
for i=1:n
    s=result.stages(i);b=numel(s.newEvaluationIDs);a=numel(s.trainingEvaluationIDs);
    selection(i,:)=[s.stage,s.FEbefore,s.FEafter,s.usedChoice,s.nextChoice, ...
        s.scores.aggregateRBF,s.scores.aggregateKriging,s.rbfRank,s.infillSupplementCount];
    training=[training;repmat(i,a,1),(1:a)',s.trainingEvaluationIDs]; %#ok<AGROW>
    for j=1:M+1
        pred=[pred;repmat(i,b,1),s.newEvaluationIDs,repmat(j,b,1),s.truth(:,j), ...
            s.predictedRBF(:,j),s.predictedKriging(:,j),repmat(s.scores.rbf(j),b,1), ...
            repmat(s.scores.kriging(j),b,1),repmat(s.scores.rbfRMSE(j),b,1),repmat(s.scores.krigingRMSE(j),b,1)]; %#ok<AGROW>
    end
end
v2all_csv(fullfile(dest,'model_selection.csv'),{'Stage','FEbefore','FEafter','UsedObjectiveModel', ...
    'UsedConstraintModel','NextObjectiveModel','NextConstraintModel','R2RBFObjectives','R2RBFConstraint', ...
    'R2KrigingObjectives','R2KrigingConstraint','RBFMatrixRank','InfillSupplementCandidates'},selection);
v2all_csv(fullfile(dest,'prediction_errors.csv'),{'Stage','EvaluationID','ResponseIndex','Truth', ...
    'RBFprediction','KrigingPrediction','BatchR2RBF','BatchR2Kriging','BatchRMSERBF','BatchRMSEKriging'},pred);
v2all_csv(fullfile(dest,'training_ids.csv'),{'Stage','TrainingPosition','EvaluationID'},training);
end
