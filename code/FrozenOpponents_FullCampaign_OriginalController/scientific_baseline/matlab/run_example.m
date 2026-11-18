function result = run_example(name,D,seed,mode,kernel)
% In MATLAB: cd('<project>/matlab'); result=run_example;
if nargin<1, name='CF2'; end
if nargin<2, D=10; end
if nargin<3, seed=1; end
if nargin<4, mode='adaptive'; end
if nargin<5, kernel='quadratic'; end
root=setup_csass();
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
directory=fullfile(root,'..','results',[name,'_D',num2str(D),'_',mode,'_',kernel, ...
    '_seed',num2str(seed),'_',stamp]);
o=struct('Seed',seed,'Mode',mode,'RBFKernel',kernel,'OutputDirectory',directory);
result=csass_run(csass.problem(name,D),o);
fprintf('Saved: %s\nIGD=%g HV=%g feasible ND=%d time=%.2fs\n',directory, ...
    result.metrics.IGD,result.metrics.HV,size(result.finalF,1),result.runtimeSeconds);
end
