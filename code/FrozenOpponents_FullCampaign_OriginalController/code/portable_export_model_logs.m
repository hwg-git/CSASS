function portable_export_model_logs(r,dest)
n=numel(r.stages);M=r.problem.M;selection=zeros(n,13);pred=zeros(n*10*(M+1),10);ids=zeros(n*100,3);times=zeros(n,2);
for i=1:n
 s=r.stages(i);selection(i,:)=[s.stage,s.FEbefore,s.FEafter,s.usedChoice,s.nextChoice,s.scores.aggregateRBF,s.scores.aggregateKriging,s.rbfRank,s.infillSupplementCount];
 ids((i-1)*100+(1:100),:)=[repmat(i,100,1),(1:100)',s.trainingEvaluationIDs];times(i,:)=[i,s.fitSeconds];
 for j=1:M+1
  ix=(i-1)*10*(M+1)+(j-1)*10+(1:10);
  pred(ix,:)=[repmat(i,10,1),s.newEvaluationIDs,repmat(j,10,1),s.truth(:,j),s.predictedRBF(:,j),s.predictedKriging(:,j),repmat(s.scores.rbf(j),10,1),repmat(s.scores.kriging(j),10,1),repmat(s.scores.rbfRMSE(j),10,1),repmat(s.scores.krigingRMSE(j),10,1)];
 end
end
portable_write_csv(fullfile(dest,'model_selection.csv'),{'Stage','FEbefore','FEafter','UsedObjectiveModel','UsedConstraintModel','NextObjectiveModel','NextConstraintModel','R2RBFObjectives','R2RBFConstraint','R2KrigingObjectives','R2KrigingConstraint','RBFMatrixRank','InfillSupplementCandidates'},selection);
portable_write_csv(fullfile(dest,'prediction_errors.csv'),{'Stage','EvaluationID','ResponseIndex','Truth','RBFprediction','KrigingPrediction','BatchR2RBF','BatchR2Kriging','BatchRMSERBF','BatchRMSEKriging'},pred);
portable_write_csv(fullfile(dest,'training_ids.csv'),{'Stage','TrainingPosition','EvaluationID'},ids);
portable_write_csv(fullfile(dest,'fit_times.csv'),{'Stage','FitSeconds'},times);
end
