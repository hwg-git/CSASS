function [S,W,policy]=abl2050_ablation_statistics(T,G,cfg)
% Saved-run ablation comparisons only. No old-paper values enter these tests.
% A comparison requires both fixed groups to contain all 30 planned seeds.
% Missing comparisons count as p=1 in a fixed Holm family of four; their
% reported p-values stay NaN. Symbols are withheld until the family is ready.
if nargin<2||isempty(G),G=abl2050_group_statistics(T);end
if nargin<3
 cfg=struct('Problems',unique(string(T.Problem),'stable'),'Dimensions',unique(T.D,'stable'));
end
modes=["adaptive","rbf_only","kriging_only","fixed_rbf_obj_kriging_con","fixed_kriging_obj_rbf_con"];
metrics=["IGD_finite","IGD_failure_rank","HVr1p1","HVr3","HVr20"];
assert(all(ismember(string(T.Mode),modes))&&all(string(T.Version)=="V2"));
S=table();W=table();familyID=0;
for problem=reshape(string(cfg.Problems),1,[])
 for d=reshape(cfg.Dimensions,1,[])
  Q=T(string(T.Problem)==problem&T.D==d,:);
  A=Q(string(Q.Mode)=="adaptive",:);
  for metric=metrics
   familyID=familyID+1;parts=cell(4,1);raw=nan(4,1);ready=false(4,1);
   for c=1:4
    C=Q(string(Q.Mode)==modes(c+1),:);
    [x,aValid,aFailures,aFullMean,aFullStd,aCM,aCS]=values(A,metric);
    [y,cValid,cFailures,cFullMean,cFullStd,cCM,cCS]=values(C,metric);
    batchComplete=complete_group(A)&&complete_group(C);
    available=batchComplete&&~isempty(x)&&~isempty(y);
    p=NaN;advantage=NaN;direction="unavailable";
    if available
     % Map pooled order INCLUDING Inf to finite ordinal ranks. ranksum is
     % invariant to this monotone transform and retains Inf ties as worst.
     [~,~,ordinal]=unique([x;y]);xr=ordinal(1:numel(x));yr=ordinal(numel(x)+1:end);
     if all(ordinal==ordinal(1)),p=1;else,p=ranksum(xr,yr,'tail','both');end
     assert(isfinite(p)&&p>=0&&p<=1);
     lowerBetter=startsWith(metric,"IGD");
     if lowerBetter,wins=x<y';else,wins=x>y';end
     ties=x==y';advantage=mean(double(wins)+0.5*double(ties),'all');
     if advantage>0.5,direction="adaptive_better";
     elseif advantage<0.5,direction="adaptive_worse";
     else,direction="rank_tie";end
    end
    raw(c)=p;ready(c)=available;
    R=table("V2",problem,d,metric,modes(c+1),familyID,height(A),height(C),aValid,cValid,...
      aFailures,cFailures,numel(x),numel(y),batchComplete,available,p,NaN,advantage,direction,...
      aFullMean,aFullStd,cFullMean,cFullStd,aCM,aCS,cCM,cCS,"PENDING",false,...
      'VariableNames',{'Version','Problem','D','Metric','ControlMode','FamilyID','AdaptiveRuns','ControlRuns',...
      'AdaptiveFiniteIGDRuns','ControlFiniteIGDRuns','AdaptiveNoFeasibleRuns','ControlNoFeasibleRuns',...
      'AdaptiveTestN','ControlTestN','BatchesComplete','TestAvailable','RawP','HolmP',...
      'AdaptiveRankAdvantage','Direction','AdaptiveMean30','AdaptiveStd30','ControlMean30','ControlStd30',...
      'AdaptiveConditionalIGDMean','AdaptiveConditionalIGDStd','ControlConditionalIGDMean',...
      'ControlConditionalIGDStd','Symbol','FamilyComplete'});
    R.ConditionalFiniteOnly=metric=="IGD_finite";
    R.TestInputPolicy=input_policy(metric);
    R.Alpha=0.05;R.HolmFamilySize=4;
    parts{c}=R;
   end
   adjusted=holm_four(raw);familyComplete=all(cellfun(@(r)r.BatchesComplete,parts));
   for c=1:4
    R=parts{c};R.HolmP=adjusted(c);R.FamilyComplete=familyComplete;
    if familyComplete && R.TestAvailable
     R.Symbol="=";
     if R.HolmP<=0.05
      if R.Direction=="adaptive_better",R.Symbol="+";
      elseif R.Direction=="adaptive_worse",R.Symbol="-";end
     end
    elseif R.BatchesComplete && ~R.TestAvailable
     R.Symbol="N/T";
    end
    S=[S;R]; %#ok<AGROW>
   end
   % Wide manuscript-style cells retain whole-batch IGD N/A. Conditional
   % means are visible ONLY in the explicitly conditional test/detail table.
   wide=table(problem,d,metric,familyID,familyComplete,...
       'VariableNames',{'Problem','D','Metric','FamilyID','FamilyComplete'});
   fields={'Adaptive','RBFOnly','KrigingOnly','FixedRBFObjKrigingCon','FixedKrigingObjRBFCon'};
   for c=1:5
    z=G(string(G.Problem)==problem&G.D==d&string(G.Mode)==modes(c),:);
    cellText=display_group(z,metric);
    if c>1
     R=parts{c-1};R.HolmP=adjusted(c-1);
     actual=S(end-4+c-1,:);
     cellText=cellText+" ("+actual.Symbol+")";
     wide.([fields{c},'HolmP'])=R.HolmP;
     wide.([fields{c},'TestN'])=R.ControlTestN;
    end
    wide.(fields{c})=cellText;
   end
   wide.AdaptiveTestN=parts{1}.AdaptiveTestN;
   wide.SignConvention="+/-: adaptive better/worse by rank advantage with Holm p<=0.05; =: not significant";
   W=[W;wide]; %#ok<AGROW>
  end
 end
