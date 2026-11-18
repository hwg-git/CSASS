function report=v2all_summary_fixture(root)
% Synthetic integration QA only. No optimizer, objective, or model is called.
% All generated records and summaries stay in a separate temporary package.
% The temporary directory is retained as evidence and is NOT experiment data.
if nargin<1,root=fileparts(fileparts(mfilename('fullpath')));end
root=char(java.io.File(root).getCanonicalPath());
lockPath=fullfile(root,'source_lock.json');
assert(isfile(lockPath),'V2_AllBenchmarks:FixtureLock','Freeze source_lock.json before this fixture.');
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
addpath(fullfile(tempRoot,'code'),'-begin');clear_v2all_interfaces();rehash;
assert(strcmpi(which('v2all_summarize'),fullfile(tempRoot,'code','v2all_summarize.m')));

% Phase A: the seven real cached groups alone do not imply new experiments ran.
a0=v2all_summarize(tempRoot,true);
assert(strcmp(a0.Status,'in_progress') && ~a0.AllExperimentsComplete);
assert(a0.NewComplete==0 && a0.ReusedComplete==210 && a0.CombinedComplete==210);
assert(a0.ArtifactFilesVerified==0 && a0.ExcelWritten);
out=fullfile(tempRoot,'outputs','V2_AllBenchmarks','tables');
T0=readtable(fullfile(out,'all_runs.csv'),'TextType','string');
G0=readtable(fullfile(out,'group_summary.csv'),'TextType','string');
P0=readtable(fullfile(out,'group_progress.csv'),'TextType','string');
assert(height(T0)==210 && all(T0.Origin=="cached") && ~any(T0.TraceAvailable));
assert(height(G0)==72 && sum(G0.Runs==30)==7 && sum(G0.Runs==0)==65);
assert(sum(P0.Pending)==1950 && sum(P0.Retained)==0);
assert(all(isnan(G0.IGDMean30(G0.Runs==0))));
check_baselines(G0);
X0=readtable(fullfile(out,'results.xlsx'),'Sheet','All_runs','TextType','string');
assert(height(X0)==210);
assert(sum(T0.FinalObjectivesAvailable)==120 && all(T0.M==2));
assert(~isfile(fullfile(out,'selection_frequency.csv')) && ~isfile(fullfile(out,'prediction_accuracy.csv')));
v2all_io('writejson',fullfile(tempRoot,'baseline_only_audit.json'),a0);

