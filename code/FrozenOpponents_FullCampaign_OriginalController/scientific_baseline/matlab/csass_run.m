function result = csass_run(problem,userOptions)
% Reconstructed CSASS from thesis Algorithms 4-1..4-4 and archive Algorithm 3-4.
% Historical author code is unavailable. See RECONSTRUCTION_NOTES.md.
if nargin<2, userOptions=struct(); end
o=csass.options(userOptions); p=problem;
assert(p.M>=2 && p.D==numel(p.lower) && all(p.upper>p.lower));
previousRNG=rng; cleanup=onCleanup(@()rng(previousRNG)); %#ok<NASGU>
rng(o.Seed,'twister'); initialRNG=rng;
started=tic;
X=p.lower+csass.lhs(o.N,p.D).*(p.upper-p.lower);
H=true_evaluate(X,p,o,0,0);
P=struct('X',H.X,'F',H.F,'CV',H.CV); A=H;
FE=o.N; stage=0; choice=mode_choice(o.Mode,[1,1]);
logs=struct([]);
if o.Verbose, fprintf('%s D=%d %s seed=%d FE=%d/%d\n',p.name,p.D,o.Mode,o.Seed,FE,o.MaxFE); end
while FE<o.MaxFE
    stage=stage+1; usedChoice=choice;
    fitStart=tic; models=csass.train_models(A,p,o); fitSeconds=toc(fitStart);
    P=csass.predict(models,P.X,p,usedChoice,H,o);
    innerPareto=zeros(o.Pmax,6);
    for inner=1:o.Pmax
        offX=csass.offspring(P,p,o);
        Off=csass.predict(models,offX,p,usedChoice,H,o);
        Q=struct('X',[P.X;Off.X],'F',[P.F;Off.F],'CV',[P.CV;Off.CV]);
        [ids,innerPareto(inner,:)]=csass.inner_pareto(Q,p,o); P=csass.subset(Q,ids);
    end
    batchSize=min(o.K,o.MaxFE-FE);
    [newX,fallbackCount,infillLog]=csass.infill_lhs(P,models,usedChoice,H,p,o,batchSize);
    % PREDICT BEFORE true evaluation and BEFORE updating either training set.
    [predRBF,predKriging]=csass.predict_models(models,newX,p);
    New=true_evaluate(newX,p,o,stage,FE);
    assert(isempty(intersect(models.trainingEvaluationIDs,New.EvaluationID)));
    Y=[New.F,New.CV];
    [proposed,score]=csass.choose_models(Y,predRBF,predKriging,usedChoice,o);
    choice=mode_choice(o.Mode,proposed);
    record=struct('stage',stage,'FEbefore',FE,'FEafter',FE+batchSize, ...
        'usedChoice',usedChoice,'proposedChoice',proposed,'nextChoice',choice, ...
        'trainingEvaluationIDs',models.trainingEvaluationIDs, ...
        'newEvaluationIDs',New.EvaluationID,'X',newX,'truth',Y, ...
        'predictedRBF',predRBF,'predictedKriging',predKriging, ...
        'scores',score,'rbfRank',models.rbfRank, ...
        'rbfTrainingCount',size(A.X,1),'fitSeconds',fitSeconds, ...
        'infillSupplementCount',fallbackCount, ...
        'infillLog',infillLog, ...
        'innerPareto',innerPareto, ...
        'krigingExitFlags',cellfun(@(k)k.exitflag,models.Kriging), ...
        'krigingNuggets',cellfun(@(k)k.nugget,models.Kriging));
    if stage==1, logs=record;
    else, logs(stage)=record; end %#ok<AGROW>
    H=append(H,New); FE=FE+batchSize;
    A=csass.archive(append(A,New),o.N,p.lower,p.upper,o.DuplicateTolerance);
    if o.Verbose && (mod(stage,10)==0 || FE==o.MaxFE)
        fprintf(' stage %d FE %d/%d next [%d %d] feasible observed %d\n', ...
            stage,FE,o.MaxFE,choice(1),choice(2),sum(H.CV==0));
    end
