function v = hypervolume(F,ref)
% Exact union volume of minimization boxes [F(i,:),ref], for 2D/3D.
assert(size(F,2)==numel(ref) && all(isfinite(F),'all') && all(isfinite(ref)));
assert(numel(ref)==2 || numel(ref)==3);
F=unique(F(all(F<ref,2),:),'rows');
if isempty(F), v=0; return; end
F=F(~any(csass.dominance(F,zeros(size(F,1),1)),1),:);
F=sortrows(F,1); v=0;
if numel(ref)==2
    best=ref(2);
    for i=1:size(F,1)
        if F(i,2)<best
            v=v+(ref(1)-F(i,1))*(best-F(i,2));
            best=F(i,2);
        end
    end
else
    cuts=unique([F(:,1);ref(1)]);
    for i=1:numel(cuts)-1
        active=F(F(:,1)<=cuts(i),2:3);
        v=v+(cuts(i+1)-cuts(i))*csass.hypervolume(active,ref(2:3));
    end
end
end
