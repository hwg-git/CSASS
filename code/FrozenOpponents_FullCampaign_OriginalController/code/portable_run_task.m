function out=portable_run_task(root,t,c)
maxNumCompThreads(1);oldpath=path;restore=onCleanup(@()path(oldpath));portable_setup(root,t.Algorithm);
out=struct('ID',t.ID,'Status','failed','IGD',NaN,'HV',NaN,'RuntimeSeconds',NaN);
dest=fullfile(c.Output,'runs',t.ID);lock=fullfile(c.Output,'locks',t.ID);
if isfile(fullfile(dest,'completed.json')),out=portable_read_json(fullfile(dest,'result.json'));if out.NonfiniteIGD,out.IGD=Inf;end;return;end
assert(~isfolder(dest),'Incomplete/failed run exists; preserve it for review rather than silently rerunning.');
claim=java.io.File(lock);assert(claim.mkdir(),'Trial already claimed by another process.');mkdir(dest);
portable_write_json(fullfile(dest,'started.json'),struct('Unix',posixtime(datetime('now','TimeZone','UTC')),'Task',t,'MATLAB',version,'PID',feature('getpid')));
b=[];started=tic;
try
 b=PortableLedgerProblem(t.Problem,t.D,100,500);assert(ismember(b.M,[2,3]));b.LedgerCSV=fullfile(dest,'partial_truth.csv');
 if strcmp(t.Algorithm,'CSASS')
  [o,~]=source_aligned_options();o.Seed=t.Seed;o.Verbose=false;o.OutputDirectory='';
  r=csass_run(portable_problem(b,t.Problem),o);H=r.history;runtime=r.runtimeSeconds;actualN=100;initialN=100;
  assert(isequal(H,b.H)&&r.FE==500&&numel(r.stages)==40);
  nativeF=r.finalF;nativeCV=zeros(size(nativeF,1),1);nativeSavedFE=500;options=o;
  portable_export_model_logs(r,dest);
 else
  a=feval(t.Algorithm,'save',1,'outputFcn',@(~,~)[]);rng(t.Seed,'twister');timer=tic;a.Solve(b);runtime=toc(timer);H=b.H;
  actualN=b.N;initialN=b.InitialN;expected=100;if b.M==3&&ismember(t.Algorithm,{'ANSGAIII','CTAEA'}),expected=91;end
  assert(actualN==expected&&initialN==expected,'Unexpected population or initial sample count.');
  nativeF=zeros(0,b.M);nativeCV=zeros(0,1);nativeSavedFE=0;
  if ~isempty(a.result),z=a.result{end,2};nativeF=z.objs;nativeCV=sum(max(0,z.cons),2);nativeSavedFE=a.result{end,1};end
  options=struct('AlgorithmParameters',{a.parameter},'ActualN',actualN,'InitialN',initialN);
 end
 assert(b.FE==500&&size(H.X,1)==500&&all(isfinite(H.F),'all')&&all(isfinite(H.G),'all'));
 ids=csass.environment(H.F,H.CV,100);F=H.F(ids,:);CV=H.CV(ids);F=F(CV==0,:);
 if ~isempty(F),F=F(~any(csass.dominance(F,zeros(size(F,1),1)),1),:);end
 PF=readmatrix(fullfile(c.Output,'references',[t.Problem,'.csv']),'NumHeaderLines',1);metrics=csass.metrics(F,PF,1.1*ones(1,b.M));
 if strcmp(t.Algorithm,'CSASS'),assert(isequaln(metrics,r.metrics)&&isequal(F,r.finalF));end
 normalized=(F-metrics.Ideal)./(metrics.Nadir-metrics.Ideal);
 hv15=csass.hypervolume(normalized,1.5*ones(1,b.M));hv2=csass.hypervolume(normalized,2*ones(1,b.M));
 assert(~isfile(fullfile(dest,'precision_ledger.csv')));movefile(b.LedgerCSV,fullfile(dest,'precision_ledger.csv'));
 portable_write_csv(fullfile(dest,'final_objectives.csv'),cellstr(compose('f%d',1:b.M)),F);
 portable_write_csv(fullfile(dest,'native_final.csv'),[cellstr(compose('f%d',1:b.M)),{'CV'}],[nativeF,nativeCV]);
 portable_write_csv(fullfile(dest,'initial_points.csv'),cellstr(compose('x%d',1:t.D)),H.X(1:initialN,:));
 outcome='finite_IGD';if isempty(F),outcome='no_feasible_set';elseif metrics.HV==0,outcome='finite_IGD_zero_HV';end
 out=struct('ID',t.ID,'Status','completed','Algorithm',t.Algorithm,'Problem',t.Problem,'D',t.D,'Seed',t.Seed,'M',b.M,'NominalN',100,'ActualN',actualN,'InitialN',initialN,'FE',500,'IGD',metrics.IGD,'NonfiniteIGD',~isfinite(metrics.IGD),'HV',metrics.HV,'HVRef1p5',hv15,'HVRef2p0',hv2,'FeasibleND',size(F,1),'PositiveCVSamples',sum(H.CV>0),'HVExcludedCount',metrics.HVExcludedCount,'RuntimeSeconds',runtime,'ElapsedWithExportsSeconds',toc(started),'NativeSavedFE',nativeSavedFE,'ReferenceCount',size(PF,1),'Outcome',outcome);
 portable_write_json(fullfile(dest,'configuration.json'),struct('Task',t,'PopulationPolicy',c.PopulationPolicy,'Options',options,'CommonOutputN',100,'HVReference',1.1*ones(1,b.M),'RawConstraintRule','sum(max(0,G),2)','MATLAB',version,'Threads',maxNumCompThreads));
 portable_write_json(fullfile(dest,'metrics.json'),metrics);portable_write_json(fullfile(dest,'result.json'),out);
 portable_write_json(fullfile(dest,'completed.json'),struct('Status','completed','FE',500,'TaskID',t.ID));
catch e
 if exist('r','var'),save(fullfile(dest,'debug_result.mat'),'r','-v7.3');end
 failure=struct('Status','failed','Task',t,'Error',getReport(e,'extended','hyperlinks','off'),'ElapsedSeconds',toc(started));
 if ~isempty(b),failure.EvaluationsCompleted=b.FE;end
 portable_write_json(fullfile(dest,'failure.json'),failure);fprintf(2,'FAIL %s: %s\n',t.ID,e.message);
end
% Keep the small lock directory as a permanent claim; completed marker controls resume.
end
