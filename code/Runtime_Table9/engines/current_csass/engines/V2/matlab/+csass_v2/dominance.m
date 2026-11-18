function dom = dominance(F,CV)
% dom(i,j): i constraint-dominates j. Minimize all objectives; CV >= 0.
n = size(F,1);
assert(size(CV,1)==n && size(CV,2)==1);
assert(all(isfinite(F),'all') && all(isfinite(CV)) && all(CV>=0));
le = true(n); lt = false(n);
for j=1:size(F,2)
    le = le & (F(:,j)<=F(:,j)');
    lt = lt | (F(:,j)< F(:,j)');
end
dom = (CV<CV') | ((CV==CV') & le & lt);
dom(1:n+1:end)=false;
end
