function report=v2d10_statistics_fixture()
% Synthetic rank/NA/Holm/mode tests only. No scientific computation.
modes=["adaptive","rbf_only","kriging_only","fixed_rbf_obj_kriging_con","fixed_kriging_obj_rbf_con"];
cfg=struct('Problems',{{'CF2'}},'Dimensions',10);T=table();
% Adaptive IGD2/HV2: wins against IGD3/HV1, loses to IGD1/HV3,
% ties exact copies; the fourth control has30 no-feasible Inf/zero.
igd={2*ones(30,1),3*ones(30,1),ones(30,1),2*ones(30,1),inf(30,1)};
hv={2*ones(30,1),ones(30,1),3*ones(30,1),2*ones(30,1),zeros(30,1)};
for i=1:5,T=[T;make(modes(i),igd{i},hv{i})];end %#ok<AGROW>
[S,W]=v2d10_ablation_statistics(T,[],cfg);
assert(height(S)==20&&height(W)==5&&all(S.BatchesComplete)&&all(S.FamilyComplete));
assert(sum(S.TestAvailable)==19&&all(S.HolmFamilySize==4));
for metric=["IGD_failure_rank","HVr1p1","HVr3","HVr20"]
 q=S(S.Metric==metric,:);
 assert(isequal(q.Symbol,["+";"-";"=";"+"]));
 assert(all(q.AdaptiveTestN==30)&all(q.ControlTestN==30));
 assert(q.RawP(3)==1&&q.HolmP(3)==1&&q.AdaptiveRankAdvantage(3)==0.5);
 assert(q.AdaptiveRankAdvantage(1)==1&&q.AdaptiveRankAdvantage(2)==0);
end
f=S(S.Metric=="IGD_finite",:);
assert(isequal(f.Symbol,["+";"-";"=";"N/T"]));
assert(f.ControlFiniteIGDRuns(4)==0&&f.ControlTestN(4)==0&&isnan(f.RawP(4))&&isnan(f.HolmP(4)));
assert(isnan(f.ControlMean30(4))&&isnan(f.ControlConditionalIGDMean(4)));
% Independently check fixed-four Holm (including an unavailable p as1).
for metric=unique(S.Metric,'stable')'
 q=S(S.Metric==metric,:);p=q.RawP;p(~isfinite(p))=1;
 [a,ix]=sort(p);adjust=zeros(4,1);running=0;
 for j=1:4,running=max(running,(5-j)*a(j));adjust(ix(j))=min(1,running);end
 k=q.TestAvailable;assert(all(abs(q.HolmP(k)-adjust(k))<1e-14));
end
% Remove one control record: it cannot be silently tested as a29-run batch.
U=T;U(end,:)=[];[Q,~]=v2d10_ablation_statistics(U,[],cfg);
assert(~any(Q.FamilyComplete));
assert(all(Q.Symbol=="PENDING")&&~any(Q.TestAvailable(Q.ControlMode==modes(5))));
assert(all(isnan(Q.RawP(Q.ControlMode==modes(5)))));
% Identical data yields p1 even with all Inf in failure-rank sensitivity.
Z=T;Z.IGD10000(:)=Inf;Z.FeasibleND(:)=0;Z{:,{'HVr1p1','HVr3','HVr20'}}=zeros(height(Z),3);
R=v2d10_ablation_statistics(Z,[],cfg);
q=R(R.Metric=="IGD_failure_rank",:);assert(all(q.RawP==1&q.HolmP==1&q.Symbol=="="));
q=R(R.Metric=="IGD_finite",:);assert(~any(q.TestAvailable)&&all(q.Symbol=="N/T"));
% A single successful run is conditional n1, never full30 mean.
Z.IGD10000(1)=7;Z.FeasibleND(1)=1;
R=v2d10_ablation_statistics(Z,[],cfg);q=R(R.Metric=="IGD_failure_rank",:);
assert(all(q.AdaptiveFiniteIGDRuns==1&q.AdaptiveTestN==30&isnan(q.AdaptiveMean30)));
assert(all(q.AdaptiveConditionalIGDMean==7&q.AdaptiveConditionalIGDStd==0));
report=struct('Status','pass','SyntheticOnly',true,'FullThirtyRequired',true,'HolmFourPassed',true,...
 'FiniteConditionalAndInfWorstSeparated',true,'PositiveNegativeTiePassed',true,'ModeIsolationPassed',true,...
 'OptimizationRuns',0,'ModelFits',0,'TrueEvaluations',0);
fprintf('V2ABL_STATISTICS_FIXTURE_PASS: synthetic rank-sum, Holm4, Inf, N/A and mode separation.\n');
end
function T=make(mode,igd,hv)
n=numel(igd);T=table(repmat("V2",n,1),repmat("CF2",n,1),10*ones(n,1),repmat(mode,n,1),...
 (1:n)',500*ones(n,1),igd,hv,3*hv,20*hv,double(isfinite(igd)),...
 'VariableNames',{'Version','Problem','D','Mode','Seed','FE','IGD10000','HVr1p1','HVr3','HVr20','FeasibleND'});
end
