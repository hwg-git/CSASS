function r=v2d10_trial(root,t)
v2d10_engine_setup(root);
oldThreads=maxNumCompThreads;maxNumCompThreads(1);
threadGuard=onCleanup(@()maxNumCompThreads(oldThreads)); %#ok<NASGU>
dest=fullfile(root,'outputs','V2_Ablation_D10','runs',t.ID);
parent=fileparts(dest);if ~isfolder(parent),mkdir(parent);end
claim=java.io.File(dest);assert(claim.mkdir(),'Run directory already exists; refusing overwrite/retry: %s',t.ID);
v2d10_io('writejson',fullfile(dest,'started.json'),struct('Task',t,'PID',feature('getpid'),...
 'MATLAB',version,'StartedUTC',char(datetime('now','TimeZone','UTC'))));
timer=tic;
try
 options=struct('N',100,'MaxFE',500,'Pmax',20,'K',10,'Seed',t.Seed,'Mode',t.Mode,...
  'RBFKernel','multiquadric','ReferencePoints',2000,'OutputDirectory','','Verbose',false,...
  'EvaluationCallback',@(X,F,G)v2d10_log_evaluations(dest,t,X,F,G));
 result=v2d10_engine(root,t,options);
 assert(result.problem.D==t.D && ismember(result.problem.M,[2,3]));
 assert(result.FE==500&&size(result.history.X,1)==500&&numel(result.stages)==40);
 H=result.history;assert(all(isfinite(H.F),'all')&&all(isfinite(H.G),'all'));
 assert(all(H.CV==sum(max(H.G,0),2)));
 ledger=readmatrix(fullfile(dest,'precision_ledger.csv'),'NumHeaderLines',1);
 expected=[H.EvaluationID,H.Stage,H.X,H.F,H.G,H.CV];
 assert(isequal(ledger,expected),'Saved true-evaluation ledger differs from engine history.');
 z=v2d10_metrics(root,result.finalF,t.Problem);
 r=struct('ID',t.ID,'Version',t.Version,'Problem',t.Problem,'D',t.D,'Seed',t.Seed,'Mode',t.Mode,...
  'FE',500,'N',100,'Pmax',20,'K',10,'status','completed','Status','completed',...
  'Source','new_frozen_V2_ablation','RuntimeSeconds',result.runtimeSeconds,'ElapsedSeconds',toc(timer));
 f=fieldnames(z);for i=1:numel(f),r.(f{i})=z.(f{i});end
 r.FinalObjectivesAvailable=true;
 r.TrueFeasibleEvaluations=sum(H.CV==0);first=find(H.CV==0,1);
 if isempty(first),r.FirstFeasibleFE=NaN;else,r.FirstFeasibleFE=H.EvaluationID(first);end
 v2d10_csv(fullfile(dest,'final_objectives.csv'),cellstr(compose('f%d',1:size(result.finalF,2))),result.finalF);
 v2d10_csv(fullfile(dest,'final_decisions.csv'),cellstr(compose('x%d',1:t.D)),result.finalX);
 v2d10_export_logs(result,dest);
 save(fullfile(dest,'diagnostic_result.mat'),'result','-v7.3');
 v2d10_io('writejson',fullfile(dest,'configuration.json'),struct('Task',t,'Options',result.options,...
  'OutputRule',result.outputRule,'MATLAB',version,'ComputeThreads',1,'PrimaryIGDRequest',10000,...
  'PrimaryIGDScale',1,'HVNormalization','Frozen PF10000 minima/ranges; references fixed for all runs',...
  'RuntimeNote','Diagnostic logging included; not comparable to earlier bare-runtime table'));
 v2d10_io('writejson',fullfile(dest,'result.json'),r);
 artifactNames={'result.json','precision_ledger.csv','final_objectives.csv','final_decisions.csv',...
  'model_selection.csv','prediction_errors.csv','training_ids.csv','stage_flags.csv','fit_times.csv',...
  'final_training_archive.csv','final_surrogate_population_NOT_TRUE.csv','configuration.json','diagnostic_result.mat'};
 files=repmat(struct('Path','','SHA256',''),numel(artifactNames),1);
 for i=1:numel(files),files(i).Path=artifactNames{i};files(i).SHA256=v2d10_io('sha',fullfile(dest,artifactNames{i}));end
 marker=struct('Status','completed','status','completed','ID',t.ID,'Version',t.Version,...
  'Problem',t.Problem,'D',t.D,'Seed',t.Seed,'Mode',t.Mode,'FE',500,'Files',files,...
  'CompletedUTC',char(datetime('now','TimeZone','UTC')));
 v2d10_io('writejson',fullfile(dest,'completed.json'),marker);
catch err
 actual=0;f=fullfile(dest,'precision_ledger.csv');
 if isfile(f),try,A=readmatrix(f,'NumHeaderLines',1);actual=size(A,1);catch,end,end
 v2d10_io('writejson',fullfile(dest,'failure.json'),struct('Task',t,'ActualFE',actual,...
  'ElapsedSeconds',toc(timer),'Error',getReport(err,'extended','hyperlinks','off')));
 rethrow(err);
end
end
