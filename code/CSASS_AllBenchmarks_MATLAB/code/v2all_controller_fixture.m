function report=v2all_controller_fixture()
% Temporary IO/manifest fixture only; no benchmark/models/optimization/pool.
root=tempname;mkdir(root);guard=onCleanup(@()remove_fixture(root)); %#ok<NASGU>
tasks=v2all_tasks(root);assert(numel(tasks)==1950);
assert(strcmp(tasks(1).ID,'V2_CF1_D10_seed01'));
assert(strcmp(tasks(end).ID,'V2_LIRCMOP14_D50_seed30'));
assert(all(strcmp({tasks.Version},'V2')));
assert(sum([tasks.D]==10)==510 && sum([tasks.D]==20)==720 && sum([tasks.D]==50)==720);
cacheProblems={'CF2','CF7','LIRCMOP1','LIRCMOP2','LIRCMOP3','LIRCMOP4','LIRCMOP7'};
for p=cacheProblems
    assert(~any(strcmp({tasks.Problem},p{1}) & [tasks.D]==10));
end
cached=fullfile(root,'baseline','V2_LIRCMOP1_D10_seed01');mkdir(cached);
v2all_io('writejson',fullfile(cached,'completed.json'),struct('ID','V2_LIRCMOP1_D10_seed01'));
a=v2all_inventory(root,tasks);assert(a.Pending==1950 && a.Completed==0 && a.Retained==0);
d=fullfile(root,'outputs','V2_AllBenchmarks','runs',tasks(1).ID);mkdir(d);
m=tasks(1);m.Status='completed';m.FE=500;
v2all_io('writejson',fullfile(d,'completed.json'),m);
d2=fullfile(root,'outputs','V2_AllBenchmarks','runs',tasks(2).ID);mkdir(d2);
v2all_io('writejson',fullfile(d2,'started.json'),struct('ID',tasks(2).ID));
d3=fullfile(root,'outputs','V2_AllBenchmarks','runs',tasks(3).ID);mkdir(d3);
v2all_io('writejson',fullfile(d3,'failure.json'),struct('ID',tasks(3).ID));
a=v2all_inventory(root,tasks);assert(a.Pending==1947 && a.Completed==1 && a.Retained==2);
assert(~a.PendingMask(1) && ~a.PendingMask(2) && ~a.PendingMask(3));
bad=m;bad.FE=499;v2all_io('writejson',fullfile(d,'completed.json'),bad);
rejected=false;
try,v2all_inventory(root,tasks);catch e,rejected=strcmp(e.identifier,'V2_AllBenchmarks:MarkerStatus');end
assert(rejected,'Incorrect completion-marker FE not rejected.');
v2all_io('writejson',fullfile(d,'completed.json'),m);
bad=m;bad.Seed=30;v2all_io('writejson',fullfile(d,'completed.json'),bad);
rejected=false;
try,v2all_inventory(root,tasks);catch e,rejected=strcmp(e.identifier,'V2_AllBenchmarks:MarkerTask');end
assert(rejected,'Incorrect completion-marker seed not rejected.');
v2all_io('writejson',fullfile(d,'completed.json'),m);
p=fullfile(root,'atomic.json');v2all_io('writejson',p,struct('Value',1));
v2all_io('writejson',p,struct('Value',2));j=v2all_io('json',p);assert(j.Value==2);
assert(numel(v2all_io('sha',p))==64);
report=struct('Status','pass','NewTasks',1950,'CachedTasks',210,'TotalTasks',2160,...
    'OptimizationRuns',0,'RealEvaluations',0,'ModelFits',0,'PoolStarted',false,'FixtureDirectoriesOnly',true);
fprintf('CONTROLLER FIXTURE PASS: manifest/cache/retention; no optimization/evaluations/models/pool.\n');
end
function remove_fixture(root)
try
    p=char(java.io.File(root).getCanonicalPath());t=char(java.io.File(tempdir).getCanonicalPath());
    assert(startsWith(lower([p,filesep]),lower([t,filesep])) && ~strcmpi(p,t));
    if isfolder(p),rmdir(p,'s');end
catch
end
end