end
% A surrogate population cannot be used as a true-evaluated output set.
% Construct the final population from the complete true-evaluation ledger.
ids=csass.environment(H.F,H.CV,o.N); finalPopulation=csass.subset(H,ids);
F=finalPopulation.F(finalPopulation.CV==0,:);
X=finalPopulation.X(finalPopulation.CV==0,:);
if ~isempty(F)
    nd=~any(csass.dominance(F,zeros(size(F,1),1)),1);
    F=F(nd,:); X=X(nd,:);
end
runSeconds=toc(started);
reference=p.reference(o.ReferencePoints);
metric=csass.metrics(F,reference,o.HVReference);
result=struct('status','reconstructed_new_run_not_historical_replication', ...
    'problem',rmfield(p,{'evaluate','reference'}),'options',o, ...
    'initialRNG',initialRNG,'initialX',H.X(1:o.N,:), ...
    'history',H,'archive',A,'stages',logs,'finalPopulation',finalPopulation, ...
    'finalX',X,'finalF',F,'surrogatePopulation',P,'FE',FE, ...
    'runtimeSeconds',runSeconds,'metrics',metric,'referenceFront',reference, ...
    'selectionKey',struct('RBF',1,'Kriging',2), ...
    'outputRule','SPEA2 select N from all true evaluations, then feasible ND');
result.provenance=csass.provenance();
assert(FE==o.MaxFE && size(H.X,1)==FE);
assert(all(isfinite(H.F),'all') && all(isfinite(H.G),'all'));
assert(numel(csass.novel(H.X,zeros(0,p.D),p.lower,p.upper,o.DuplicateTolerance))==FE);
if ~isempty(o.OutputDirectory), csass.save_result(result,o.OutputDirectory); end
end

function New=true_evaluate(X,p,o,stage,offset)
[F,G]=p.evaluate(X);
assert(isequal(size(F),[size(X,1),p.M]));
assert(size(G,1)==size(X,1) && all(isfinite(F),'all') && all(isfinite(G),'all'));
CV=sum(max(0,G),2); CV(CV<=o.FeasibilityTolerance)=0;
New=struct('X',X,'F',F,'G',G,'CV',CV, ...
    'Stage',repmat(stage,size(X,1),1), ...
    'EvaluationID',(offset+(1:size(X,1)))');
end

function H=append(H,New)
for f={'X','F','G','CV','Stage','EvaluationID'}
    H.(f{1})=[H.(f{1});New.(f{1})];
end
end

function choice=mode_choice(mode,proposed)
switch mode
    case 'adaptive', choice=proposed;
    case 'rbf_only', choice=[1,1];
    case 'kriging_only', choice=[2,2];
    case 'fixed_rbf_obj_kriging_con', choice=[1,2];
    case 'fixed_kriging_obj_rbf_con', choice=[2,1];
end
end

function [X,nSupplement]=infill(P,models,choice,H,p,o,K)
novel=csass.novel(P.X,H.X,p.lower,p.upper,o.DuplicateTolerance);
C=csass.subset(P,novel); nSupplement=0;
% Supplement only when current population contains fewer than K novel points.
% These generated candidates are SURROGATE evaluated and all are logged.
for attempt=1:5
    if size(C.X,1)>=K, break; end
    X=csass.offspring(P,p,o);
    ids=csass.novel(X,[H.X;C.X],p.lower,p.upper,o.DuplicateTolerance);
    extra=csass.predict(models,X(ids,:),p,choice,H,o);
    C.X=[C.X;extra.X]; C.F=[C.F;extra.F]; C.CV=[C.CV;extra.CV];
    nSupplement=nSupplement+size(extra.X,1);
end
if size(C.X,1)<K
    X=p.lower+csass.lhs(max(o.N,K),p.D).*(p.upper-p.lower);
    ids=csass.novel(X,[H.X;C.X],p.lower,p.upper,o.DuplicateTolerance);
    extra=csass.predict(models,X(ids,:),p,choice,H,o);
    C.X=[C.X;extra.X]; C.F=[C.F;extra.F]; C.CV=[C.CV;extra.CV];
    nSupplement=nSupplement+size(extra.X,1);
end
assert(size(C.X,1)>=K,'Cannot select a full novel batch.');
rank=csass.fronts(C.F,C.CV); fit=csass.fitness(C.F,C.CV);
[~,ids]=sortrows([rank,fit,(1:numel(rank))'],[1,2,3]);
X=C.X(ids(1:K),:);
end
