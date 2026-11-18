function ids = environment(F,CV,N)
% Thesis Algorithm 4-3: feasible ND, SPEA2 truncation or fitness filling.
n=size(F,1); N=min(N,n);
if N==0, ids=zeros(0,1); return; end
[fit,raw]=csass_v2.fitness(F,CV);
ids=find(CV==0 & raw==0);
if numel(ids)>N
    while numel(ids)>N
        D=csass_v2.distance(F(ids,:),F(ids,:));
        D(1:size(D,1)+1:end)=inf;
        D=sort(D,2);
        [~,order]=sortrows(D);
        ids(order(1))=[];
    end
elseif numel(ids)<N
    rest=setdiff((1:n)',ids,'stable');
    [~,order]=sortrows([fit(rest),rest],[1,2]);
    ids=[ids;rest(order(1:N-numel(ids)))];
end
end
