function s = metrics(F,PF,reference)
% Raw IGD and exact normalized HV (2 or 3 objectives); minimize all objectives.
% Normalization depends ONLY on reference PF, never on a competing run.
assert(~isempty(PF) && all(isfinite(PF),'all'));
m=size(PF,2); assert(m==2 || m==3);
ideal=min(PF,[],1); nadir=max(PF,[],1); range=nadir-ideal;
assert(all(range>0),'Degenerate reference front.');
if nargin<3 || isempty(reference), reference=1.1*ones(1,m); end
assert(isequal(size(reference),[1,m]) && all(isfinite(reference)));
s=struct('IGD',Inf,'NormalizedIGD',Inf,'HV',0,'FeasibleCount',size(F,1), ...
    'HVExcludedCount',0,'Ideal',ideal,'Nadir',nadir,'HVReference',reference, ...
    'Convention','raw IGD; PF-bound normalized exact HV; strict box reference');
if isempty(F), return; end
assert(size(F,2)==m && all(isfinite(F),'all'));
F=unique(F,'rows');
F=F(~any(csass.dominance(F,zeros(size(F,1),1)),1),:);
s.IGD=igd(F,PF);
A=(F-ideal)./range; B=(PF-ideal)./range;
s.NormalizedIGD=igd(A,B);
valid=all(A<reference,2);
s.HVExcludedCount=sum(~valid);
s.HV=csass.hypervolume(A(valid,:),reference);
end

function value=igd(F,PF)
nearest=zeros(size(PF,1),1);
for start=1:500:size(PF,1)
    ids=start:min(start+499,size(PF,1));
    nearest(ids)=min(csass.distance(PF(ids,:),F),[],2);
end
value=mean(nearest);
end
