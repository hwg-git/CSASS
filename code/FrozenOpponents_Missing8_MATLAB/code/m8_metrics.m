function z=m8_metrics(root,problem,F)
% Metrics on ONE saved, true-evaluated feasible non-dominated final set.
% IGD uses original objective units. HV uses frozen PF10000 min/max bounds,
% without clipping objective values or dividing by reference-box volume.
persistent cacheRoot cache
if isempty(cacheRoot)||~strcmp(cacheRoot,root)
 cacheRoot=root;cache=containers.Map('KeyType','char','ValueType','any');
end
if ~isKey(cache,problem)
 a=readmatrix(fullfile(root,'references','PF10000',[problem '.csv']),'NumHeaderLines',1);
 b=readmatrix(fullfile(root,'references','PF2000',[problem '.csv']),'NumHeaderLines',1);
 assert(~isempty(a)&&~isempty(b)&&all(isfinite(a),'all')&&all(isfinite(b),'all'),'Invalid frozen reference front.');
 assert(size(a,2)==size(b,2)&&ismember(size(a,2),[2 3]));
 lo=min(a,[],1);span=max(a,[],1)-lo;assert(all(span>0),'Reference front must have positive span in every objective.');
 cache(problem)=struct('PF10000',a,'PF2000',b,'Min',lo,'Range',span);
end
c=cache(problem);m=size(c.PF10000,2);
if isempty(F),F=zeros(0,m);end
assert(isnumeric(F)&&ismatrix(F)&&size(F,2)==m&&all(isfinite(F),'all'),'Final objectives must be finite and match reference dimension.');
z=struct('M',m,'IGD10000',igd(F,c.PF10000),'IGD2000',igd(F,c.PF2000), ...
 'HVr1p1',0,'HVr3',0,'HVr20',0,'FeasibleND',size(F,1), ...
 'NonfiniteIGD',isempty(F),'NonfiniteIGD10000',isempty(F),'NonfiniteIGD2000',isempty(F),'ReferenceCount10000',size(c.PF10000,1), ...
 'ReferenceCount2000',size(c.PF2000,1),'RequestedPF10000',10000, ...
 'RequestedPF2000',2000,'ObjectiveScale',1,'HVNormalizationMinimum',c.Min, ...
 'HVNormalizationRange',c.Range,'Ideal',c.Min,'Nadir',c.Min+c.Range,'HVReferenceValues',[1.1 3 20]);
U=(F-c.Min)./c.Range;
z.HVr1p1=hv(U,1.1);z.HVr3=hv(U,3);z.HVr20=hv(U,20);
z.HVExcluded1p1=sum(any(U>=1.1,2));z.HVExcluded3=sum(any(U>=3,2));z.HVExcluded20=sum(any(U>=20,2));
end
function v=igd(F,P)
if isempty(F),v=Inf;return;end
nearest=zeros(size(P,1),1);
for i=1:512:size(P,1)
 ids=i:min(i+511,size(P,1));q=P(ids,:);D=zeros(numel(ids),size(F,1));
 for j=1:size(P,2),D=D+(q(:,j)-F(:,j)').^2;end
 nearest(ids)=sqrt(min(D,[],2));
end
v=mean(nearest);
end
function v=hv(F,r)
F=F(all(F<r,2),:);
if isempty(F),v=0;return;end
if size(F,2)==2,v=hv2(F,r);return;end
F=sortrows(F,1);width=diff([F(:,1);r]);v=0;
for i=1:size(F,1),if width(i)>0,v=v+width(i)*hv2(F(1:i,2:3),r);end,end
assert(isfinite(v)&&v>=0);
end
function v=hv2(F,r)
F=sortrows(F,2);height=diff([F(:,2);r]);v=sum((r-cummin(F(:,1))).*height);
assert(isfinite(v)&&v>=0);
end