end
policy=struct('Alpha',0.05,'Alternative','two-sided','Test','Wilcoxon rank-sum (MATLAB ranksum)',...
 'Comparison','Adaptive versus each of four fixed controls within the same problem and dimension',...
 'HolmFamily','Four controls, separately for each problem, dimension and metric',...
 'IncompleteFamily','Missing p counted as1 for adjustment; unavailable p remains NaN; symbols withheld until all five groups have30 records',...
 'IGDFinite','Only finite IGD observations, conditional on success; whole-group 30 records required; report retained sample sizes',...
 'IGDFailureRank','All30: no feasible set represented by positive Inf and tied worst; pooled ordinal ranks sent to ranksum',...
 'HV','All30 including zero; reference-specific tests are separate families and exploratory sensitivity analyses',...
 'Symbols','+ adaptive significantly better; - adaptive significantly worse; = not significant; PENDING family incomplete; N/T no finite observations',...
 'Direction','P(adaptive better than control)+0.5P(tie), with lower IGD and higher HV better',...
 'Means','Full30 IGD mean/SD only if30 finite; conditional finite-only mean/SD in separate columns',...
 'OldPaperValuesUsedInTests',false,'PairedSeeds','Seeds aligned by design; rank-sum is the predeclared unpaired test, not a signed-rank test',...
 'MultiplicityScope','Holm protects four controls per metric/problem/dimension, not all problems or all reference points together');
end

function ok=complete_group(Q)
ok=height(Q)==30&&isequal(sort(Q.Seed(:)),(1:30)')&&all(Q.FE==500);
end

function [x,valid,failed,fm,fs,cm,cs]=values(Q,metric)
valid=sum(isfinite(Q.IGD10000));failed=sum(Q.FeasibleND==0);fm=NaN;fs=NaN;cm=NaN;cs=NaN;
finiteIGD=Q.IGD10000(isfinite(Q.IGD10000));
if ~isempty(finiteIGD),cm=mean(finiteIGD);cs=std(finiteIGD,0);end
if startsWith(metric,"IGD")
 if complete_group(Q)&&valid==30,fm=cm;fs=cs;end
 if metric=="IGD_finite",x=finiteIGD;
 else
  assert(all(isfinite(Q.IGD10000)|((Q.FeasibleND==0)&isinf(Q.IGD10000)&Q.IGD10000>0)),...
      'IGD failure-rank input must contain finite values or explicit no-feasible Inf.');
  x=Q.IGD10000;
 end
else
 x=Q.(char(metric));assert(all(isfinite(x)&x>=0),'HV must include finite zeros.');
 if complete_group(Q),fm=mean(x);fs=std(x,0);end
end
x=x(:);
end

function a=holm_four(p)
z=p;z(~isfinite(z))=1;[s,order]=sort(z);a=zeros(4,1);running=0;
for i=1:4,running=max(running,(5-i)*s(i));a(order(i))=min(1,running);end
a(~isfinite(p))=NaN;
end

function t=input_policy(metric)
if metric=="IGD_finite",t="Finite IGD only; conditional comparison with explicit valid n";
elseif metric=="IGD_failure_rank",t="All30 IGD; no-feasible Inf tied worst; rank-only sensitivity";
else,t="All30 HV including zeros";end
end

function t=display_group(G,metric)
if isempty(G)||G.Runs==0,t="PENDING";return;end
assert(height(G)==1);
if G.Runs~=30,t="PENDING";return;end
if startsWith(metric,"IGD"),m=G.IGDMean30;s=G.IGDStd30;
else,m=G.([char(metric),'Mean30']);s=G.([char(metric),'Std30']);end
if isfinite(m),t=string(sprintf('%.4E (%.2E)',m,s));
else,t="N/A";end
% Success/finite counts remain in detailed tables, not publication cells.
end
