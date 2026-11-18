function report=abl2050_autoimport(root,sourcePath,action,selector)
% Explicit reuse/independent policy. Cancel is a no-op, never experiment consent.
% Caller owns target coordinator lock. No optimization is performed here.
if nargin<2,sourcePath=[];end
if nargin<3||isempty(action),action='resume';end
if islogical(action),if action,action='select';else,action='resume';end,end
assert(ismember(action,{'resume','select','independent'}),'Ablation_D20D50:ImportAction','Unknown reuse action.');
if nargin<4||isempty(selector)
 selector=@()uigetdir(pwd,'Select completed full-V2 package. Cancel stops; run_independent is an explicit separate command.');
end
assert(isa(selector,'function_handle'),'Ablation_D20D50:ImportSelector','Folder selector must be a function handle.');
out=fullfile(root,'outputs','Ablation_D20D50');if ~isfolder(out),mkdir(out);end
policyPath=fullfile(out,'import_policy.json');policy=struct();
if isfile(policyPath),policy=abl2050_io('json',policyPath);end
if strcmp(action,'independent')
 policy=struct('Policy','independent','ExplicitIndependent',true,'Command','run_independent',...
  'SourcePath','','UpdatedUTC',utc_now(),'FixedTotalTasks',1800,...
  'Meaning','Explicitly authorized independent manifest; existing complete records remain retained and skipped.');
 abl2050_io('writejson',policyPath,policy);
 report=struct('Status','independent_mode','Imported',0,'OptimizationRuns',0,...
  'Message','Explicit run_independent selected: execute only unfinished slots of the fixed1800 manifest.');
 fprintf('%s\n',report.Message);return;
end
% A fully imported local adaptive set is self-contained. Validate every byte
% and its original-source evidence chain before permitting source-free resume.
if strcmp(action,'resume') && isempty(sourcePath)
 audit=verify_local_imports(root,policy);
 if audit.AllVerified
  policy.Policy='reuse';policy.SourceRequiredForResume=false;policy.LocalImportAudit=audit;
  policy.LocalImportsVerified=true;policy.UpdatedUTC=utc_now();
  policy.SourcePackageLockSHA256=audit.SourcePackageLockSHA256;
  if ~isfield(policy,'SourcePath'),policy.SourcePath='';end
  abl2050_io('writejson',policyPath,policy);
  report=struct('Status','local_imports_verified','Imported',0,'AlreadyPresent',360,...
   'NotAvailable',0,'AllRequiredSourceComplete',true,'OptimizationRuns',0,'LocalAudit',audit,...
   'Message','All360 local adaptive imports and their source evidence verified; original source folder is not required.');
  fprintf('%s\n',report.Message);return;
 end
end
if ~isempty(sourcePath)
 assert(ischar(sourcePath)||(isstring(sourcePath)&&isscalar(sourcePath)),...
  'Ablation_D20D50:ImportPath','Source must be a folder path.');choice=char(sourcePath);
elseif strcmp(action,'select') || ~isfield(policy,'Policy')
 choice=selector();
elseif strcmp(policy.Policy,'independent')
 if isfield(policy,'ExplicitIndependent')&&isequal(policy.ExplicitIndependent,true)&&...
    isfield(policy,'Command')&&strcmp(policy.Command,'run_independent')
  report=struct('Status','independent_mode','Imported',0,'OptimizationRuns',0,...
   'Message','Resuming the saved explicit run_independent choice; existing complete records remain skipped.');
  fprintf('%s\n',report.Message);return;
 end
 % Older cancel-based policy is not valid consent for independent execution.
 choice=selector();
elseif strcmp(policy.Policy,'reuse')
 assert(isfield(policy,'SourcePath')&&~isempty(policy.SourcePath),...
  'Ablation_D20D50:ImportPath','Stored reuse source missing; use import to select a source or run_independent explicitly.');
 choice=char(policy.SourcePath);
else,error('Ablation_D20D50:ImportPolicy','Saved reuse policy is invalid.');end
if isequal(choice,0)
 report=struct('Status','cancelled','Imported',0,'OptimizationRuns',0,...
  'Message','Folder selection cancelled. No policy changed and no experiment started. Use run_independent only if independent runs are intended.');
 fprintf('%s\n',report.Message);return;
end
assert(ischar(choice)||(isstring(choice)&&isscalar(choice)),'Ablation_D20D50:ImportPath','Invalid selected folder.');
assert(isfolder(choice),'Ablation_D20D50:ImportFolder',...
 'Selected/saved source is unavailable and360 valid local imports are not complete: %s',char(choice));
