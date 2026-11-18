function report=v2d10_controller_fixture()
% Temporary manifest/IO fixture only; no scientific engine/models/pool.
root=tempname;mkdir(root);guard=onCleanup(@()remove_fixture(root)); %#ok<NASGU>
tasks=v2d10_tasks(root);assert(numel(tasks)==540);
assert(strcmp(tasks(1).ID,'V2_CF2_D10_rbf_only_seed01'));
assert(strcmp(tasks(end).ID,'V2_LIRCMOP13_D10_fixed_kriging_obj_rbf_con_seed30'));
assert(all([tasks.D]==10) && numel(tasks)==540);
modes={'adaptive','rbf_only','kriging_only','fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'};
assert(all(strcmp({tasks.Version},'V2')) && all(ismember({tasks.Mode},modes)));
assert(sum(strcmp({tasks.Mode},'adaptive'))==60);
for mode=modes(2:end),assert(sum(strcmp({tasks.Mode},mode{1}))==120);end
assert(~any(ismember({tasks.Problem},{'CF7','LIRCMOP7'}) & [tasks.D]==10));
assert(~any(ismember({tasks.Problem},{'CF2','LIRCMOP1'}) & [tasks.D]==10 & strcmp({tasks.Mode},'adaptive')));
a=v2d10_inventory(root,tasks);assert(a.Pending==540 && a.Completed==0 && a.Retained==0);
d=fullfile(root,'outputs','V2_Ablation_D10','runs',tasks(1).ID);mkdir(d);
artifactNames={'result.json','precision_ledger.csv','final_objectives.csv','final_decisions.csv',...
    'model_selection.csv','prediction_errors.csv','training_ids.csv','stage_flags.csv','fit_times.csv',...
    'final_training_archive.csv','final_surrogate_population_NOT_TRUE.csv','configuration.json','diagnostic_result.mat'};
files=repmat(struct('Path','','SHA256',''),13,1);
for k=1:13
    path=fullfile(d,artifactNames{k});fid=fopen(path,'w');assert(fid>=0);
    fprintf(fid,'SYNTHETIC_CONTROLLER_FIXTURE_ONLY\n');fclose(fid);
    files(k).Path=artifactNames{k};files(k).SHA256=v2d10_io('sha',path);
end
m=tasks(1);m.Status='completed';m.FE=500;m.Files=files;
v2d10_io('writejson',fullfile(d,'completed.json'),m);
d2=fullfile(root,'outputs','V2_Ablation_D10','runs',tasks(2).ID);mkdir(d2);
v2d10_io('writejson',fullfile(d2,'started.json'),struct('ID',tasks(2).ID));
d3=fullfile(root,'outputs','V2_Ablation_D10','runs',tasks(3).ID);mkdir(d3);
v2d10_io('writejson',fullfile(d3,'failure.json'),struct('ID',tasks(3).ID));
a=v2d10_inventory(root,tasks);assert(a.Pending==537 && a.Completed==1 && a.Retained==2 && a.ComputedCompleted==1);
assert(~a.PendingMask(1) && ~a.PendingMask(2) && ~a.PendingMask(3));
bad=m;bad.FE=499;v2d10_io('writejson',fullfile(d,'completed.json'),bad);
assert_rejected(root,tasks,'V2_Ablation_D10:MarkerStatus');
bad=m;bad.Mode='adaptive';v2d10_io('writejson',fullfile(d,'completed.json'),bad);
assert_rejected(root,tasks,'V2_Ablation_D10:MarkerTask');
bad=m;bad.Files=bad.Files(1:12);v2d10_io('writejson',fullfile(d,'completed.json'),bad);
assert_rejected(root,tasks,'V2_Ablation_D10:Artifacts');
% Only eligible adaptive imported records satisfy the marker contract.
bad=m;bad.Origin='imported';v2d10_io('writejson',fullfile(d,'completed.json'),bad);
assert_rejected(root,tasks,'V2_Ablation_D10:ImportMode');
v2d10_io('writejson',fullfile(d,'completed.json'),m);
idx=find(strcmp({tasks.Mode},'adaptive'),1);im=tasks(idx);
im.Status='completed';im.FE=500;im.Files=files;im.Origin='imported';
importDir=fullfile(root,'outputs','V2_Ablation_D10','runs',im.ID);mkdir(importDir);
for k=1:13,copyfile(fullfile(d,artifactNames{k}),fullfile(importDir,artifactNames{k}));end
v2d10_io('writejson',fullfile(importDir,'completed.json'),im);
a=v2d10_inventory(root,tasks);assert(a.ImportedCompleted==1 && a.ComputedCompleted==1 && a.Pending==536);
% Imports may preserve exactly three hashed original-source evidence files.
sourceFiles={'source_completed.json','source_result.json','source_configuration.json'};
for k=1:3
    sourcePath=fullfile(importDir,sourceFiles{k});
    v2d10_io('writejson',sourcePath,struct('SyntheticFixture',true,'SourceFile',sourceFiles{k}));
    im.Files(13+k)=struct('Path',sourceFiles{k},'SHA256',v2d10_io('sha',sourcePath));
end
v2d10_io('writejson',fullfile(importDir,'completed.json'),im);
a=v2d10_inventory(root,tasks);assert(a.ImportedCompleted==1 && a.Completed==2);
bad=im;bad.Files(16).Path='unexpected_evidence.json';
v2d10_io('writejson',fullfile(importDir,'completed.json'),bad);
assert_rejected(root,tasks,'V2_Ablation_D10:Artifacts');
v2d10_io('writejson',fullfile(importDir,'completed.json'),im);
p=fullfile(root,'atomic.json');v2d10_io('writejson',p,struct('Value',1));
v2d10_io('writejson',p,struct('Value',2));j=v2d10_io('json',p);assert(j.Value==2);
assert(numel(v2d10_io('sha',p))==64);
report=struct('Status','pass','NewTasks',540,'CachedTasks',360,'TotalTasks',900,...
    'OptimizationRuns',0,'RealEvaluations',0,'ModelFits',0,'PoolStarted',false,'FixtureDirectoriesOnly',true);
fprintf('CONTROLLER FIXTURE PASS:30 groups, cached exclusions, mode/FE/13-core/16-import guards; no optimization.\n');
end
function assert_rejected(root,tasks,expected)
rejected=false;
try,v2d10_inventory(root,tasks);catch e,rejected=strcmp(e.identifier,expected);end
assert(rejected,'Invalid marker was not rejected by %s.',expected);
end
function remove_fixture(root)
try
    p=char(java.io.File(root).getCanonicalPath());t=char(java.io.File(tempdir).getCanonicalPath());
    assert(startsWith(lower([p,filesep]),lower([t,filesep])) && ~strcmpi(p,t));
    if isfolder(p),rmdir(p,'s');end
catch
end
end
