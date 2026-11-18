function [fit,raw,dom] = fitness(F,CV)
% Constrained SPEA2 strength/raw fitness and k-neighbor density.
dom = csass_v2.dominance(F,CV);
strength = sum(dom,2);
raw = double(dom)'*strength;
n = size(F,1);
if n<=1, fit=raw; return; end
D = csass_v2.distance(F,F);
D(1:n+1:end)=inf;
D = sort(D,2);
k = min(n-1,max(1,floor(sqrt(n))));
fit = raw + 1./(D(:,k)+2);
end