choice=char(java.io.File(char(choice)).getCanonicalPath());
policy=struct('Policy','reuse','SourcePath',choice,'UpdatedUTC',utc_now(),...
 'RequiredCompleteSourceAdaptive',360,'FixedTotalTasks',1800,'SourceRequiredForResume',true,...
 'Meaning','Require all360 adaptive source trials complete and identical before copying; verified local imports later permit source-free resume.');
abl2050_io('writejson',policyPath,policy);
report=abl2050_import_main(root,choice);
assert(report.NotAvailable==0&&report.AllRequiredSourceComplete,...
 'Ablation_D20D50:IncompleteImport','Reuse verification incomplete; no optimization may start.');
policy.SourcePackageLockSHA256=report.SourcePackageLockSHA256;
audit=verify_local_imports(root,policy);
% Prior independently computed adaptive records may legitimately occupy slots.
% They are never relabelled imports; their normal final audit remains required.
policy.LastVerifiedUTC=utc_now();policy.LastImported=report.Imported;policy.AlreadyPresent=report.AlreadyPresent;
policy.LocalImportsVerified=audit.AllVerified;policy.LocalImportAudit=audit;
policy.SourceRequiredForResume=~audit.AllVerified;policy.UpdatedUTC=utc_now();
abl2050_io('writejson',policyPath,policy);
end

function audit=verify_local_imports(root,policy)
tasks=abl2050_tasks(root);tasks=tasks(strcmp({tasks.Mode},'adaptive'));
assert(numel(tasks)==360&&all(ismember([tasks.D],[20,50])),'Ablation_D20D50:ReuseScope','Expected360 adaptive D20/D50 tasks.');
audit=struct('AllVerified',false,'Expected',360,'Verified',0,'ArtifactHashesChecked',0,...
 'SourceEvidenceTriplesChecked',0,'SourcePackageLockSHA256','','CompletedMarkersDigestSHA256','','VerifiedUTC','');
base=fullfile(root,'outputs','Ablation_D20D50','runs');
for i=1:numel(tasks)
 f=fullfile(base,tasks(i).ID,'completed.json');if ~isfile(f),return;end
 m=abl2050_io('json',f);
 if ~isfield(m,'Origin')||~strcmp(m.Origin,'imported'),return;end
end
core={'result.json','precision_ledger.csv','final_objectives.csv','final_decisions.csv',...
 'model_selection.csv','prediction_errors.csv','training_ids.csv','stage_flags.csv','fit_times.csv',...
 'final_training_archive.csv','final_surrogate_population_NOT_TRUE.csv','configuration.json','diagnostic_result.mat'};
