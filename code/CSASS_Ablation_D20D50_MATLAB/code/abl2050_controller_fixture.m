function report=abl2050_controller_fixture()
% Temporary manifest/IO fixture only; no scientific engine/models/pool.
root=tempname;mkdir(root);guard=onCleanup(@()remove_fixture(root)); %#ok<NASGU>
tasks=abl2050_tasks(root);assert(numel(tasks)==1800);
assert(strcmp(tasks(1).ID,'V2_CF2_D20_adaptive_seed01'));
assert(strcmp(tasks(end).ID,'V2_LIRCMOP13_D50_fixed_kriging_obj_rbf_con_seed30'));
assert(sum([tasks.D]==20)==900 && sum([tasks.D]==50)==900 && numel(tasks)==1800);
modes={'adaptive','rbf_only','kriging_only','fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'};
assert(all(strcmp({tasks.Version},'V2')) && all(ismember({tasks.Mode},modes)));
assert(sum(strcmp({tasks.Mode},'adaptive'))==360);
for mode=modes(2:end),assert(sum(strcmp({tasks.Mode},mode{1}))==360);end
assert(~any([tasks.D]==10));
a=abl2050_inventory(root,tasks);assert(a.Pending==1800 && a.Completed==0 && a.Retained==0);
first=find(strcmp({tasks.Mode},'rbf_only'),1);
d=fullfile(root,'outputs','Ablation_D20D50','runs',tasks(first).ID);mkdir(d);
artifactNames={'result.json','precision_ledger.csv','final_objectives.csv','final_decisions.csv',...
    'model_selection.csv','prediction_errors.csv','training_ids.csv','stage_flags.csv','fit_times.csv',...
    'final_training_archive.csv','final_surrogate_population_NOT_TRUE.csv','configuration.json','diagnostic_result.mat'};
files=repmat(struct('Path','','SHA256',''),13,1);
for k=1:13
    path=fullfile(d,artifactNames{k});fid=fopen(path,'w');assert(fid>=0);
    fprintf(fid,'SYNTHETIC_CONTROLLER_FIXTURE_ONLY\n');fclose(fid);
    files(k).Path=artifactNames{k};files(k).SHA256=abl2050_io('sha',path);
end
m=tasks(first);m.Status='completed';m.FE=500;m.Files=files;
abl2050_io('writejson',fullfile(d,'completed.json'),m);
d2=fullfile(root,'outputs','Ablation_D20D50','runs',tasks(first+1).ID);mkdir(d2);
abl2050_io('writejson',fullfile(d2,'started.json'),struct('ID',tasks(first+1).ID));
d3=fullfile(root,'outputs','Ablation_D20D50','runs',tasks(first+2).ID);mkdir(d3);
abl2050_io('writejson',fullfile(d3,'failure.json'),struct('ID',tasks(first+2).ID));
a=abl2050_inventory(root,tasks);assert(a.Pending==1797 && a.Completed==1 && a.Retained==2 && a.ComputedCompleted==1);
assert(~a.PendingMask(first) && ~a.PendingMask(first+1) && ~a.PendingMask(first+2));
bad=m;bad.FE=499;abl2050_io('writejson',fullfile(d,'completed.json'),bad);
assert_rejected(root,tasks,'Ablation_D20D50:MarkerStatus');
bad=m;bad.Mode='adaptive';abl2050_io('writejson',fullfile(d,'completed.json'),bad);
assert_rejected(root,tasks,'Ablation_D20D50:MarkerTask');
bad=m;bad.Files=bad.Files(1:12);abl2050_io('writejson',fullfile(d,'completed.json'),bad);
assert_rejected(root,tasks,'Ablation_D20D50:Artifacts');
% Only eligible adaptive imported records satisfy the marker contract.
bad=m;bad.Origin='imported';abl2050_io('writejson',fullfile(d,'completed.json'),bad);
assert_rejected(root,tasks,'Ablation_D20D50:ImportMode');
abl2050_io('writejson',fullfile(d,'completed.json'),m);
idx=find(strcmp({tasks.Mode},'adaptive'),1);im=tasks(idx);
im.Status='completed';im.FE=500;im.Files=files;im.Origin='imported';
importDir=fullfile(root,'outputs','Ablation_D20D50','runs',im.ID);mkdir(importDir);
for k=1:13,copyfile(fullfile(d,artifactNames{k}),fullfile(importDir,artifactNames{k}));end
abl2050_io('writejson',fullfile(importDir,'completed.json'),im);
a=abl2050_inventory(root,tasks);assert(a.ImportedCompleted==1 && a.ComputedCompleted==1 && a.Pending==1796);
% Imports may preserve exactly three hashed original-source evidence files.
sourceFiles={'source_completed.json','source_result.json','source_configuration.json'};
for k=1:3
    sourcePath=fullfile(importDir,sourceFiles{k});
    abl2050_io('writejson',sourcePath,struct('SyntheticFixture',true,'SourceFile',sourceFiles{k}));
    im.Files(13+k)=struct('Path',sourceFiles{k},'SHA256',abl2050_io('sha',sourcePath));
end
abl2050_io('writejson',fullfile(importDir,'completed.json'),im);
a=abl2050_inventory(root,tasks);assert(a.ImportedCompleted==1 && a.Completed==2);
bad=im;bad.Files(16).Path='unexpected_evidence.json';
abl2050_io('writejson',fullfile(importDir,'completed.json'),bad);
assert_rejected(root,tasks,'Ablation_D20D50:Artifacts');
abl2050_io('writejson',fullfile(importDir,'completed.json'),im);
p=fullfile(root,'atomic.json');abl2050_io('writejson',p,struct('Value',1));
abl2050_io('writejson',p,struct('Value',2));j=abl2050_io('json',p);assert(j.Value==2);
assert(numel(abl2050_io('sha',p))==64);
report=struct('Status','pass','NewTasks',1800,'CachedTasks',0,'TotalTasks',1800,...
    'OptimizationRuns',0,'RealEvaluations',0,'ModelFits',0,'PoolStarted',false,'FixtureDirectoriesOnly',true);
fprintf('CONTROLLER FIXTURE PASS:60 groups, D20/50 only, no cached dispatch, mode/FE/13-core/16-import guards; no optimization.\n');
end
function assert_rejected(root,tasks,expected)
rejected=false;
try,abl2050_inventory(root,tasks);catch e,rejected=strcmp(e.identifier,expected);end
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
