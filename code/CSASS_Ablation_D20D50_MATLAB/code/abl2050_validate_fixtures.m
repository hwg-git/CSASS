function report=abl2050_validate_fixtures(root,newPlan)
% Pure table/manifest QA. No model fitting, optimization or problem calls.
if nargin<1||isempty(root),root=fileparts(fileparts(mfilename('fullpath')));end
if nargin<2,newPlan=abl2050_tasks(root);end
if isstruct(newPlan),newPlan=struct2table(newPlan);end
T=fixture("CF2","adaptive",(1:30)',(1:30)'/100);
S=abl2050_group_statistics(T);
assert(height(S)==1&&S.Runs==30&&S.FiniteIGDRuns==30);
assert(close(S.IGDMean30,15.5)&&close(S.IGDStd30,std((1:30)')));
T.IGD10000(30)=Inf;T.FeasibleND(30)=0;T{30,{'HVr1p1','HVr3','HVr20'}}=[0,0,0];
S=abl2050_group_statistics(T);
assert(S.FiniteIGDRuns==29&&isnan(S.IGDMean30)&&isnan(S.IGDStd30)&&S.ZeroHVRuns==1);
assert(close(S.IGDConditionalMean,15)&&close(S.IGDConditionalStd,std((1:29)')));
T.IGD10000(:)=Inf;T.FeasibleND(:)=0;T{:,{'HVr1p1','HVr3','HVr20'}}=zeros(30,3);
S=abl2050_group_statistics(T);
assert(S.FiniteIGDRuns==0&&S.ZeroHVRuns==30&&isnan(S.IGDConditionalMean)&&S.HVr1p1Mean30==0);
T.IGD10000(1)=4;T.FeasibleND(1)=1;S=abl2050_group_statistics(T);
assert(S.FiniteIGDRuns==1&&isnan(S.IGDMean30)&&S.IGDConditionalMean==4&&S.IGDConditionalStd==0);
T=fixture("CF2","adaptive",(1:30)',ones(30,1));
S=abl2050_group_statistics(T(1:29,:));
assert(S.Runs==29&&isnan(S.IGDMean30)&&isnan(S.HVr1p1Mean30)&&startsWith(S.IGDDisplay,"PENDING"));
rejected=false;try,abl2050_group_statistics([T;T(1,:)]);catch e,rejected=contains(e.message,'Duplicate seeds');end
assert(rejected);
% The SAME seeds in different modes are distinct groups, never duplicates.
U=T;U.Mode(:)="rbf_only";U.IGD10000(:)=99;
S=abl2050_group_statistics([T;U]);assert(height(S)==2&&all(S.Runs==30));
assert(S.IGDMean30(S.Mode=="adaptive")==15.5&&S.IGDMean30(S.Mode=="rbf_only")==99);
assert(height(newPlan)==1800&&all(newPlan.Version=="V2"));
assert(all(ismember(newPlan.D,[20,50]))&&all(newPlan.N==100)&all(newPlan.MaxFE==500)&all(newPlan.Pmax==20)&all(newPlan.K==10));
kn=keys(newPlan);assert(isequal(string(newPlan.ID),kn)&&numel(unique(kn))==1800);
problems=["CF2","CF7","LIRCMOP1","LIRCMOP7","CF8","LIRCMOP13"];
modes=["adaptive","rbf_only","kriging_only","fixed_rbf_obj_kriging_con","fixed_kriging_obj_rbf_con"];
expected=strings(1800,1);n=0;U=table();
for problem=problems
 for d=[20,50]
  for mode=modes
   ids="V2_"+problem+"_D"+string(d)+"_"+mode+"_seed"+compose('%02d',(1:30)');
   expected(n+(1:30))=ids;n=n+30;
   q=fixture(problem,mode,repmat(n/30,30,1),ones(30,1));q.D(:)=d;U=[U;q]; %#ok<AGROW>
  end
 end
end
assert(n==1800&&isequal(sort(kn),sort(expected)));
assert(sum(newPlan.D==20)==900&&sum(newPlan.D==50)==900);
S=abl2050_group_statistics(U);
assert(height(S)==60&&all(S.Runs==30)&&isequal(sort(S.IGDMean30),(1:60)'));
B=abl2050_empty_runs();assert(height(B)==0&&isstring(B.ID)&&isnumeric(B.IGD10000)&&islogical(B.FinalObjectivesAvailable));
G=abl2050_group_statistics(B);assert(height(G)==0&&width(G)==19&&isstring(G.IGDDisplay));
assert(~isfile(fullfile(root,'baseline','completed_runs.csv')),'D10 cached trials must not be packaged as D20/50 results.');
report=struct('Status','pass','NewTaskCount',1800,'CachedTaskCount',0,'CombinedMatrixRows',1800,...
 'Groups',60,'Modes',5,'TrialsPerGroup',30,'NoCache',true,'ModeIsolationPassed',true,...
 'FiniteAndNAFixturesPassed',true,'DuplicateSeedsRejected',true,'EmptyRunSchemaPassed',true,...
 'OptimizationCalls',0,'ModelFits',0,'TrueEvaluations',0);
fprintf('ABL2050_VALIDATE_FIXTURES_PASS: 1800 planned,0 cached,60 D20/50 mode-separated groups; no science executed.\n');
end

function T=fixture(problem,mode,v,h)
n=numel(v);T=table(repmat("V2",n,1),repmat(problem,n,1),20*ones(n,1),repmat(mode,n,1),...
 (1:n)',500*ones(n,1),v,h,3*h,20*h,ones(n,1),'VariableNames',...
 {'Version','Problem','D','Mode','Seed','FE','IGD10000','HVr1p1','HVr3','HVr20','FeasibleND'});
end
function k=keys(T)
k=string(T.Version)+"_"+string(T.Problem)+"_D"+string(T.D)+"_"+string(T.Mode)+"_seed"+compose('%02d',T.Seed);
end
function y=close(a,b),y=isfinite(a)&&isfinite(b)&&abs(a-b)<=1e-11*max([1,abs(a),abs(b)]);end