evidence={'source_completed.json','source_result.json','source_configuration.json'};
markerProof=cell(360,1);sourceLocks=cell(360,1);
for i=1:numel(tasks)
 t=tasks(i);d=fullfile(base,t.ID);markerPath=fullfile(d,'completed.json');m=abl2050_io('json',markerPath);
 check_identity(m,t.ID,t,true);assert(strcmp(m.Status,'completed')&&m.FE==500,'Ablation_D20D50:ReuseStatus','Invalid local completion status/FE.');
 assert(isfield(m,'Files')&&ismember(numel(m.Files),[13,16]),'Ablation_D20D50:ReuseArtifacts','Expected13/16 files.');
 names={m.Files.Path};extras=setdiff(names,core);
 assert(numel(unique(names))==numel(names)&&all(ismember(core,names))&&...
  (isempty(extras)||isequal(sort(extras),sort(evidence))),'Ablation_D20D50:ReuseArtifacts','Unexpected/missing local import artifact.');
 for j=1:numel(m.Files)
  f=fullfile(d,m.Files(j).Path);
  assert(isfile(f)&&strcmpi(abl2050_io('sha',f),m.Files(j).SHA256),...
   'Ablation_D20D50:ReuseArtifactHash','Local imported artifact changed: %s/%s',t.ID,m.Files(j).Path);
  audit.ArtifactHashesChecked=audit.ArtifactHashesChecked+1;
 end
 for j=1:3,assert(isfile(fullfile(d,evidence{j})),'Ablation_D20D50:ReuseEvidence','Original source evidence missing: %s',t.ID);end
 r=abl2050_io('json',fullfile(d,'result.json'));conf=abl2050_io('json',fullfile(d,'configuration.json'));
 check_identity(r,t.ID,t,true);check_identity(conf.Task,t.ID,t,true);
 assert(strcmp(r.status,'completed')&&r.FE==500&&r.N==100&&r.Pmax==20&&r.K==10&&r.RequestedPF==10000&&r.Scale==1);
 assert(strcmp(r.Source,'imported_identical_V2_main_campaign')&&strcmp(r.Origin,'imported'));
 original=abl2050_io('json',fullfile(d,'source_completed.json'));oldID=sprintf('V2_%s_D%d_seed%02d',t.Problem,t.D,t.Seed);
 check_identity(original,oldID,t,false);assert(strcmp(original.Status,'completed')&&original.FE==500);
 sourceMarkerSHA=abl2050_io('sha',fullfile(d,'source_completed.json'));
 assert(strcmpi(sourceMarkerSHA,r.SourceCompletedSHA256)&&strcmpi(sourceMarkerSHA,m.SourceCompletedSHA256),...
  'Ablation_D20D50:ReuseEvidenceHash','Original completion marker identity/hash broken.');
 onames={original.Files.Path};assert(numel(onames)==13&&numel(unique(onames))==13&&isequal(sort(onames),sort(core)));
 for j=1:numel(original.Files)
  n=original.Files(j).Path;proof=n;
  if strcmp(n,'result.json'),proof='source_result.json';elseif strcmp(n,'configuration.json'),proof='source_configuration.json';end
  assert(strcmpi(abl2050_io('sha',fullfile(d,proof)),original.Files(j).SHA256),...
   'Ablation_D20D50:ReuseSourceHash','Original source artifact chain broken: %s/%s',t.ID,n);
 end
 sr=abl2050_io('json',fullfile(d,'source_result.json'));sc=abl2050_io('json',fullfile(d,'source_configuration.json'));
 check_identity(sr,oldID,t,false);check_identity(sc.Task,oldID,t,true);
 for key={'FE','N','Pmax','K','RequestedPF','Scale','FeasibleND','NonfiniteIGD','IGD10000','IGD2000','HVr1p1','HVr3','HVr20'}
  k=key{1};assert(isfield(sr,k)&&isfield(r,k)&&isequaln(sr.(k),r.(k)),...
   'Ablation_D20D50:ReuseResultChanged','Imported/source result mismatch: %s/%s',t.ID,k);
 end
 assert(isequaln(conf.Options,sc.Options),'Ablation_D20D50:ReuseOptions','Imported options differ from source.');
 o=conf.Options;assert(o.N==100&&o.MaxFE==500&&o.Pmax==20&&o.K==10&&o.Seed==t.Seed&&...
  strcmp(o.Mode,'adaptive')&&strcmp(o.RBFKernel,'multiquadric')&&o.ReferencePoints==2000);
 assert(conf.Task.N==100&&conf.Task.MaxFE==500&&conf.Task.Pmax==20&&conf.Task.K==10);
 sourceLocks{i}=char(r.SourcePackageLockSHA256);
 assert(~isempty(regexp(sourceLocks{i},'^[a-fA-F0-9]{64}$','once')),'Ablation_D20D50:ReuseSourceLock','Invalid recorded source lock.');
 if isfield(policy,'SourcePackageLockSHA256')&&~isempty(policy.SourcePackageLockSHA256)
  assert(strcmpi(sourceLocks{i},policy.SourcePackageLockSHA256),'Ablation_D20D50:ReuseSourceLock','Saved reuse policy/source lock mismatch.');
 end
 markerProof{i}=[t.ID,':',abl2050_io('sha',markerPath)];
 audit.Verified=audit.Verified+1;audit.SourceEvidenceTriplesChecked=audit.SourceEvidenceTriplesChecked+1;
end
assert(numel(unique(lower(string(sourceLocks))))==1,'Ablation_D20D50:ReuseSourceLock','Imports refer to different frozen source packages.');
audit.SourcePackageLockSHA256=sourceLocks{1};md=java.security.MessageDigest.getInstance('SHA-256');
md.update(unicode2native(strjoin(markerProof,newline),'UTF-8'));
audit.CompletedMarkersDigestSHA256=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
audit.AllVerified=audit.Verified==360;audit.VerifiedUTC=utc_now();
end
function check_identity(s,id,t,requireMode)
assert(isfield(s,'ID')&&strcmp(s.ID,id),'Ablation_D20D50:ReuseIdentity','Record ID mismatch.');
for key={'Version','Problem','D','Seed'}
 k=key{1};assert(isfield(s,k)&&isequal(s.(k),t.(k)),'Ablation_D20D50:ReuseIdentity','Record task field mismatch: %s',k);
end
if requireMode,assert(isfield(s,'Mode')&&strcmp(s.Mode,'adaptive'),'Ablation_D20D50:ReuseMode','Expected adaptive mode.');end
end
function s=utc_now()
s=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end