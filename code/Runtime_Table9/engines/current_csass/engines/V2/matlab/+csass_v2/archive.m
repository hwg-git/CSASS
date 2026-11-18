function A = archive(H,N,lower,upper,tol)
% Thesis Algorithm 3-4: complete fronts then extreme-distance cutoff front.
% Ambiguous aggregation resolved as minimum distance to any extreme point.
u=csass_v2.novel(H.X,zeros(0,size(H.X,2)),lower,upper,tol);
A=csass_v2.subset(H,u);
if size(A.X,1)<=N, return; end
r=csass_v2.fronts(A.F,A.CV); keep=zeros(0,1);
for level=1:max(r)
    ids=find(r==level);
    if numel(keep)+numel(ids)<=N
        keep=[keep;ids]; %#ok<AGROW>
    else
        [~,extreme]=min(A.F,[],1);
        D=csass_v2.distance(A.F(ids,:),A.F(extreme,:));
        score=min(D,[],2);
        [~,order]=sortrows([-score,ids],[1,2]);
        keep=[keep;ids(order(1:N-numel(keep)))]; %#ok<AGROW>
        break;
    end
end
A=csass_v2.subset(A,keep);
end
