function report=abl2050_reuse_fixture(~)
% Pure synthetic policy/provenance fixture. No engine, pool, or evaluations.
scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()clean_scratch(scratch)); %#ok<NASGU>
out=fullfile(scratch,'outputs','Ablation_D20D50');
policyPath=fullfile(out,'import_policy.json');
cancelled=abl2050_autoimport(scratch,[],'resume',@()0);
assert(strcmp(cancelled.Status,'cancelled')&&~isfile(policyPath));
assert(~isfolder(fullfile(out,'runs')));
legacy=struct('Policy','independent','SourcePath','');
abl2050_io('writejson',policyPath,legacy);before=abl2050_io('sha',policyPath);
cancelled=abl2050_autoimport(scratch,[],'resume',@()0);
assert(strcmp(cancelled.Status,'cancelled')&&strcmp(before,abl2050_io('sha',policyPath)));
explicit=abl2050_autoimport(scratch,[],'independent',@unexpected_selector);
assert(strcmp(explicit.Status,'independent_mode'));
p=abl2050_io('json',policyPath);
assert(p.ExplicitIndependent&&strcmp(p.Command,'run_independent'));
resumed=abl2050_autoimport(scratch,[],'resume',@unexpected_selector);
assert(strcmp(resumed.Status,'independent_mode'));
before=abl2050_io('sha',policyPath);
cancelled=abl2050_autoimport(scratch,[],'select',@()0);
assert(strcmp(cancelled.Status,'cancelled')&&strcmp(before,abl2050_io('sha',policyPath)));

tasks=abl2050_tasks(scratch);tasks=tasks(strcmp({tasks.Mode},'adaptive'));
assert(numel(tasks)==360);sourceSHA=repmat('a',1,64);
for i=1:numel(tasks),write_import_fixture(out,tasks(i),sourceSHA,mod(i,2)==0);end
missingSource=fullfile(scratch,'source_was_removed');assert(~isfolder(missingSource));
p=struct('Policy','reuse','SourcePath',missingSource,'SourcePackageLockSHA256',sourceSHA);
abl2050_io('writejson',policyPath,p);
local=abl2050_autoimport(scratch,[],'resume',@unexpected_selector);
assert(strcmp(local.Status,'local_imports_verified'));
assert(local.LocalAudit.Verified==360&&local.LocalAudit.SourceEvidenceTriplesChecked==360);
assert(local.LocalAudit.ArtifactHashesChecked==180*13+180*16);
p=abl2050_io('json',policyPath);
assert(p.LocalImportsVerified&&~p.SourceRequiredForResume&&strcmp(p.SourcePath,missingSource));
assert(~isfolder(missingSource));
bad=fullfile(out,'runs',tasks(1).ID,'final_objectives.csv');
fid=fopen(bad,'a');assert(fid>=0);fprintf(fid,'tampered');fclose(fid);
rejected=false;
try,abl2050_autoimport(scratch,[],'resume',@unexpected_selector);
catch e,rejected=strcmp(e.identifier,'Ablation_D20D50:ReuseArtifactHash');end
assert(rejected,'Ablation_D20D50:FixtureTamper','Corrupted local import was not rejected.');
report=struct('Status','pass','ScientificRuns',0,'TrueEvaluations',0,'PoolStarted',false,...
 'CancellationNoPolicyOrRuns',true,'LegacyCancelPolicyRejected',true,...
 'ExplicitIndependentOnly',true,'SavedExplicitIndependentResumed',true,...
 'ForcedSelectionCancelPreservesPolicy',true,'ImportedLocalTrialsVerified',360,...
 'Core13AndExtended16BothCovered',true,'ArtifactHashesChecked',local.LocalAudit.ArtifactHashesChecked,...
 'SourceEvidenceTriplesChecked',360,'RemovedSourceResumePassed',true,'TamperRejected',true);
end