% Phase B: one completed synthetic trial is not a completed 30-seed group.
tasks=v2all_tasks(tempRoot);
ix=find(strcmp({tasks.Version},'V2') & strcmp({tasks.Problem},'CF1') & [tasks.D]==10 & [tasks.Seed]==1);
assert(isscalar(ix));task=tasks(ix);
dest=fullfile(tempRoot,'outputs','V2_AllBenchmarks','runs',task.ID);mkdir(dest);
write_synthetic_trial(task,dest);
a1=v2all_summarize(tempRoot,true);
assert(strcmp(a1.Status,'in_progress') && ~a1.AllExperimentsComplete);
assert(a1.NewComplete==1 && a1.ReusedComplete==210 && a1.CombinedComplete==211);
assert(a1.RetainedIncomplete==0 && a1.ArtifactFilesVerified==13 && a1.ExcelWritten);
T=readtable(fullfile(out,'all_runs.csv'),'TextType','string');
G=readtable(fullfile(out,'group_summary.csv'),'TextType','string');
P=readtable(fullfile(out,'group_progress.csv'),'TextType','string');
assert(height(T)==211 && numel(unique(T.ID))==211 && sum(T.Origin=="new")==1);
assert(sum(T.TraceAvailable)==1 && sum(P.Pending)==1949 && sum(P.Completed)==211);
assert(sum(T.FinalObjectivesAvailable)==121 && all(T.M==2));
new=T.ID==string(task.ID);assert(sum(new)==1 && isinf(T.IGD10000(new)) && T.FeasibleND(new)==0);
assert(all([T.HVr1p1(new),T.HVr3(new),T.HVr20(new)]==0));
k=G.Version=="V2" & G.Problem=="CF1" & G.D==10;
assert(sum(k)==1 && G.Runs(k)==1 && G.FiniteIGDRuns(k)==0);
assert(isnan(G.IGDMean30(k)) && isnan(G.IGDStd30(k)) && isnan(G.IGDConditionalMean(k)));
assert(isnan(G.HVr1p1Mean30(k)) && G.ZeroHVRuns(k)==1 && G.IGDDisplay(k)=="PENDING [1/30]");
check_baselines(G);
S=readtable(fullfile(out,'selection_frequency.csv'),'TextType','string');
assert(height(S)==1 && S.Version=="V2" && S.Problem=="CF1");
assert(S.TrialsWithLogs==1 && S.Stages==40 && S.UsedRBFObjective==20 && S.UsedKrigingObjective==20);
assert(S.UsedRBFConstraint==0 && S.UsedKrigingConstraint==40);
assert(S.RBFObjectiveProportion==0.5 && S.RBFConstraintProportion==0);
assert(S.ObjectiveChoiceChanges==2 && S.ConstraintChoiceChanges==0);
assert(S.ObjectiveUsedSwitches==1 && S.ConstraintUsedSwitches==0);
assert(S.FinalUnusedObjectiveChanges==1 && S.FinalUnusedConstraintChanges==0);
assert(S.RunsWithObjectiveSwitches==1 && S.RunsWithConstraintSwitches==0);
E=readtable(fullfile(out,'prediction_accuracy.csv'),'TextType','string');
assert(height(E)==3 && isequal(sort(E.ResponseIndex),(1:3)') && all(E.Observations==400));
assert(all(E.RBFRMSE==1 & E.KrigingRMSE==2 & E.RBFMAE==1 & E.KrigingMAE==2));
F=readtable(fullfile(out,'stage_flags.csv'),'TextType','string');
assert(height(F)==40 && all(F.ID==string(task.ID)));
assert(sum(F.ObjectiveChoiceChanged)==2 && sum(F.ConstraintChoiceChanged)==0);
assert(all(F.ObjectiveR2Undefined==1 & F.ConstraintR2Undefined==1));
X=readtable(fullfile(out,'results.xlsx'),'Sheet','All_runs','TextType','string');
XS=readtable(fullfile(out,'results.xlsx'),'Sheet','Model_selection','TextType','string');
XE=readtable(fullfile(out,'results.xlsx'),'Sheet','Prediction_accuracy','TextType','string');
assert(height(X)==211 && height(XS)==1 && height(XE)==3);
% XLSX must preserve nonfinite scientific values as explicit text. MATLAB's
% numeric Inf export can otherwise become the finite sentinel 65535.
XC=readcell(fullfile(out,'results.xlsx'),'Sheet','All_runs');
headers=string(XC(1,:));idCol=find(headers=="ID");assert(isscalar(idCol));
row=find(strcmp(string(XC(2:end,idCol)),string(task.ID)))+1;assert(isscalar(row));
for label={"IGD10000","IGD2000"}
    col=find(headers==label{1});assert(isscalar(col));value=XC{row,col};
    assert((ischar(value)||isstring(value)) && strcmp(string(value),"Inf"),...
        'LIR24:ExcelNonfinite','Excel %s must contain literal text Inf, not numeric 65535.',label{1});
end
col=find(headers=="HVr1p1");assert(isnumeric(XC{row,col}) && XC{row,col}==0);
assert(isequal(beforeOutputs,output_snapshot(root)),'Source-package outputs changed during isolated QA.');
report=struct('Status','pass','SyntheticOnly',true,'OptimizationRuns',0,'TrueEvaluations',0,...
    'ModelFits',0,'BaselineOnlyCombined',210,'OneSyntheticCombined',211,'NewSyntheticTrials',1,...
    'ModelSelectionStages',40,'PredictionObservations',1200,'ArtifactHashesVerified',13,...
    'ExcelReadbackPassed',true,'ExcelInfTextVerified',true,'SourceOutputsUnchanged',true,'TemporaryPackage',tempRoot,...
    'TemporaryTables',out,'Warning','Synthetic QA records are not scientific experiment results.');
v2all_io('writejson',fullfile(tempRoot,'fixture_report.json'),report);
fprintf('SUMMARY FIXTURE PASS: 0 optimization runs; synthetic-only evidence retained at %s\n',tempRoot);
end

function check_baselines(G)
v=G.Version=="V2" & G.Problem=="LIRCMOP1" & G.D==10;
c=G.Version=="V2" & G.Problem=="LIRCMOP3" & G.D==10;
assert(sum(v)==1 && sum(c)==1 && G.Runs(v)==30 && G.Runs(c)==30);
assert(G.FiniteIGDRuns(v)==30 && abs(G.IGDMean30(v)-0.4142279446716474)<1e-12);
assert(abs(G.IGDStd30(v)-0.0641618024460537)<1e-12);
assert(G.FiniteIGDRuns(c)==30 && abs(G.IGDMean30(c)-0.3770657858483033)<1e-12);
assert(abs(G.IGDStd30(c)-0.055466505092600336)<1e-12 && G.ZeroHVRuns(c)==0);
assert(abs(G.HVr1p1Mean30(v)-0.20003928864337514)<1e-12);
assert(abs(G.HVr1p1Mean30(c)-0.21680695213523257)<1e-12);
end

function write_synthetic_trial(task,dest)
% Hand-constructed numeric arrays only. FE=500 describes the fake fixture schema.
r=struct('ID',task.ID,'Version',task.Version,'Problem',task.Problem,'D',10,'M',2,'FinalObjectivesAvailable',true,'Seed',task.Seed,...
    'FE',500,'N',100,'Pmax',20,'K',10,'RequestedPF',10000,'Scale',1,...
    'status','completed','Status','completed','RuntimeSeconds',0,'ElapsedSeconds',0,...
    'SyntheticFixture',true,'FeasibleND',0,'NonfiniteIGD',true,'IGD10000',NaN,'IGD2000',NaN,...
    'HVr1p1',0,'HVr3',0,'HVr20',0,'Source','SYNTHETIC_QA_ONLY');
v2all_io('writejson',fullfile(dest,'result.json'),r);
v2all_io('writejson',fullfile(dest,'configuration.json'),struct('Task',task,'SyntheticFixture',true));
xnames=cellstr(compose('x%d',1:10));
stage=[zeros(100,1);repelem((1:40)',10)];
v2all_io('csv',fullfile(dest,'precision_ledger.csv'),...
    [{'EvaluationID','Stage'},xnames,{'f1','f2','g1','g2','g3','CV'}],...
    [(1:500)',stage,zeros(500,12),ones(500,3),3*ones(500,1)]);
v2all_io('csv',fullfile(dest,'final_objectives.csv'),{'f1','f2'},zeros(0,2));
v2all_io('csv',fullfile(dest,'final_decisions.csv'),xnames,zeros(0,10));
z=struct();z.problem=struct('M',2,'D',10);z.stages=struct([]);
for i=1:40
    used=1+double(i>20);next=1+double(i>=20);
    if i==40,next=1;end % An unused final decision must not inflate used switches.
    scores=struct('aggregateRBF',[NaN,NaN],'aggregateKriging',[NaN,NaN],...
        'rbf',nan(1,3),'kriging',nan(1,3),'rbfRMSE',ones(1,3),'krigingRMSE',2*ones(1,3));
    s=struct('stage',i,'FEbefore',100+(i-1)*10,'FEafter',100+i*10,...
        'newEvaluationIDs',(101+(i-1)*10:100+i*10)','trainingEvaluationIDs',(1:100)',...
        'usedChoice',[used,2],'nextChoice',[next,2],'scores',scores,'rbfRank',0,...
        'infillSupplementCount',0,'fitSeconds',0,'truth',zeros(10,3),...
        'predictedRBF',ones(10,3),'predictedKriging',2*ones(10,3),...
        'infillLog',struct('initialNovel',10,'generatedLHS',0,'acceptedLHS',0,'selectedLHS',0,'selectedPopulation',10));
    if i==1,z.stages=s;else,z.stages(i)=s;end
end
z.archive=struct('EvaluationID',(1:100)','X',zeros(100,10),'F',zeros(100,2),'CV',ones(100,1));
z.surrogatePopulation=struct('X',zeros(100,10),'F',zeros(100,2),'CV',ones(100,1));
v2all_export_logs(z,dest); % Exporter only: no training, sampling, or objective call.
fixture=struct('SyntheticFixture',true,'ActualEvaluations',0,'ActualModelFits',0,...
    'Description','Synthetic integration QA; intentionally empty final feasible set.');
save(fullfile(dest,'diagnostic_result.mat'),'fixture','-v7');
names={'result.json','precision_ledger.csv','final_objectives.csv','final_decisions.csv',...
    'model_selection.csv','prediction_errors.csv','training_ids.csv','stage_flags.csv','fit_times.csv',...
    'final_training_archive.csv','final_surrogate_population_NOT_TRUE.csv','configuration.json','diagnostic_result.mat'};
files=repmat(struct('Path','','SHA256',''),numel(names),1);
for i=1:numel(names),files(i).Path=names{i};files(i).SHA256=v2all_io('sha',fullfile(dest,names{i}));end
marker=struct('Status','completed','status','completed','ID',task.ID,'Version',task.Version,...
    'Problem',task.Problem,'D',10,'Seed',task.Seed,'FE',500,'Files',files,...
    'SyntheticFixture',true,'CompletedUTC','SYNTHETIC_QA');
v2all_io('writejson',fullfile(dest,'completed.json'),marker);
end

function s=output_snapshot(root)
p=fullfile(root,'outputs');
if ~isfolder(p),s=struct('Exists',false,'Files',{{}});return;end
d=dir(fullfile(p,'**','*'));d=d(~[d.isdir]);
items=cell(numel(d),1);
for i=1:numel(d),items{i}=sprintf('%s|%s|%d|%.17g',d(i).folder,d(i).name,d(i).bytes,d(i).datenum);end
s=struct('Exists',true,'Files',{sort(items)});
end

function clear_v2all_interfaces()
clear v2all_preflight v2all_summarize v2all_inventory v2all_tasks v2all_io v2all_collect v2all_trial
clear v2all_group_statistics v2all_write_table v2all_export_logs v2all_csv v2all_write_excel v2all_trace_statistics
end

function restore_path(savedPath)
path(savedPath);clear_v2all_interfaces();rehash;
end
