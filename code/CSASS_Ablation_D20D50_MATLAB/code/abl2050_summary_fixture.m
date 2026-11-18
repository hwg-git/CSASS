function report=abl2050_summary_fixture(root)
% Synthetic integration QA only. No optimizer, objective, or model is called.
% All generated records and summaries stay in a separate temporary package.
% The temporary directory is retained as evidence and is NOT experiment data.
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
root=char(java.io.File(root).getCanonicalPath());
lockPath=fullfile(root,'source_lock.json');
assert(isfile(lockPath),'Ablation_D20D50:FixtureLock','Freeze source_lock.json before this fixture.');
lock=jsondecode(fileread(lockPath));
beforeOutputs=output_snapshot(root);
savedPath=path;
pathGuard=onCleanup(@()restore_path(savedPath)); %#ok<NASGU>
tempRoot=tempname;mkdir(tempRoot);
for i=1:numel(lock.Files)
    rel=char(lock.Files(i).Path);
    assert(isempty(regexp(rel,'(^[\\/]|^[A-Za-z]:|(^|[\\/])\.\.([\\/]|$))','once')));
    assert(~startsWith(strrep(rel,'\','/'),'outputs/'),'Fixture must not copy experiment outputs.');
    dest=fullfile(tempRoot,rel);parent=fileparts(dest);
    if ~isfolder(parent),mkdir(parent);end
    [ok,msg]=copyfile(fullfile(root,rel),dest);assert(ok,'%s',msg);
end
[ok,msg]=copyfile(lockPath,fullfile(tempRoot,'source_lock.json'));assert(ok,'%s',msg);
fid=fopen(fullfile(tempRoot,'SYNTHETIC_NOT_EXPERIMENTS.txt'),'w');assert(fid>=0);
fprintf(fid,['PURE SYNTHETIC QA: no optimization, true evaluations, or model fitting.\n',...
    'The synthetic run below must never be merged into research results.\n',...
    'Original package: %s\n'],root);fclose(fid);
addpath(fullfile(tempRoot,'code'),'-begin');clear_abl2050_interfaces();rehash;
assert(strcmpi(which('abl2050_summarize'),fullfile(tempRoot,'code','abl2050_summarize.m')));

% Phase A: zero saved runs must yield all60 planned groups as PENDING.
a0=abl2050_summarize(tempRoot,true);
assert(strcmp(a0.Status,'in_progress') && ~a0.AllExperimentsComplete);
assert(a0.NewComplete==0 && a0.ReusedComplete==0 && a0.CombinedComplete==0);
assert(a0.ArtifactFilesVerified==0 && a0.ExcelWritten);
assert(a0.NewlyComputedComplete==0 && a0.ImportedComplete==0);
out=fullfile(tempRoot,'outputs','Ablation_D20D50','tables');
T0=readtable(fullfile(out,'all_runs.csv'),'TextType','string');
G0=readtable(fullfile(out,'group_summary.csv'),'TextType','string');
P0=readtable(fullfile(out,'group_progress.csv'),'TextType','string');
assert(height(T0)==0 && ~any(T0.TraceAvailable));
assert(height(G0)==60 && sum(G0.Runs==30)==0 && sum(G0.Runs==0)==60);
assert(sum(P0.Pending)==1800 && sum(P0.Retained)==0);
assert(all(isnan(G0.IGDMean30(G0.Runs==0))));
assert(all(G0.IGDDisplay=="PENDING"));
AS0=readtable(fullfile(out,'ablation_statistics.csv'),'TextType','string');
AW0=readtable(fullfile(out,'ablation_paper_style.csv'),'TextType','string');
assert(height(AS0)==240 && height(AW0)==60);
assert(~ismember('Version',AW0.Properties.VariableNames));
assert(all(ismember(G0.D,[20,50])) && all(ismember(AS0.D,[20,50])));
assert(~any(AS0.TestAvailable) && all(AS0.Symbol=="PENDING"));
assert(height(unique(G0(:,{'Problem','D','Mode'}),'rows'))==60);
X0=readtable(fullfile(out,'results.xlsx'),'Sheet','All_runs','TextType','string');
assert(height(X0)==0);
assert(sum(T0.FinalObjectivesAvailable)==0);
assert(~isfile(fullfile(out,'selection_frequency.csv')) && ~isfile(fullfile(out,'prediction_accuracy.csv')));
abl2050_io('writejson',fullfile(tempRoot,'empty_summary_audit.json'),a0);

% Phase B: one completed synthetic trial is not a completed 30-seed group.
tasks=abl2050_tasks(tempRoot);
ix=find(strcmp({tasks.Version},'V2') & strcmp({tasks.Problem}, 'CF2') & [tasks.D]==20 & strcmp({tasks.Mode},'rbf_only') & [tasks.Seed]==1);
assert(isscalar(ix));task=tasks(ix);
dest=fullfile(tempRoot,'outputs','Ablation_D20D50','runs',task.ID);mkdir(dest);
write_synthetic_trial(task,dest);
a1=abl2050_summarize(tempRoot,true);
assert(strcmp(a1.Status,'in_progress') && ~a1.AllExperimentsComplete);
assert(a1.NewComplete==1 && a1.ReusedComplete==0 && a1.CombinedComplete==1);
assert(a1.RetainedIncomplete==0 && a1.ArtifactFilesVerified==13 && a1.ExcelWritten);
assert(a1.NewlyComputedComplete==1 && a1.ImportedComplete==0);
T=readtable(fullfile(out,'all_runs.csv'),'TextType','string');
G=readtable(fullfile(out,'group_summary.csv'),'TextType','string');
P=readtable(fullfile(out,'group_progress.csv'),'TextType','string');
assert(height(T)==1 && numel(unique(T.ID))==1 && sum(T.Origin=="new")==1);
assert(sum(T.TraceAvailable)==1 && sum(P.Pending)==1799 && sum(P.Completed)==1);
assert(sum(T.FinalObjectivesAvailable)==1 && all(T.M==2));
new=T.ID==string(task.ID);assert(sum(new)==1 && isinf(T.IGD10000(new)) && T.FeasibleND(new)==0);
assert(all([T.HVr1p1(new),T.HVr3(new),T.HVr20(new)]==0));
k=G.Version=="V2" & G.Problem=="CF2" & G.D==20 & G.Mode=="rbf_only";
assert(sum(k)==1 && G.Runs(k)==1 && G.FiniteIGDRuns(k)==0);
assert(isnan(G.IGDMean30(k)) && isnan(G.IGDStd30(k)) && isnan(G.IGDConditionalMean(k)));
assert(isnan(G.HVr1p1Mean30(k)) && G.ZeroHVRuns(k)==1 && G.IGDDisplay(k)=="PENDING");
assert(height(G)==60 && sum(G.Runs==0)==59 && sum(G.Runs==1)==1);
S=readtable(fullfile(out,'selection_frequency.csv'),'TextType','string');
assert(height(S)==1 && S.Version=="V2" && S.Problem=="CF2" && S.D==20 && S.Mode=="rbf_only");
assert(S.TrialsWithLogs==1 && S.Stages==40 && S.UsedRBFObjective==40 && S.UsedKrigingObjective==0);
assert(S.UsedRBFConstraint==40 && S.UsedKrigingConstraint==0);
assert(S.RBFObjectiveProportion==1 && S.RBFConstraintProportion==1);
assert(S.ObjectiveChoiceChanges==0 && S.ConstraintChoiceChanges==0);
assert(S.ObjectiveUsedSwitches==0 && S.ConstraintUsedSwitches==0);
assert(S.FinalUnusedObjectiveChanges==0 && S.FinalUnusedConstraintChanges==0);
assert(S.RunsWithObjectiveSwitches==0 && S.RunsWithConstraintSwitches==0);
E=readtable(fullfile(out,'prediction_accuracy.csv'),'TextType','string');
assert(height(E)==3 && isequal(sort(E.ResponseIndex),(1:3)') && all(E.Observations==400));
assert(all(E.RBFRMSE==1 & E.KrigingRMSE==2 & E.RBFMAE==1 & E.KrigingMAE==2));
F=readtable(fullfile(out,'stage_flags.csv'),'TextType','string');
assert(height(F)==40 && all(F.ID==string(task.ID)));
assert(sum(F.ObjectiveChoiceChanged)==0 && sum(F.ConstraintChoiceChanged)==0);
assert(all(F.ObjectiveR2Undefined==1 & F.ConstraintR2Undefined==1));
X=readtable(fullfile(out,'results.xlsx'),'Sheet','All_runs','TextType','string');
XS=readtable(fullfile(out,'results.xlsx'),'Sheet','Model_selection','TextType','string');
XE=readtable(fullfile(out,'results.xlsx'),'Sheet','Prediction_accuracy','TextType','string');
assert(height(X)==1 && height(XS)==1 && height(XE)==3);
XAS=readtable(fullfile(out,'results.xlsx'),'Sheet','Ablation_statistics','TextType','string');
XAW=readtable(fullfile(out,'results.xlsx'),'Sheet','Ablation_paper_style','TextType','string');
assert(height(XAS)==240 && height(XAW)==60);
assert(all(XAS.Symbol(XAS.Problem=="CF2"&XAS.D==20)=="PENDING"));
assert(all(F.Mode=="rbf_only") && all(E.Mode=="rbf_only"));
% XLSX must preserve nonfinite scientific values as explicit text. MATLAB's
% numeric Inf export can otherwise become the finite sentinel 65535.
XC=readcell(fullfile(out,'results.xlsx'),'Sheet','All_runs');
headers=string(XC(1,:));idCol=find(headers=="ID");assert(isscalar(idCol));
row=find(strcmp(string(XC(2:end,idCol)),string(task.ID)))+1;assert(isscalar(row));
for label={"IGD10000","IGD2000"}
    col=find(headers==label{1});assert(isscalar(col));value=XC{row,col};
    assert((ischar(value)||isstring(value)) && strcmp(string(value),"Inf"),...
        'Ablation_D20D50:ExcelNonfinite','Excel %s must contain literal text Inf, not numeric 65535.',label{1});
end
col=find(headers=="HVr1p1");assert(isnumeric(XC{row,col}) && XC{row,col}==0);
assert(isequal(beforeOutputs,output_snapshot(root)),'Source-package outputs changed during isolated QA.');
report=struct('Status','pass','SyntheticOnly',true,'OptimizationRuns',0,'TrueEvaluations',0,...
    'ModelFits',0,'EmptySummaryCombined',0,'OneSyntheticCombined',1,'NewSyntheticTrials',1,...
    'ModelSelectionStages',40,'PredictionObservations',1200,'ArtifactHashesVerified',13,...
    'FixedModeTracePassed',true,'D20D50Only',true,'ExcelReadbackPassed',true,'ExcelInfTextVerified',true,'SourceOutputsUnchanged',true,'TemporaryPackage',tempRoot,...
    'TemporaryTables',out,'Warning','Synthetic QA records are not scientific experiment results.');
abl2050_io('writejson',fullfile(tempRoot,'fixture_report.json'),report);
fprintf('SUMMARY FIXTURE PASS: 0 optimization runs; synthetic-only evidence retained at %s\n',tempRoot);
end

function write_synthetic_trial(task,dest)
% Hand-constructed numeric arrays only. FE=500 describes the fake fixture schema.
r=struct('ID',task.ID,'Version',task.Version,'Problem',task.Problem,'D',task.D,'Mode',task.Mode,'M',2,'FinalObjectivesAvailable',true,'Seed',task.Seed,...
    'FE',500,'N',100,'Pmax',20,'K',10,'RequestedPF',10000,'Scale',1,...
    'status','completed','Status','completed','RuntimeSeconds',0,'ElapsedSeconds',0,...
    'SyntheticFixture',true,'FeasibleND',0,'NonfiniteIGD',true,'IGD10000',NaN,'IGD2000',NaN,...
    'HVr1p1',0,'HVr3',0,'HVr20',0,'Source','SYNTHETIC_QA_ONLY');
abl2050_io('writejson',fullfile(dest,'result.json'),r);
abl2050_io('writejson',fullfile(dest,'configuration.json'),struct('Task',task,'SyntheticFixture',true));
xnames=cellstr(compose('x%d',1:task.D));
stage=[zeros(100,1);repelem((1:40)',10)];
abl2050_io('csv',fullfile(dest,'precision_ledger.csv'),...
    [{'EvaluationID','Stage'},xnames,{'f1','f2','g1','g2','g3','CV'}],...
    [(1:500)',stage,zeros(500,task.D+2),ones(500,3),3*ones(500,1)]);
abl2050_io('csv',fullfile(dest,'final_objectives.csv'),{'f1','f2'},zeros(0,2));
abl2050_io('csv',fullfile(dest,'final_decisions.csv'),xnames,zeros(0,task.D));
z=struct();z.problem=struct('M',2,'D',task.D);z.stages=struct([]);
for i=1:40
    used=1;next=1; % RBF-only uses RBF for objectives AND CV at every stage.
    scores=struct('aggregateRBF',[NaN,NaN],'aggregateKriging',[NaN,NaN],...
        'rbf',nan(1,3),'kriging',nan(1,3),'rbfRMSE',ones(1,3),'krigingRMSE',2*ones(1,3));
    s=struct('stage',i,'FEbefore',100+(i-1)*10,'FEafter',100+i*10,...
        'newEvaluationIDs',(101+(i-1)*10:100+i*10)','trainingEvaluationIDs',(1:100)',...
        'usedChoice',[used,1],'nextChoice',[next,1],'scores',scores,'rbfRank',0,...
        'infillSupplementCount',0,'fitSeconds',0,'truth',zeros(10,3),...
        'predictedRBF',ones(10,3),'predictedKriging',2*ones(10,3),...
        'infillLog',struct('initialNovel',10,'generatedLHS',0,'acceptedLHS',0,'selectedLHS',0,'selectedPopulation',10));
    if i==1,z.stages=s;else,z.stages(i)=s;end
end
z.archive=struct('EvaluationID',(1:100)','X',zeros(100,task.D),'F',zeros(100,2),'CV',ones(100,1));
z.surrogatePopulation=struct('X',zeros(100,task.D),'F',zeros(100,2),'CV',ones(100,1));
abl2050_export_logs(z,dest); % Exporter only: no training, sampling, or objective call.
fixture=struct('SyntheticFixture',true,'ActualEvaluations',0,'ActualModelFits',0,...
    'Description','Synthetic integration QA; intentionally empty final feasible set.');
save(fullfile(dest,'diagnostic_result.mat'),'fixture','-v7');
names={'result.json','precision_ledger.csv','final_objectives.csv','final_decisions.csv',...
    'model_selection.csv','prediction_errors.csv','training_ids.csv','stage_flags.csv','fit_times.csv',...
    'final_training_archive.csv','final_surrogate_population_NOT_TRUE.csv','configuration.json','diagnostic_result.mat'};
files=repmat(struct('Path','','SHA256',''),numel(names),1);
for i=1:numel(names),files(i).Path=names{i};files(i).SHA256=abl2050_io('sha',fullfile(dest,names{i}));end
marker=struct('Status','completed','status','completed','ID',task.ID,'Version',task.Version,...
    'Problem',task.Problem,'D',task.D,'Mode',task.Mode,'Seed',task.Seed,'FE',500,'Files',files,...
    'SyntheticFixture',true,'CompletedUTC','SYNTHETIC_QA');
abl2050_io('writejson',fullfile(dest,'completed.json'),marker);
end

function s=output_snapshot(root)
p=fullfile(root,'outputs');
if ~isfolder(p),s=struct('Exists',false,'Files',{{}});return;end
d=dir(fullfile(p,'**','*'));d=d(~[d.isdir]);
items=cell(numel(d),1);
for i=1:numel(d),items{i}=sprintf('%s|%s|%d|%.17g',d(i).folder,d(i).name,d(i).bytes,d(i).datenum);end
s=struct('Exists',true,'Files',{sort(items)});
end

function clear_abl2050_interfaces()
clear abl2050_preflight abl2050_summarize abl2050_inventory abl2050_tasks abl2050_io abl2050_collect abl2050_trial
clear abl2050_group_statistics abl2050_write_table abl2050_export_logs abl2050_csv abl2050_write_excel abl2050_trace_statistics
clear abl2050_ablation_statistics abl2050_empty_runs
end

function restore_path(savedPath)
path(savedPath);clear_abl2050_interfaces();rehash;
end
