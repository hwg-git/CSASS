function [S,E,Flags,SelectionByStage,PredictionByStage]=v2all_trace_statistics(root,tasksCompleted)
% Pure saved-log postprocessing; never evaluates a problem or fits a model.
% Prediction rows are read one trial at a time. Only grouped sums of squared
% and absolute errors are retained, rather than concatenating every point.
% Used switches compare stages 1:40; the unused final next choice is separate.
S=table();E=table();Flags=table();SelectionByStage=table();PredictionByStage=table();
if isempty(tasksCompleted),return;end
if istable(tasksCompleted),tasksCompleted=table2struct(tasksCompleted);end
assert(isstruct(tasksCompleted),'V2All:TraceTasks','Completed tasks must be a struct array or table.');
taskIDs=string({tasksCompleted.ID});
assert(numel(unique(taskIDs))==numel(taskIDs),'V2All:TraceDuplicate','Duplicate completed task IDs.');
nStages=40;batchSize=10;initialFE=100;
groupIndex=containers.Map('KeyType','char','ValueType','double');
groups=struct([]);flagParts=cell(numel(tasksCompleted),1);
for i=1:numel(tasksCompleted)
    t=tasksCompleted(i);id=char(t.ID);
    runDir=fullfile(root,'outputs','V2_AllBenchmarks','runs',id);
    Z=sortrows(readtable(fullfile(runDir,'model_selection.csv')),'Stage');
    P=readtable(fullfile(runDir,'prediction_errors.csv'));
    F=sortrows(readtable(fullfile(runDir,'stage_flags.csv')),'Stage');
    require_columns(Z,{'Stage','FEbefore','FEafter','UsedObjectiveModel','UsedConstraintModel',...
        'NextObjectiveModel','NextConstraintModel','InfillSupplementCandidates'},id,'selection');
    require_columns(P,{'Stage','EvaluationID','ResponseIndex','Truth','RBFprediction','KrigingPrediction'},id,'prediction');
    require_columns(F,{'Stage','FEbefore','FEafter','UsedObjectiveModel','UsedConstraintModel',...
        'NextObjectiveModel','NextConstraintModel','ObjectiveChoiceChanged','ConstraintChoiceChanged',...
        'InfillSupplementCandidates'},id,'flags');
    stages=(1:nStages)';before=initialFE+(stages-1)*batchSize;after=before+batchSize;
    assert(height(Z)==nStages&&isequal(Z.Stage,stages),'V2All:TraceStages','%s: expected stages 1:40.',id);
    assert(isequal(Z.FEbefore,before)&&isequal(Z.FEafter,after),'V2All:TraceFE','%s: stage FE intervals differ.',id);
    used=Z{:,{'UsedObjectiveModel','UsedConstraintModel'}};
    next=Z{:,{'NextObjectiveModel','NextConstraintModel'}};
    assert(all(ismember(used(:),[1,2]))&&all(ismember(next(:),[1,2])),...
        'V2All:TraceChoices','%s: unknown model choice.',id);
    assert(isequal(next(1:end-1,:),used(2:end,:)),...
        'V2All:TraceChain','%s: next choices do not match following used choices.',id);
    shared={'Stage','FEbefore','FEafter','UsedObjectiveModel','UsedConstraintModel',...
        'NextObjectiveModel','NextConstraintModel','InfillSupplementCandidates'};
    assert(height(F)==nStages&&isequaln(F{:,shared},Z{:,shared}),...
        'V2All:TraceFlags','%s: stage flags and model choices disagree.',id);
    assert(isequal(F.ObjectiveChoiceChanged,double(used(:,1)~=next(:,1)))&&...
        isequal(F.ConstraintChoiceChanged,double(used(:,2)~=next(:,2))),...
        'V2All:TraceFlagChanges','%s: flagged choice changes disagree.',id);

    % Every problem has M objective responses plus ONE aggregate true CV.
    % This is independent of the problem's number of individual constraints.
    m=2+double(any(strcmp(char(t.Problem),{'CF8','CF9','CF10','LIRCMOP13','LIRCMOP14'})));
    responses=m+1;
    assert(height(P)==nStages*batchSize*responses&&...
        isequal(unique(P.ResponseIndex),(1:responses)'),...
        'V2All:TraceResponses','%s: expected M+1 complete prediction responses.',id);
    ix=[P.Stage,P.ResponseIndex];
    assert(all(isfinite(ix(:)))&&all(ix(:)==floor(ix(:)))&&...
        all(P.Stage>=1&P.Stage<=nStages),...
        'V2All:TracePredictionStages','%s: invalid prediction stage/response indices.',id);
    assert(all(P.EvaluationID==floor(P.EvaluationID))&&...
        all(P.EvaluationID>initialFE+(P.Stage-1)*batchSize&...
            P.EvaluationID<=initialFE+P.Stage*batchSize),...
        'V2All:TracePredictionIDs','%s: prediction IDs outside their true-evaluation batch.',id);
    assert(size(unique([ix,P.EvaluationID],'rows'),1)==height(P),...
        'V2All:TracePredictionDuplicate','%s: repeated stage/response/evaluation triple.',id);
    observed=accumarray(ix,1,[nStages,responses]);
    assert(all(observed(:)==batchSize),'V2All:TraceBatch','%s: expected 10 observations per stage and response.',id);
    eR=P.RBFprediction-P.Truth;eK=P.KrigingPrediction-P.Truth;
    assert(all(isfinite(eR))&&all(isfinite(eK)),...
        'V2All:TracePredictionFinite','%s: nonfinite truth or prediction residual.',id);
    sseR=accumarray(ix,eR.^2,[nStages,responses]);
    sseK=accumarray(ix,eK.^2,[nStages,responses]);
    saeR=accumarray(ix,abs(eR),[nStages,responses]);
    saeK=accumarray(ix,abs(eK),[nStages,responses]);

    key=sprintf('%s|%s|%d',char(t.Version),char(t.Problem),t.D);
    if ~isKey(groupIndex,key)
        g=struct('Version',string(t.Version),'Problem',string(t.Problem),'D',t.D,'M',m,...
            'Trials',0,'Stages',0,'Counts',zeros(1,4),'Changes',zeros(1,2),...
            'UsedSwitches',zeros(1,2),'FinalUnused',zeros(1,2),'RunsWithSwitches',zeros(1,2),...
            'StageCounts',zeros(nStages,4),'StageTrials',zeros(nStages,1),...
            'Observations',zeros(nStages,responses),'SSER',zeros(nStages,responses),...
            'SSEK',zeros(nStages,responses),'SAER',zeros(nStages,responses),'SAEK',zeros(nStages,responses));
        % Give the first element its complete schema before indexed writes.
        % A fieldless struct([]) cannot accept this typed indexed assignment
        % on all supported MATLAB versions.
        if isempty(groups)
            groups=g;
        else
            assert(isequal(fieldnames(groups),fieldnames(g)),...
                'V2All:TraceGroupSchema','Inconsistent trace accumulator fields.');
            groups(end+1)=g; %#ok<AGROW>
        end
        groupIndex(key)=numel(groups);
    end
    gi=groupIndex(key);g=groups(gi);
    assert(g.M==m,'V2All:TraceGroupM','%s: inconsistent objective count within group.',id);
    indicator=double([used(:,1)==1,used(:,1)==2,used(:,2)==1,used(:,2)==2]);
    actualSwitches=sum(diff(used,1,1)~=0,1);lastUnused=double(used(end,:)~=next(end,:));
    changes=sum(used~=next,1);
    assert(isequal(changes,actualSwitches+lastUnused),'V2All:TraceSwitchCount','%s: inconsistent switch decomposition.',id);
    g.Trials=g.Trials+1;g.Stages=g.Stages+nStages;g.Counts=g.Counts+sum(indicator,1);
    g.Changes=g.Changes+changes;g.UsedSwitches=g.UsedSwitches+actualSwitches;
    g.FinalUnused=g.FinalUnused+lastUnused;g.RunsWithSwitches=g.RunsWithSwitches+(actualSwitches>0);
    g.StageCounts=g.StageCounts+indicator;g.StageTrials=g.StageTrials+1;
    g.Observations=g.Observations+observed;
    g.SSER=g.SSER+sseR;g.SSEK=g.SSEK+sseK;g.SAER=g.SAER+saeR;g.SAEK=g.SAEK+saeK;
    groups(gi)=g;
    flagParts{i}=with_task(F,t);
end

% Only the small grouped arrays and at most 40 flag rows per trial survive.
nGroups=numel(groups);selectionParts=cell(nGroups,1);errorParts=cell(nGroups,1);
selectionStageParts=cell(nGroups,1);errorStageParts=cell(nGroups,1);
for i=1:nGroups
    g=groups(i);key=table(g.Version,g.Problem,g.D,'VariableNames',{'Version','Problem','D'});
    c=g.Counts;n=g.Stages;
    assert(n==nStages*g.Trials&&sum(c(1:2))==n&&sum(c(3:4))==n);
    R=[key,table(g.Trials,n,c(1),c(2),c(3),c(4),c(1)/n,c(3)/n,...
        g.Changes(1),g.Changes(2),'VariableNames',{'TrialsWithLogs','Stages','UsedRBFObjective',...
        'UsedKrigingObjective','UsedRBFConstraint','UsedKrigingConstraint','RBFObjectiveProportion',...
        'RBFConstraintProportion','ObjectiveChoiceChanges','ConstraintChoiceChanges'})];
    R.ObjectiveUsedSwitches=g.UsedSwitches(1);R.ConstraintUsedSwitches=g.UsedSwitches(2);
    R.FinalUnusedObjectiveChanges=g.FinalUnused(1);R.FinalUnusedConstraintChanges=g.FinalUnused(2);
    R.RunsWithObjectiveSwitches=g.RunsWithSwitches(1);R.RunsWithConstraintSwitches=g.RunsWithSwitches(2);
    selectionParts{i}=R;
    r=(1:g.M+1)';obs=sum(g.Observations,1)';
    errorParts{i}=[key(ones(numel(r),1),:),table(r,obs,...
        sqrt(sum(g.SSER,1)'./obs),sqrt(sum(g.SSEK,1)'./obs),...
        sum(g.SAER,1)'./obs,sum(g.SAEK,1)'./obs,'VariableNames',...
        {'ResponseIndex','Observations','RBFRMSE','KrigingRMSE','RBFMAE','KrigingMAE'})];
    q=g.StageCounts;trialCounts=g.StageTrials;
    assert(all(trialCounts==g.Trials)&&all(sum(q(:,1:2),2)==trialCounts)&&...
        all(sum(q(:,3:4),2)==trialCounts));
    selectionStageParts{i}=[key(ones(nStages,1),:),table((1:nStages)',trialCounts,...
        q(:,1),q(:,2),q(:,3),q(:,4),q(:,1)./trialCounts,q(:,2)./trialCounts,...
        q(:,3)./trialCounts,q(:,4)./trialCounts,'VariableNames',...
        {'Stage','TrialsWithLogs','UsedRBFObjective','UsedKrigingObjective','UsedRBFConstraint',...
        'UsedKrigingConstraint','RBFObjectiveProportion','KrigingObjectiveProportion',...
        'RBFConstraintProportion','KrigingConstraintProportion'})];
    [stageGrid,responseGrid]=ndgrid((1:nStages)',r);
    obs=g.Observations(:);
    B=[key(ones(numel(obs),1),:),table(stageGrid(:),responseGrid(:),obs,...
        sqrt(g.SSER(:)./obs),sqrt(g.SSEK(:)./obs),g.SAER(:)./obs,g.SAEK(:)./obs,...
        'VariableNames',{'Stage','ResponseIndex','Observations','RBFRMSE','KrigingRMSE','RBFMAE','KrigingMAE'})];
    errorStageParts{i}=sortrows(B,{'Stage','ResponseIndex'});
end
S=vertcat(selectionParts{:});E=vertcat(errorParts{:});Flags=vertcat(flagParts{:});
SelectionByStage=vertcat(selectionStageParts{:});PredictionByStage=vertcat(errorStageParts{:});
end

function require_columns(T,columns,id,kind)
assert(all(ismember(columns,T.Properties.VariableNames)),...
    'V2All:TraceColumns','%s: %s log is missing required columns.',id,kind);
end

function A=with_task(A,t)
n=height(A);A.ID=repmat(string(t.ID),n,1);A.Version=repmat(string(t.Version),n,1);
A.Problem=repmat(string(t.Problem),n,1);A.D=repmat(t.D,n,1);A.Seed=repmat(t.Seed,n,1);
end
