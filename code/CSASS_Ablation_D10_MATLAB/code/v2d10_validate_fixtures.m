function report=v2d10_validate_fixtures(root,newPlan)
% Pure table/manifest QA. No model fitting, optimization or problem calls.
if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
if nargin<2,newPlan=v2d10_tasks(root);end
if isstruct(newPlan),newPlan=struct2table(newPlan);end
T=fixture("CF2","adaptive",(1:30)',(1:30)'/100);
S=v2d10_group_statistics(T);
assert(height(S)==1&&S.Runs==30&&S.FiniteIGDRuns==30);
assert(close(S.IGDMean30,15.5)&&close(S.IGDStd30,std((1:30)')));
T.IGD10000(30)=Inf;T.FeasibleND(30)=0;T{30,{'HVr1p1','HVr3','HVr20'}}=[0,0,0];
S=v2d10_group_statistics(T);
assert(S.FiniteIGDRuns==29&&isnan(S.IGDMean30)&&isnan(S.IGDStd30)&&S.ZeroHVRuns==1);
assert(close(S.IGDConditionalMean,15)&&close(S.IGDConditionalStd,std((1:29)')));
T.IGD10000(:)=Inf;T.FeasibleND(:)=0;T{:,{'HVr1p1','HVr3','HVr20'}}=zeros(30,3);
S=v2d10_group_statistics(T);
assert(S.FiniteIGDRuns==0&&S.ZeroHVRuns==30&&isnan(S.IGDConditionalMean)&&S.HVr1p1Mean30==0);
T.IGD10000(1)=4;T.FeasibleND(1)=1;S=v2d10_group_statistics(T);
assert(S.FiniteIGDRuns==1&&isnan(S.IGDMean30)&&S.IGDConditionalMean==4&&S.IGDConditionalStd==0);
T=fixture("CF2","adaptive",(1:30)',ones(30,1));
S=v2d10_group_statistics(T(1:29,:));
assert(S.Runs==29&&isnan(S.IGDMean30)&&isnan(S.HVr1p1Mean30)&&startsWith(S.IGDDisplay,"PENDING"));
rejected=false;try,v2d10_group_statistics([T;T(1,:)]);catch e,rejected=contains(e.message,'Duplicate seeds');end
assert(rejected);
% The SAME seeds in different modes are distinct groups, never duplicates.
U=T;U.Mode(:)="rbf_only";U.IGD10000(:)=99;
S=v2d10_group_statistics([T;U]);assert(height(S)==2&&all(S.Runs==30));
assert(S.IGDMean30(S.Mode=="adaptive")==15.5&&S.IGDMean30(S.Mode=="rbf_only")==99);
B=readtable(fullfile(root,'baseline','completed_runs.csv'),'TextType','string');
assert(height(B)==360&&height(newPlan)==540&&all(B.Version=="V2")&&all(newPlan.Version=="V2"));
assert(all(B.D==10)&&all(newPlan.D==10)&&all(B.FE==500)&&all(B.Status=="completed"));
assert(all(newPlan.N==100)&all(newPlan.MaxFE==500)&all(newPlan.Pmax==20)&all(newPlan.K==10));
kb=keys(B);kn=keys(newPlan);
assert(isequal(string(B.ID),kb)&&isequal(string(newPlan.ID),kn));
assert(numel(unique(kb))==360&&numel(unique(kn))==540&&isempty(intersect(kb,kn)));
problems=["CF2","CF7","LIRCMOP1","LIRCMOP7","CF8","LIRCMOP13"];
modes=["adaptive","rbf_only","kriging_only","fixed_rbf_obj_kriging_con","fixed_kriging_obj_rbf_con"];
expected=strings(900,1);cache=strings(360,1);n=0;c=0;U=table();
for problem=problems
 for d=10
  for mode=modes
   ids="V2_"+problem+"_D"+string(d)+"_"+mode+"_seed"+compose('%02d',(1:30)');
   expected(n+(1:30))=ids;n=n+30;
   cached=d==10&&(ismember(problem,["CF7","LIRCMOP7"])||...
       (ismember(problem,["CF2","LIRCMOP1"])&&mode=="adaptive"));
   if cached,cache(c+(1:30))=ids;c=c+30;end
   q=fixture(problem,mode,repmat(n/30,30,1),ones(30,1));q.D(:)=d;U=[U;q]; %#ok<AGROW>
  end
 end
end
assert(n==900&&c==360&&isequal(sort(kb),sort(cache)));
assert(isequal(sort(kn),sort(setdiff(expected,cache)))&&isequal(sort([kb;kn]),sort(expected)));
S=v2d10_group_statistics(U);
assert(height(S)==30&&all(S.Runs==30)&&isequal(sort(S.IGDMean30),(1:30)'));
G=v2d10_group_statistics(B);assert(height(G)==12&&all(G.Runs==30));
expectedProblem=["CF2","CF7","LIRCMOP1","LIRCMOP7"];
means=[.20980846332164643,3.2026200181802547,.4142279446716474,.32418380182976014];
sd=[.1114590439452128,1.8408103198606032,.0641618024460537,.21092441926781388];
for i=1:4
 a=G(G.Problem==expectedProblem(i)&G.Mode=="adaptive",:);
 assert(height(a)==1&&a.FiniteIGDRuns==30&&close(a.IGDMean30,means(i))&&close(a.IGDStd30,sd(i)));
end
report=struct('Status','pass','NewTaskCount',540,'CachedTaskCount',360,'CombinedMatrixRows',900,...
 'Groups',30,'Modes',5,'TrialsPerGroup',30,'CachedAndNewDisjoint',true,'ModeIsolationPassed',true,...
 'FiniteAndNAFixturesPassed',true,'DuplicateSeedsRejected',true,'BaselineStatisticsPassed',true,...
 'OptimizationCalls',0,'ModelFits',0,'TrueEvaluations',0);
fprintf('V2D10_VALIDATE_FIXTURES_PASS: 540 planned +360 cached,30 D10 mode-separated groups; no science executed.\n');
end

function T=fixture(problem,mode,v,h)
n=numel(v);T=table(repmat("V2",n,1),repmat(problem,n,1),10*ones(n,1),repmat(mode,n,1),...
 (1:n)',500*ones(n,1),v,h,3*h,20*h,ones(n,1),'VariableNames',...
 {'Version','Problem','D','Mode','Seed','FE','IGD10000','HVr1p1','HVr3','HVr20','FeasibleND'});
end
function k=keys(T)
k=string(T.Version)+"_"+string(T.Problem)+"_D"+string(T.D)+"_"+string(T.Mode)+"_seed"+compose('%02d',T.Seed);
end
function y=close(a,b),y=isfinite(a)&&isfinite(b)&&abs(a-b)<=1e-11*max([1,abs(a),abs(b)]);end
