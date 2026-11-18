function report = test_csass()
% Numerical and integration checks; no assertions about historical superiority.
root=setup_csass(); rng(123,'twister'); names={};

% Hand-computable Pareto/constraint examples and fitness orientation.
F=[1,4;2,2;4,1;3,3;0,0]; CV=[0;0;0;0;1];
D=csass.dominance(F,CV);
assert(D(2,4) && ~D(4,2) && D(4,5) && ~D(5,4));
rank=csass.fronts(F,CV); assert(isequal(rank,[1;1;1;2;3]));
selected=csass.environment(F,CV,3); assert(isequal(sort(selected),[1;2;3]));
selected=csass.environment([0,4;1,3;2,2;3,1;4,0],zeros(5,1),3);
assert(numel(unique(selected))==3 && all(ismember([1,5],selected)));
names{end+1}='constraint dominance, fronts, SPEA2 filling/truncation';

% Exact HV checked against inclusion-exclusion, rather than its own algorithm.
A=[1,3;2,2]; assert(abs(csass.hypervolume(A,[4,4])-5)<1e-12);
A3=[1,2,2;2,1,2;2,2,1];
assert(abs(csass.hypervolume(A3,[4,4,4])-20)<1e-12);
for m=2:3
    for repeat=1:8
        A=rand(5,m); expected=inclusion_exclusion(A,ones(1,m));
        assert(abs(csass.hypervolume(A,ones(1,m))-expected)<1e-10);
    end
end
assert(csass.hypervolume(zeros(0,2),[1,1])==0);
assert(csass.hypervolume([2,0],[1,1])==0);
PF=[0,1;1,0]; scores=csass.metrics(PF,PF,[]);
assert(scores.IGD==0 && abs(scores.HV-0.21)<1e-12);
empty=csass.metrics(zeros(0,2),PF,[]);
assert(isinf(empty.IGD) && empty.HV==0);
names{end+1}='2D/3D exact HV against independent inclusion-exclusion and IGD';

