function v2all_export_logs(r,dest)
n=numel(r.stages);M=r.problem.M;
assert(n==40);selection=zeros(n,13);pred=zeros(n*10*(M+1),10);
ids=zeros(n*100,3);flags=nan(n,17);fitTimes=zeros(n,2);
for i=1:n
 s=r.stages(i);assert(numel(s.newEvaluationIDs)==10&&numel(s.trainingEvaluationIDs)==100);
 selection(i,:)=[s.stage,s.FEbefore,s.FEafter,s.usedChoice,s.nextChoice,...
  s.scores.aggregateRBF,s.scores.aggregateKriging,s.rbfRank,s.infillSupplementCount];
 ids((i-1)*100+(1:100),:)=[repmat(i,100,1),(1:100)',s.trainingEvaluationIDs];
 fitTimes(i,:)=[i,s.fitSeconds];
 undef=isnan(s.scores.aggregateRBF)|isnan(s.scores.aggregateKriging);
 flags(i,1:12)=[i,s.FEbefore,s.FEafter,undef,s.usedChoice,s.nextChoice,...
  s.nextChoice~=s.usedChoice,s.infillSupplementCount];
 if isfield(s,'infillLog')
  q=s.infillLog;flags(i,13:17)=[q.initialNovel,q.generatedLHS,q.acceptedLHS,q.selectedLHS,q.selectedPopulation];
 end
 for j=1:M+1
  ix=(i-1)*10*(M+1)+(j-1)*10+(1:10);
  pred(ix,:)=[repmat(i,10,1),s.newEvaluationIDs,repmat(j,10,1),s.truth(:,j),...
   s.predictedRBF(:,j),s.predictedKriging(:,j),repmat(s.scores.rbf(j),10,1),...
   repmat(s.scores.kriging(j),10,1),repmat(s.scores.rbfRMSE(j),10,1),repmat(s.scores.krigingRMSE(j),10,1)];
 end
end
v2all_csv(fullfile(dest,'model_selection.csv'),{'Stage','FEbefore','FEafter','UsedObjectiveModel',...
 'UsedConstraintModel','NextObjectiveModel','NextConstraintModel','R2RBFObjectives','R2RBFConstraint',...
 'R2KrigingObjectives','R2KrigingConstraint','RBFMatrixRank','InfillSupplementCandidates'},selection);
v2all_csv(fullfile(dest,'prediction_errors.csv'),{'Stage','EvaluationID','ResponseIndex','Truth',...
 'RBFprediction','KrigingPrediction','BatchR2RBF','BatchR2Kriging','BatchRMSERBF','BatchRMSEKriging'},pred);
v2all_csv(fullfile(dest,'training_ids.csv'),{'Stage','TrainingPosition','EvaluationID'},ids);
v2all_csv(fullfile(dest,'fit_times.csv'),{'Stage','FitSeconds'},fitTimes);
v2all_csv(fullfile(dest,'stage_flags.csv'),{'Stage','FEbefore','FEafter','ObjectiveR2Undefined',...
 'ConstraintR2Undefined','UsedObjectiveModel','UsedConstraintModel','NextObjectiveModel','NextConstraintModel',...
 'ObjectiveChoiceChanged','ConstraintChoiceChanged','InfillSupplementCandidates','InitialNovel',...
 'GeneratedLHS','AcceptedLHS','SelectedLHS','SelectedPopulation'},flags);
H=r.archive;
v2all_csv(fullfile(dest,'final_training_archive.csv'),[{'EvaluationID'},cellstr(compose('x%d',1:r.problem.D)),...
 cellstr(compose('f%d',1:M)),{'TrueCV'}],[H.EvaluationID,H.X,H.F,H.CV]);
P=r.surrogatePopulation;
v2all_csv(fullfile(dest,'final_surrogate_population_NOT_TRUE.csv'),[cellstr(compose('x%d',1:r.problem.D)),...
 cellstr(compose('predicted_f%d',1:M)),{'PredictedCV'}],[P.X,P.F,P.CV]);
end
