function z=v2d10_metrics(root,F,problem)
v2d10_engine_setup(root);
pf=readmatrix(fullfile(root,'references','PF10000',[problem,'.csv']),'NumHeaderLines',1);
old=readmatrix(fullfile(root,'references','PF2000',[problem,'.csv']),'NumHeaderLines',1);
assert(size(F,2)==size(pf,2)&&all(isfinite(F),'all'));
a=csass_v2.metrics(F,pf,1.1*ones(1,size(pf,2)));
b=csass_v2.metrics(F,old,1.1*ones(1,size(old,2)));
z=struct('M',size(pf,2),'IGD10000',a.IGD,'IGD2000',b.IGD,'NonfiniteIGD',isempty(F),...
 'FeasibleND',size(F,1),'RequestedPF',10000,'ActualPFRows',size(pf,1),'Scale',1);
range=max(pf,[],1)-min(pf,[],1);assert(all(range>0));
U=(F-min(pf,[],1))./range;
for r=[1.1,3,20]
 name=['HVr',strrep(sprintf('%g',r),'.','p')];
 z.(name)=csass_v2.hypervolume(U,r*ones(1,size(pf,2)));
end
end
