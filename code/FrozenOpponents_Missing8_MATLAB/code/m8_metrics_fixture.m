function receipt=m8_metrics_fixture(folder)
% Synthetic metric fixture only: no problem/algorithm calls or model fits.
assert(~isfolder(folder),'Fixture path must be new.');mkdir(folder);
for n={'PF10000','PF2000'},mkdir(fullfile(folder,'references',n{1}));end
P=[0 1;1 0];F=[.2 .8;.8 .2];
for n={'PF10000','PF2000'}
 file=fullfile(folder,'references',n{1},'SYNTHETIC.csv');fid=fopen(file,'w');assert(fid>=0);fprintf(fid,'f1,f2\n0,1\n1,0\n');fclose(fid);
end
z=m8_metrics(folder,'SYNTHETIC',F);
assert(abs(z.IGD10000-sqrt(.08))<1e-12&&abs(z.HVr1p1-.45)<1e-12);
assert(abs(z.HVr3-7.48)<1e-12&&abs(z.HVr20-391.68)<1e-10);
empty=m8_metrics(folder,'SYNTHETIC',zeros(0,2));assert(isinf(empty.IGD10000)&&empty.HVr1p1==0);
outside=m8_metrics(folder,'SYNTHETIC',[2 2]);assert(isfinite(outside.IGD10000)&&outside.HVr1p1==0&&outside.HVr3==1);
better=m8_metrics(folder,'SYNTHETIC',[-.1 -.1]);assert(abs(better.HVr1p1-1.44)<1e-12);
receipt=struct('Status','pass','SyntheticCases',4,'ReferenceRows',size(P,1),'OptimizationRuns',0,'TrueEvaluations',0,'ModelFits',0);
end
