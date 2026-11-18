function A = archive(H,N,lower,upper,tol)
% Diagnostic variant: reserve up to K=10 near-boundary infeasible observations.
% Not a recovered historical setting. Only archive retention changes.
u=csass.novel(H.X,zeros(0,size(H.X,2)),lower,upper,tol);
A=csass.subset(H,u);
if size(A.X,1)<=N,return;end
infeasible=find(A.CV>0);
if ~isempty(infeasible) && any(A.CV==0) && N>1
 [~,order]=sortrows([A.CV(infeasible),A.EvaluationID(infeasible)],[1,2]);
 count=min([10,numel(infeasible),N-1]);reserved=infeasible(order(1:count));
 rest=setdiff((1:size(A.X,1))',reserved,'stable');
 ids=original_select(csass.subset(A,rest),N-count);
 keep=[rest(ids);reserved];
else
 keep=original_select(A,N);
end
A=csass.subset(A,keep);
end

function keep=original_select(A,N)
if size(A.X,1)<=N,keep=(1:size(A.X,1))';return;end
r=csass.fronts(A.F,zeros(size(A.CV)));keep=zeros(0,1);
for level=1:max(r)
 ids=find(r==level);
 if numel(keep)+numel(ids)<=N
  keep=[keep;ids]; %#ok<AGROW>
 else
  [~,extreme]=min(A.F,[],1);
  D=csass.distance(A.F(ids,:),A.F(extreme,:));score=min(D,[],2);
  [~,order]=sortrows([-score,ids],[1,2]);
  keep=[keep;ids(order(1:N-numel(keep)))]; %#ok<AGROW>
  break;
 end
end
end