function write_import_fixture(out,t,sourceSHA,extended)
d=fullfile(out,'runs',t.ID);mkdir(d);
core={'result.json','precision_ledger.csv','final_objectives.csv','final_decisions.csv',...
 'model_selection.csv','prediction_errors.csv','training_ids.csv','stage_flags.csv','fit_times.csv',...
 'final_training_archive.csv','final_surrogate_population_NOT_TRUE.csv','configuration.json','diagnostic_result.mat'};
for j=1:numel(core)
 if ismember(core{j},{'result.json','configuration.json'}),continue;end
 fid=fopen(fullfile(d,core{j}),'w');assert(fid>=0);
 fprintf(fid,'SYNTHETIC_REUSE_FIXTURE_ONLY %s %s\n',t.ID,core{j});fclose(fid);
end
oldID=sprintf('V2_%s_D%d_seed%02d',t.Problem,t.D,t.Seed);
st=t;st.ID=oldID;
o=struct('N',100,'MaxFE',500,'Pmax',20,'K',10,'Seed',t.Seed,...
 'Mode','adaptive','RBFKernel','multiquadric','ReferencePoints',2000);
sc=struct('Task',st,'Options',o);
sr=struct('ID',oldID,'Version','V2','Problem',t.Problem,'D',t.D,'Seed',t.Seed,...
 'status','completed','FE',500,'N',100,'Pmax',20,'K',10,'RequestedPF',10000,'Scale',1,...
 'FeasibleND',1,'NonfiniteIGD',false,'IGD10000',0.5,'IGD2000',0.51,...
 'HVr1p1',0.1,'HVr3',0.2,'HVr20',0.3);
abl2050_io('writejson',fullfile(d,'source_result.json'),sr);
abl2050_io('writejson',fullfile(d,'source_configuration.json'),sc);
files=repmat(struct('Path','','SHA256',''),13,1);
for j=1:numel(core)
 proof=core{j};
 if strcmp(proof,'result.json'),proof='source_result.json';
 elseif strcmp(proof,'configuration.json'),proof='source_configuration.json';end
 files(j)=struct('Path',core{j},'SHA256',abl2050_io('sha',fullfile(d,proof)));
end
sm=struct('ID',oldID,'Version','V2','Problem',t.Problem,'D',t.D,'Seed',t.Seed,...
 'Status','completed','FE',500,'Files',files);
abl2050_io('writejson',fullfile(d,'source_completed.json'),sm);
originalSHA=abl2050_io('sha',fullfile(d,'source_completed.json'));
r=sr;r.ID=t.ID;r.Mode='adaptive';r.Source='imported_identical_V2_main_campaign';r.Origin='imported';
r.SourceCompletedSHA256=originalSHA;r.SourcePackageLockSHA256=sourceSHA;
abl2050_io('writejson',fullfile(d,'result.json'),r);
conf=sc;conf.Task=t;abl2050_io('writejson',fullfile(d,'configuration.json'),conf);
names=core;if extended,names=[names,{'source_completed.json','source_result.json','source_configuration.json'}];end
files=repmat(struct('Path','','SHA256',''),numel(names),1);
for j=1:numel(names),files(j)=struct('Path',names{j},'SHA256',abl2050_io('sha',fullfile(d,names{j})));end
m=sm;m.ID=t.ID;m.Mode='adaptive';m.Origin='imported';m.SourceCompletedSHA256=originalSHA;m.Files=files;
abl2050_io('writejson',fullfile(d,'completed.json'),m);
end
function x=unexpected_selector()
x=0; %#ok<NASGU>
error('Ablation_D20D50:FixtureUnexpectedSelector','A saved valid choice must not invoke the folder selector.');
end
function clean_scratch(p)
base=char(java.io.File(tempdir).getCanonicalPath());target=char(java.io.File(p).getCanonicalPath());
assert(startsWith(lower(target),lower([base,filesep]))&&~strcmpi(target,base),'Unsafe fixture cleanup path.');
if isfolder(target),rmdir(target,'s');end
end
