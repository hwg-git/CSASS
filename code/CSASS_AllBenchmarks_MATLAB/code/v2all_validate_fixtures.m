function report = v2all_validate_fixtures(root,newPlan)
% Pure bookkeeping/statistics tests. No optimizer, model fitting, benchmark
% evaluation, parallel pool, or writes to real run directories are performed.
% The optional newPlan must be the actual frozen 1950-task struct/table.
if nargin<1 || isempty(root)
    root=fileparts(fileparts(mfilename('fullpath')));
end
if nargin<2
    newPlan=v2all_tasks(root);
end
if isstruct(newPlan),newPlan=struct2table(newPlan);end
assert(istable(newPlan),'The frozen plan must be a table.');

% A full, finite group reports all thirty observations and sample SD.
T=fixture("V2","LIRCMOP2",(1:30)',(1:30)'/100);
S=v2all_group_statistics(T);
assert(height(S)==1 && S.Runs(1)==30 && S.FiniteIGDRuns(1)==30);
assert(close(S.IGDMean30(1),15.5) && close(S.IGDStd30(1),std((1:30)')));
assert(close(S.IGDConditionalMean(1),15.5) && S.ZeroHVRuns(1)==0);

% One failure makes the full summary unavailable; finite-only summaries stay
% separate. The failed trial must retain a real HV of zero.
T.IGD10000(30)=Inf;T.HVr1p1(30)=0;T.HVr3(30)=0;T.HVr20(30)=0;
T.FeasibleND(30)=0;
S=v2all_group_statistics(T);
assert(S.Runs(1)==30 && S.FiniteIGDRuns(1)==29);
assert(isnan(S.IGDMean30(1)) && isnan(S.IGDStd30(1)));
assert(close(S.IGDConditionalMean(1),15) && close(S.IGDConditionalStd(1),std((1:29)')));
assert(S.ZeroHVRuns(1)==1);

% No feasible sets: zero HV is not converted to N/A or a discarded trial.
T.IGD10000(:)=Inf;T.HVr1p1(:)=0;T.HVr3(:)=0;T.HVr20(:)=0;T.FeasibleND(:)=0;
S=v2all_group_statistics(T);
assert(S.Runs(1)==30 && S.FiniteIGDRuns(1)==0 && S.ZeroHVRuns(1)==30);
assert(isnan(S.IGDMean30(1)) && isnan(S.IGDStd30(1)) && isnan(S.IGDConditionalMean(1)));
assert(S.HVr1p1Mean30(1)==0 && S.HVr3Mean30(1)==0 && S.HVr20Mean30(1)==0);

% A single finite observation cannot become a complete thirty-run mean.
T.IGD10000(1)=4;T.FeasibleND(1)=1;
S=v2all_group_statistics(T);
assert(S.FiniteIGDRuns(1)==1 && isnan(S.IGDMean30(1)) && isnan(S.IGDStd30(1)));
assert(close(S.IGDConditionalMean(1),4));
singleFiniteConditionalSD=S.IGDConditionalStd(1);
assert(singleFiniteConditionalSD==0);

% A partial group with all currently completed values finite remains partial.
T=fixture("V2","LIRCMOP2",(1:30)',ones(30,1));
S=v2all_group_statistics(T(1:29,:));
assert(S.Runs(1)==29 && S.FiniteIGDRuns(1)==29);
assert(isnan(S.IGDMean30(1)) && isnan(S.IGDStd30(1)));
assert(isnan(S.HVr1p1Mean30(1)) && startsWith(S.IGDDisplay(1),"PENDING"));

% Repeated seeds must fail instead of being counted as independent trials.
duplicateRejected=false;
try
    v2all_group_statistics([T;T(1,:)]);
catch err
    duplicateRejected=contains(err.message,'Duplicate seeds');
end
assert(duplicateRejected,'Duplicate-seed fixture was not rejected.');

% All 72 groups are fixed in advance. Cached whole groups are never dispatched.
B=readtable(fullfile(root,'baseline','completed_runs.csv'),'TextType','string');
assert(height(B)==210 && height(newPlan)==1950);
assert(all(string(B.Version)=="V2") && all(string(newPlan.Version)=="V2"));
assert(all(B.D==10) && all(B.FE==500) && all(B.M==2));
assert(all(newPlan.N==100) && all(newPlan.MaxFE==500));
assert(all(newPlan.Pmax==20) && all(newPlan.K==10));
assert(all(ismember(newPlan.D,[10,20,50])));
assert(sum(B.FinalObjectivesAvailable)==120 && sum(B.FinalDecisionsAvailable)==60);
assert(all(B.Status=="completed"));
kb=taskkeys(B);kn=taskkeys(newPlan);
assert(all(string(B.ID)==kb) && all(string(newPlan.ID)==kn));
assert(numel(unique(kb))==210 && numel(unique(kn))==1950 && isempty(intersect(kb,kn)));
problems=["CF"+string(1:10),"LIRCMOP"+string(1:14)];
cached=["CF2","CF7","LIRCMOP1","LIRCMOP2","LIRCMOP3","LIRCMOP4","LIRCMOP7"];
expected=strings(2160,1);expectedCache=strings(210,1);n=0;c=0;U=table();
for problem=problems
    for d=[10,20,50]
        ids="V2_"+problem+"_D"+string(d)+"_seed"+compose('%02d',(1:30)');
        expected(n+(1:30))=ids;n=n+30;
        if d==10 && ismember(problem,cached)
            expectedCache(c+(1:30))=ids;c=c+30;
        end
        V=fixture("V2",problem,repmat(n/30,30,1),ones(30,1));V.D(:)=d;U=[U;V]; %#ok<AGROW>
    end
end
assert(n==2160 && c==210);
assert(isequal(sort(kb),sort(expectedCache)));
assert(isequal(sort(kn),sort(setdiff(expected,expectedCache))));
assert(isequal(sort([kb;kn]),sort(expected)));
S=v2all_group_statistics(U);
assert(height(S)==72 && all(S.Runs==30) && all(S.FiniteIGDRuns==30));
assert(isequal(sort(S.IGDMean30),(1:72)'));

% Verify actual fixed cache numbers, not the synthetic matrix above.
S=v2all_group_statistics(B);assert(height(S)==7 && all(S.Runs==30) && all(S.FiniteIGDRuns==30));
means=[0.20980846332164643,3.2026200181802547,0.4142279446716474,...
    0.3450380835751601,0.3770657858483033,0.34682316502823574,0.32418380182976014];
sds=[0.1114590439452128,1.8408103198606032,0.0641618024460537,...
    0.03719322165003396,0.055466505092600336,0.03412797783881637,0.21092441926781388];
hvs=[0.5171872433818322,0.0055122176997161,0.20003928864337514,...
    0.460865343135888,0.21680695213523257,0.41728871671984136,0.39551975215258794];
for i=1:7
    a=S(S.Problem==cached(i),:);assert(height(a)==1 && a.D==10);
    assert(close(a.IGDMean30,means(i)) && close(a.IGDStd30,sds(i)) && close(a.HVr1p1Mean30,hvs(i)));
    expectedZeros=0;if cached(i)=="CF7",expectedZeros=29;end
    assert(a.ZeroHVRuns==expectedZeros);
end
report=struct('Status','pass','NewTaskCount',1950,'CachedTaskCount',210,...
    'CombinedMatrixRows',2160,'Groups',72,'TrialsPerGroup',30,...
    'CachedAndNewDisjoint',true,'FiniteAndNAFixturesPassed',true,...
    'PartialGroupFixturePassed',true,'DuplicateSeedsRejected',true,'BaselineStatisticsPassed',true,...
    'FinalObjectivesAvailable',120,'FinalObjectivesMissing',90,...
    'SingleFiniteConditionalSD',singleFiniteConditionalSD,...
    'OptimizationCalls',0,'ModelFits',0,'TrueEvaluations',0,'WritesToRunDirectories',0);
fprintf('V2ALL_VALIDATE_FIXTURES_PASS: 1950 new + 210 cached, no scientific execution.\n');
end

function T=fixture(version,problem,v,h)
n=numel(v);
T=table(repmat(version,n,1),repmat(problem,n,1),10*ones(n,1),(1:n)', ...
    500*ones(n,1),v,h,3*h,20*h,ones(n,1), ...
    'VariableNames',{'Version','Problem','D','Seed','FE','IGD10000', ...
    'HVr1p1','HVr3','HVr20','FeasibleND'});
end

function k=taskkeys(T)
k=string(T.Version)+"_"+string(T.Problem)+"_D"+string(T.D)+"_seed"+compose('%02d',T.Seed);
end

function yes=close(a,b)
yes=isscalar(a) && isscalar(b) && isfinite(a) && isfinite(b) && abs(a-b)<=1e-11*max([1,abs(a),abs(b)]);
end
