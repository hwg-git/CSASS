function report=v2d10_import_main(root,sourcePath)
% Reuse complete adaptive trials from the fixed V2 all-benchmark package.
% Called under this package's exclusive coordinator lock. Never run science.
root=char(java.io.File(char(root)).getCanonicalPath());
v2d10_preflight(root);
if nargin<2||isempty(sourcePath)
 sourcePath=uigetdir(pwd,'Select CSASS_V2_AllBenchmarks_MATLAB or its V2_AllBenchmarks output folder');
 assert(~isequal(sourcePath,0),'V2_Ablation_D10:ImportCancelled','Folder selection cancelled; no data changed.');
end
sourcePath=char(java.io.File(char(sourcePath)).getCanonicalPath());
if isfile(fullfile(sourcePath,'MAIN_CSASS_V2_ALL.m'))
 sourceRoot=sourcePath;
elseif isfolder(fullfile(sourcePath,'runs')) && isfile(fullfile(fileparts(fileparts(sourcePath)),'MAIN_CSASS_V2_ALL.m'))
 sourceRoot=fileparts(fileparts(sourcePath));
else
 error('V2_Ablation_D10:ImportFolder','Choose the full V2 package root or outputs/V2_AllBenchmarks; other versions cannot be imported.');
end
sourceOut=fullfile(sourceRoot,'outputs','V2_AllBenchmarks');
assert(isfolder(sourceOut),'V2_Ablation_D10:ImportAbsent','No full-campaign output folder exists yet.');
assert(~strcmpi(sourceRoot,char(java.io.File(root).getCanonicalPath())));
file=java.io.RandomAccessFile(fullfile(sourceOut,'coordinator.lock'),'rw');
try,lock=file.getChannel().tryLock();
catch e,file.close();error('V2_Ablation_D10:ImportBusy','Stop or finish the source controller first: %s',e.message);end
if isempty(lock),file.close();error('V2_Ablation_D10:ImportBusy','The full-campaign controller is active; import after it finishes or stops.');end
guard=onCleanup(@()close_lock(lock,file)); %#ok<NASGU>
cfg=v2d10_io('json',fullfile(sourceRoot,'protocol.json'));
assert(cfg.N==100&&cfg.MaxFE==500&&cfg.Pmax==20&&cfg.K==10&&cfg.RequestedPF==10000&&cfg.Scale==1);
assert(strcmp(cfg.Mode,'adaptive')&&strcmp(cfg.RBFKernel,'multiquadric')&&cfg.TotalTasks==2160);
assert(isequal(cfg.HVReferences(:)',[1.1,3,20]));
sourceLock=v2d10_io('json',fullfile(sourceRoot,'source_lock.json'));
localLock=v2d10_io('json',fullfile(root,'source_lock.json'));
assert(isfield(sourceLock,'Files')&&~isempty(sourceLock.Files),'Empty source package lock.');
sourceNames=replace(string({sourceLock.Files.Path}),'\','/');
assert(numel(unique(lower(sourceNames)))==numel(sourceLock.Files));
assert(all(ismember(["protocol.json","MAIN_CSASS_V2_ALL.m"],sourceNames)),'Source lock omits main protocol.');
for i=1:numel(sourceLock.Files)
 rel=char(sourceLock.Files(i).Path);filePath=verified_path(sourceRoot,rel);
 assert(strcmpi(v2d10_io('sha',filePath),sourceLock.Files(i).SHA256),'V2_Ablation_D10:ImportSourceModified','Source package modified: %s',rel);
end
localNames=replace(string({localLock.Files.Path}),'\','/');
protected=startsWith(localNames,{'engines/','benchmarks/','references/'});
for i=find(protected)
 rel=char(localNames(i));k=sourceNames==localNames(i);
 assert(sum(k)==1&&strcmpi(localLock.Files(i).SHA256,sourceLock.Files(k).SHA256),...
  'V2_Ablation_D10:ImportScienceMismatch','Scientific source or reference differs: %s',rel);
end
v2d10_engine_setup(root);tasks=v2d10_tasks(root);tasks=tasks(strcmp({tasks.Mode},'adaptive'));
names={'result.json','precision_ledger.csv','final_objectives.csv','final_decisions.csv',...
 'model_selection.csv','prediction_errors.csv','training_ids.csv','stage_flags.csv','fit_times.csv',...
 'final_training_archive.csv','final_surrogate_population_NOT_TRUE.csv','configuration.json','diagnostic_result.mat'};
imported={};existing={};unavailable={};
for i=1:numel(tasks)
 t=tasks(i);dest=fullfile(root,'outputs','V2_Ablation_D10','runs',t.ID);
 oldID=sprintf('V2_%s_D%d_seed%02d',t.Problem,t.D,t.Seed);
 src=fullfile(sourceOut,'runs',oldID);markerPath=fullfile(src,'completed.json');
 if isfolder(dest),existing{end+1}=t.ID;continue;end %#ok<AGROW>
 if ~isfile(markerPath),unavailable{end+1}=t.ID;continue;end %#ok<AGROW>
 marker=v2d10_io('json',markerPath);
 assert(strcmp(marker.ID,oldID)&&strcmp(marker.Version,'V2')&&strcmp(marker.Status,'completed'));
 assert(strcmp(marker.Problem,t.Problem)&&marker.D==t.D&&marker.Seed==t.Seed&&marker.FE==500);
 assert(isfield(marker,'Files')&&~isempty(marker.Files));
 assert(numel(unique(lower(replace(string({marker.Files.Path}),'\','/'))))==numel(marker.Files));
 assert(all(ismember(names,{marker.Files.Path})), 'A full-campaign completed trial is missing a required artifact.');
 for j=1:numel(marker.Files)
  rel=char(marker.Files(j).Path);filePath=verified_path(src,rel);
  assert(strcmpi(v2d10_io('sha',filePath),marker.Files(j).SHA256),'V2_Ablation_D10:ImportArtifactModified','Changed source trial artifact: %s/%s',oldID,rel);
 end
 r=v2d10_io('json',fullfile(src,'result.json'));
 assert(strcmp(r.ID,oldID)&&strcmp(r.Version,'V2')&&strcmp(r.Problem,t.Problem)&&r.D==t.D&&r.Seed==t.Seed);
 assert(r.FE==500&&r.N==100&&r.Pmax==20&&r.K==10&&r.RequestedPF==10000&&r.Scale==1&&strcmp(r.status,'completed'));
 conf=v2d10_io('json',fullfile(src,'configuration.json'));
 assert(isfield(conf,'Task')&&isfield(conf,'Options'),'Source configuration lacks task/options.');
 sourceTask=t;sourceTask.ID=oldID;
 for key={'ID','Version','Problem','D','Seed','Mode','N','MaxFE','Pmax','K'}
  k=key{1};assert(isfield(conf.Task,k)&&option_equal(conf.Task.(k),sourceTask.(k)),...
   'V2_Ablation_D10:ImportTaskMismatch','Source configuration task differs: %s',k);
 end
 expected=csass_v2.options(struct('N',100,'MaxFE',500,'Pmax',20,'K',10,'Seed',t.Seed,...
  'Mode','adaptive','RBFKernel','multiquadric','ReferencePoints',2000,'OutputDirectory','','Verbose',false));
 fields=fieldnames(expected);
 assert(isequal(sort(fieldnames(conf.Options)),sort(fields)),...
  'V2_Ablation_D10:ImportOptionMismatch','Source scientific option fields differ.');
 for j=1:numel(fields)
  k=fields{j};assert(option_equal(conf.Options.(k),expected.(k)),...
   'V2_Ablation_D10:ImportOptionMismatch','Source scientific option differs: %s',k);
 end
 F=readmatrix(fullfile(src,'final_objectives.csv'),'NumHeaderLines',1);
 m=2+double(ismember(t.Problem,{'CF8','LIRCMOP13'}));if isempty(F),F=zeros(0,m);end
 z=v2d10_metrics(root,F,t.Problem);assert(r.FeasibleND==size(F,1)&&logical(r.NonfiniteIGD)==isempty(F));
 for key={'IGD10000','IGD2000','HVr1p1','HVr3','HVr20'}
  k=key{1};if startsWith(k,'IGD')&&r.NonfiniteIGD,assert(isinf(z.(k)));continue;end
  assert(isfinite(r.(k))&&abs(z.(k)-r.(k))<=1e-10*max(1,abs(r.(k))),...
   'V2_Ablation_D10:ImportMetricMismatch','Source metric differs from saved final set: %s %s',oldID,k);
 end
 L=readmatrix(fullfile(src,'precision_ledger.csv'),'NumHeaderLines',1);
 nG=size(L,2)-(2+t.D+m+1);
 assert(size(L,1)==500&&nG>=1&&all(isfinite(L),'all')&&isequal(L(:,1),(1:500)'),...
  'V2_Ablation_D10:ImportLedger','Incomplete true-evaluation ledger in source.');
 assert(isequal(L(:,2),[zeros(100,1);repelem((1:40)',10)]),...
  'V2_Ablation_D10:ImportLedger','Source evaluation stages differ.');
 assert(isequal(L(:,end),sum(max(L(:,3+t.D+m:end-1),0),2)),...
  'V2_Ablation_D10:ImportLedger','Source CV does not equal sum(max(G,0)).');
 X=readmatrix(fullfile(src,'final_decisions.csv'),'NumHeaderLines',1);
 if isempty(X),X=zeros(0,t.D);end
 assert(size(X,1)==size(F,1)&&size(X,2)==t.D&&all(isfinite(X),'all'));
 [present,location]=ismember([X,F],L(:,3:2+t.D+m),'rows');
 assert(all(present)&&all(L(location,end)==0),...
  'V2_Ablation_D10:ImportFinalTruth','Final solution set is not a true feasible subset of the source ledger.');
 parent=fileparts(dest);if ~isfolder(parent),mkdir(parent);end
 claim=java.io.File(dest);assert(claim.mkdir(),'V2_Ablation_D10:ImportCollision','Destination already exists.');
 v2d10_io('writejson',fullfile(dest,'started.json'),struct('Task',t,'ImportOnly',true,'Source',src));
 % A failed copy deliberately leaves this claimed directory retained, never rerun.
 for j=1:numel(names),copyfile(fullfile(src,names{j}),fullfile(dest,names{j}));end
 copyfile(markerPath,fullfile(dest,'source_completed.json'));
 copyfile(fullfile(src,'result.json'),fullfile(dest,'source_result.json'));
 copyfile(fullfile(src,'configuration.json'),fullfile(dest,'source_configuration.json'));
 r.ID=t.ID;r.Mode=t.Mode;r.Source='imported_identical_V2_main_campaign';r.Origin='imported';
 r.ImportedFrom=src;r.SourceCompletedSHA256=v2d10_io('sha',markerPath);
 r.SourcePackageLockSHA256=v2d10_io('sha',fullfile(sourceRoot,'source_lock.json'));
 v2d10_io('writejson',fullfile(dest,'result.json'),r);
 conf.Task=t;conf.ImportedFrom=src;conf.ImportDoesNotChangeScientificOptions=true;
 v2d10_io('writejson',fullfile(dest,'configuration.json'),conf);
 marker.ID=t.ID;marker.Mode=t.Mode;marker.Source=r.Source;marker.ImportedFrom=src;marker.Origin='imported';
 marker.SourceCompletedSHA256=r.SourceCompletedSHA256;
 allNames=[names,{'source_completed.json','source_result.json','source_configuration.json'}];
 artifacts=repmat(struct('Path','','SHA256',''),numel(allNames),1);
 for j=1:numel(allNames),artifacts(j).Path=allNames{j};artifacts(j).SHA256=v2d10_io('sha',fullfile(dest,allNames{j}));end
 marker.Files=artifacts;marker.ImportedUTC=char(datetime('now','TimeZone','UTC'));
 v2d10_io('writejson',fullfile(dest,'completed.json'),marker);
 imported{end+1}=t.ID; %#ok<AGROW>
end
report=struct('Status','import_complete','OptimizationRuns',0,'TrueEvaluations',0,...
 'SourceRoot',sourceRoot,'Imported',numel(imported),'AlreadyPresent',numel(existing),...
 'NotAvailable',numel(unavailable),'ImportedIDs',{imported},'AlreadyPresentIDs',{existing},...
 'NotAvailableIDs',{unavailable},'ScientificSourcesAndReferencesByteIdentical',true,...
 'SelectionRule','Every completed source trial matching the fixed adaptive manifest, independent of scores');
dest=fullfile(root,'outputs','V2_Ablation_D10','import_receipts');if ~isfolder(dest),mkdir(dest);end
token=char(java.util.UUID.randomUUID);
v2d10_io('writejson',fullfile(dest,[char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')),'_',token(1:8),'.json']),report);
fprintf('IMPORTED %d complete adaptive trials; %d already present; %d not yet available. No optimization.\n',...
 report.Imported,report.AlreadyPresent,report.NotAvailable);
end
function path=verified_path(base,rel)
assert(ischar(rel)&&isrow(rel)&&~isempty(rel)&&~contains(rel,char(0)));
normalized=strrep(rel,'\','/');parts=strsplit(normalized,'/','CollapseDelimiters',false);
assert(~startsWith(normalized,'/')&&~contains(normalized,':')&&...
 ~any(ismember(parts,{'','.','..'})),'V2_Ablation_D10:ImportPath','Source paths must stay relative.');
canonicalBase=char(java.io.File(base).getCanonicalPath());
path=char(java.io.File(fullfile(base,rel)).getCanonicalPath());
assert(startsWith(lower(path),lower([canonicalBase,filesep])),...
 'V2_Ablation_D10:ImportPath','Resolved source path escapes its declared directory.');
assert(isfile(path),'V2_Ablation_D10:ImportPath','Missing source file: %s',rel);
end
function equal=option_equal(actual,expected)
% JSON loses row/column orientation and can change the class of empty values.
% Scalar scientific settings remain exact; only empty/string representations
% and vector orientation are normalized, never nonempty numeric values.
if isempty(expected)
 equal=isempty(actual);
elseif ischar(expected)||isstring(expected)
 equal=(ischar(actual)||isstring(actual))&&isscalar(string(actual))&&strcmp(string(actual),string(expected));
elseif isnumeric(expected)||islogical(expected)
 equal=(isnumeric(actual)||islogical(actual))&&numel(actual)==numel(expected)&&...
  isequaln(double(actual(:)),double(expected(:)));
else
 equal=isequaln(actual,expected);
end
end
function close_lock(lock,file)
try,if lock.isValid(),lock.release();end,catch,end
try,file.close();catch,end
end
