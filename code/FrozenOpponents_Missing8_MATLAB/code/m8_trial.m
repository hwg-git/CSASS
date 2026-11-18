function result=m8_trial(root,t)
% Frozen scientific engine; only logging, metric recomputation and packaging are new.
maxNumCompThreads(1);oldpath=path;guard=onCleanup(@()path(oldpath)); %#ok<NASGU>
portable_setup(root,t.Algorithm);c=m8_config(root);
assert(t.N==100&&t.MaxFE==500&&t.M==2&&ismember(t.Algorithm,c.Algorithms));
dest=fullfile(c.Output,'runs',t.ID);claim=java.io.File(dest);
parent=fileparts(dest);if ~isfolder(parent),mkdir(parent);end
assert(claim.mkdir(),'Run already exists; preserve completed/partial/failed data: %s',t.ID);
lockHash=m8_io('sha',fullfile(root,'source_lock.json'));
m8_io('writejson',fullfile(dest,'started.json'),struct('Task',t,'MATLAB',version,'PID',feature('getpid'),...
 'SourceCodeLockSHA256',lockHash,'StartedUTC',char(datetime('now','TimeZone','UTC'))));
b=[];start=tic;
try
 b=PortableLedgerProblem(t.Problem,t.D,100,500);assert(b.M==2);
 b.LedgerCSV=fullfile(dest,'partial_truth.csv');
 a=feval(t.Algorithm,'save',1,'outputFcn',@(~,~)[]);
 rng(t.Seed,'twister');timer=tic;a.Solve(b);runtime=toc(timer);H=b.H;
 assert(b.N==100&&b.InitialN==100,'Unexpected actual population or initial sample count.');
 assert(b.FE==500&&size(H.X,1)==500&&all(isfinite(H.F),'all')&&all(isfinite(H.G),'all'));
 assert(isequal(H.EvaluationID,(1:500)')&&sum(H.Stage==0)==100);
 assert(isequal(H.CV,sum(max(0,H.G),2)));
 ids=csass.environment(H.F,H.CV,100);ids=ids(H.CV(ids)==0);
 if ~isempty(ids),ids=ids(~any(csass.dominance(H.F(ids,:),zeros(numel(ids),1)),1));end
 finalids=ids;F=H.F(ids,:);X=H.X(ids,:);G=H.G(ids,:);
 % This is the same final-set extraction as the original full campaign.
 metrics=m8_metrics(root,t.Problem,F);
 nativeF=zeros(0,b.M);nativeCV=zeros(0,1);nativeSavedFE=0;
 if ~isempty(a.result),z=a.result{end,2};nativeF=z.objs;nativeCV=sum(max(0,z.cons),2);nativeSavedFE=a.result{end,1};end
 options=struct('AlgorithmParameters',{a.parameter},'ActualN',100,'InitialN',100);
 movefile(b.LedgerCSV,fullfile(dest,'precision_ledger.csv'));
 m8_io('csv',fullfile(dest,'final_objectives.csv'),cellstr(compose('f%d',1:b.M)),F);
 m8_io('csv',fullfile(dest,'final_decisions.csv'),cellstr(compose('x%d',1:t.D)),X);
 m8_io('csv',fullfile(dest,'final_constraints.csv'),cellstr(compose('g%d',1:size(G,2))),G);
 m8_io('csv',fullfile(dest,'native_final.csv'),[cellstr(compose('f%d',1:b.M)),{'CV'}],[nativeF,nativeCV]);
 m8_io('csv',fullfile(dest,'initial_decisions.csv'),cellstr(compose('x%d',1:t.D)),H.X(1:100,:));
 result=struct('ID',t.ID,'Algorithm',t.Algorithm,'Problem',t.Problem,'D',t.D,'M',b.M,'Seed',t.Seed,...
  'Status','completed','FE',500,'N',100,'NominalN',100,'ActualN',100,'InitialN',100,...
  'IGD2000',metrics.IGD2000,'IGD10000',metrics.IGD10000,...
  'NonfiniteIGD2000',~isfinite(metrics.IGD2000),'NonfiniteIGD10000',~isfinite(metrics.IGD10000),...
  'HVr1p1',metrics.HVr1p1,'HVr3',metrics.HVr3,'HVr20',metrics.HVr20,...
  'ReferenceCount10000',metrics.ReferenceCount10000,'ReferenceCount2000',metrics.ReferenceCount2000,...
  'FeasibleND',size(F,1),'TrueFeasibleEvaluations',sum(H.CV==0),'RuntimeSeconds',runtime,...
  'ElapsedWithExportsSeconds',toc(start),'NativeSavedFE',nativeSavedFE,'TruncatedRows',b.TruncatedRows,...
  'SourceCodeLockSHA256',lockHash,'InitialSHA256',m8_io('sha',fullfile(dest,'initial_decisions.csv')));
 configuration=struct('Task',t,'Options',options,'MATLAB',version,'Toolboxes',ver,...
  'ThreadsPerTrial',1,'PrimaryIGDPFRequest',10000,'PrimaryHVReference',1.1,...
  'Initialization','unchanged shared csass.lhs','CommonOutputN',100,'RawConstraintRule','sum(max(0,G),2)',...
  'SourceCodeLockSHA256',lockHash);
 m8_io('writejson',fullfile(dest,'configuration.json'),configuration);
 save(fullfile(dest,'result.mat'),'result','H','finalids','options','metrics','nativeF','nativeCV','-v7');
 encoded=result;
 for f={'IGD2000','IGD10000'},if isinf(encoded.(f{1})),encoded.(f{1})='Inf';end,end
 m8_io('writejson',fullfile(dest,'result.json'),encoded);
 files={'result.json','result.mat','precision_ledger.csv','final_decisions.csv','final_objectives.csv',...
  'final_constraints.csv','initial_decisions.csv','native_final.csv','configuration.json'};
 receipt=repmat(struct('Path','','SHA256',''),numel(files),1);
 for i=1:numel(files),receipt(i)=struct('Path',files{i},'SHA256',m8_io('sha',fullfile(dest,files{i})));end
 marker=t;marker.Status='completed';marker.FE=500;marker.InitialN=100;marker.Files=receipt;marker.SourceCodeLockSHA256=lockHash;
 m8_io('writejson',fullfile(dest,'completed.json'),marker);
catch e
 failure=struct('Status','failed','Task',t,'Error',getReport(e,'extended','hyperlinks','off'),...
  'ElapsedSeconds',toc(start),'SourceCodeLockSHA256',lockHash);
 if ~isempty(b),failure.EvaluationsCompleted=b.FE;end
 m8_io('writejson',fullfile(dest,'failure.json'),failure);
 rethrow(e);
end
end