% Sampling/duplicate/bounds checks.
U=csass.lhs(20,7);
assert(all(U>0 & U<1,'all'));
for j=1:7, assert(isequal(sort(floor(U(:,j)*20)),(0:19)')); end
ids=csass.novel([0,0;0,0;1,1],[1,1],[0,0],[1,1],1e-10);
assert(isequal(ids,1));
names{end+1}='LHS marginal strata and decision deduplication';

% All benchmark interfaces/reference fronts; independently check known PF points.
benchmarks=[cellstr(compose('CF%d',1:10)),cellstr(compose('LIRCMOP%d',1:14))];
for i=1:numel(benchmarks)
    p=csass.problem(benchmarks{i},10);
    X=p.lower+csass.lhs(5,p.D).*(p.upper-p.lower);
    [f,g]=p.evaluate(X); pf=p.reference(200);
    assert(isequal(size(f),[5,p.M]) && size(g,1)==5);
    assert(~isempty(pf) && size(pf,2)==p.M && all(isfinite(pf),'all'));
end
p=csass.problem('CF2',10); a=[0.25;0.75]; X=zeros(2,10); X(:,1)=a;
for j=2:10
    if mod(j,2)==1, X(:,j)=sin(6*pi*a+j*pi/10);
    else, X(:,j)=cos(6*pi*a+j*pi/10); end
end
[f,g]=p.evaluate(X); assert(max(abs(f-[a,1-sqrt(a)]),[],'all')<1e-12);
assert(all(g<=1e-12,'all'));
p=csass.problem('LIRCMOP1',10); a=0.3; X=zeros(1,10); X(1)=a;
X(3:2:end)=sin(pi*a/2)+sqrt(0.505/4);
X(2:2:end)=cos(pi*a/2)-sqrt(0.505/5);
[f,g]=p.evaluate(X);
assert(max(abs(f-[a+0.505,1-a^2+0.505]))<1e-12 && all(g<0,'all'));
names{end+1}='24 benchmark adapters/reference fronts and known CF2/LIRCMOP1 points';

% Pre-update model comparison, negative/undefined R2, and independent task choice.
o=csass.options(struct('Verbose',false)); Y=[(1:5)',(1:5)',(1:5)'];
R=Y; K=Y; R(:,3)=0; K(:,1:2)=0;
[choice,score]=csass.choose_models(Y,R,K,[1,1],o);
assert(isequal(choice,[1,2]) && score.kriging(1)<0);
[choice,~]=csass.choose_models(ones(5,3),zeros(5,3),ones(5,3),[2,1],o);
assert(isequal(choice,[2,1]));
names{end+1}='R2 negative/undefined cases and task-specific selection';

% Train/predict consistency for GP and literal quadratic RBF; no hidden toolboxes.
p=csass.problem('CF2',4); X=p.lower+csass.lhs(12,4).*(p.upper-p.lower);
[f,g]=p.evaluate(X); A=struct('X',X,'F',f,'G',g,'CV',sum(max(0,g),2), ...
    'EvaluationID',(1:12)','Stage',zeros(12,1));
o=csass.options(struct('KrigingMaxFunEvals',25,'KrigingMaxIter',15,'Verbose',false));
models=csass.train_models(A,p,o); [~,K]=csass.predict_models(models,X,p);
assert(max(abs(K-[f,A.CV]),[],'all')<1e-4);
assert(models.rbfRank<=p.D+2);
names{end+1}='Kriging training-point recovery and quadratic-kernel rank diagnosis';

% Budget endpoint is deliberately not divisible by K; preserve original RNG.
o=struct('N',12,'MaxFE',29,'K',5,'Pmax',2,'Seed',44, ...
    'KrigingMaxFunEvals',25,'KrigingMaxIter',15,'Verbose',false,'ReferencePoints',200);
before=rng; r1=csass_run(csass.problem('CF2',4),o); after=rng;
assert(isequal(before,after));
r2=csass_run(csass.problem('CF2',4),o);
assert(isequaln(r1.history,r2.history));
assert(r1.FE==29 && numel(r1.stages)==4);
assert(isequal([r1.stages.FEafter],[17,22,27,29]));
assert(isequal(r1.archive.EvaluationID,unique(r1.archive.EvaluationID,'stable')));
assert(size(r1.archive.X,1)<=12);
for s=r1.stages
    assert(max(s.trainingEvaluationIDs)<=s.FEbefore);
    assert(min(s.newEvaluationIDs)>s.FEbefore);
    assert(isempty(intersect(s.trainingEvaluationIDs,s.newEvaluationIDs)));
    checkProblem=csass.problem('CF2',4);
    [f,g]=checkProblem.evaluate(s.X); %#ok<NASGU>
    assert(max(abs(s.truth(:,1:2)-f),[],'all')<1e-12);
end
checkProblem=csass.problem('CF2',4);
[f,g]=checkProblem.evaluate(r1.history.X);
assert(isequal(f,r1.history.F) && isequal(g,r1.history.G));
assert(all(ismember(r1.finalF,r1.history.F,'rows')));
assert(all(r1.finalPopulation.EvaluationID<=r1.FE));
names{end+1}='exact non-divisible FE budget, truth ledger, no validation leakage, determinism';

% Every ablation pins the intended choices from the initial stage onwards.
modes={'rbf_only','kriging_only','fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'};
expected=[1,1;2,2;1,2;2,1];
for i=1:4
    t=o; t.Mode=modes{i}; t.MaxFE=17;
    r=csass_run(csass.problem('CF2',4),t);
    assert(isequal(r.initialX,r1.initialX));
    assert(isequal(r.stages(1).usedChoice,expected(i,:)));
    assert(isequal(r.stages(1).nextChoice,expected(i,:)));
end
names{end+1}='four fixed controls share initial designs and pin correct task models';

% Verify output persistence, including round-trip run truth and logs.
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
out=fullfile(root,'..','results',['test_export_',stamp]);
csass.save_result(r1,out); loaded=load(fullfile(out,'run.mat'));
assert(isequaln(loaded.result.history,r1.history));
ledger=readtable(fullfile(out,'true_evaluations.csv'));
assert(height(ledger)==29 && isequal(ledger.EvaluationID,(1:29)'));
predictions=readtable(fullfile(out,'prediction_errors.csv'));
assert(height(predictions)==(29-12)*3);
assert(numel(unique(predictions.EvaluationID))==17);
names{end+1}='MAT/CSV output round trip and complete per-response prediction logs';

report=struct('passed',true,'checks',{names},'checkGroups',numel(names), ...
    'MATLAB',version,'status','implementation verification, not historical numerical replication');
reportDir=fullfile(root,'..','verification'); if ~isfolder(reportDir), mkdir(reportDir); end
fid=fopen(fullfile(reportDir,'test_report.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true)); fclose(fid);
fprintf('PASS: %d verification groups.\n',numel(names));
end

function v=inclusion_exclusion(A,ref)
v=0; n=size(A,1);
for bits=1:(2^n-1)
    ids=logical(bitget(bits,1:n)); lower=max(A(ids,:),[],1);
    v=v+(-1)^(sum(ids)+1)*prod(max(0,ref-lower));
end
end
