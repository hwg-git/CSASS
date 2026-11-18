function portable_preflight(root,c)
for folder={'runs','references','tables','locks'},p=fullfile(c.Output,folder{1});if ~isfolder(p),mkdir(p);end;end
bootstrap=fullfile(c.Output,'locks','bootstrap');claim=java.io.File(bootstrap);timer=tic;
while ~claim.mkdir(),assert(toc(timer)<60,'Another preflight is active; preserve the lock and stop the other controller first.');pause(.1);end
release=onCleanup(@()rmdir(bootstrap)); %#ok<NASGU>
portable_setup(root,'CSASS');source=portable_read_json(fullfile(root,'source_manifest.json'));
for i=1:numel(source.Files)
 f=source.Files(i);assert(strcmp(portable_sha(fullfile(root,f.Path)),f.SHA256),'Source checksum mismatch: %s',f.Path);
end
manifestFile=fullfile(c.Output,'experiment_manifest.json');tasks=portable_tasks(c);
if isfile(manifestFile)
 old=portable_read_json(manifestFile);assert(strcmp(old.ScientificFingerprint,source.ScientificFingerprint)&&strcmp(old.PopulationPolicy,c.PopulationPolicy),'Different source/protocol: use a separate output folder.');
else
 portable_write_json(manifestFile,struct('ScientificFingerprint',source.ScientificFingerprint,'SelectedCSASSFingerprint',source.SelectedCSASSFingerprint,'PopulationPolicy',c.PopulationPolicy,'N',100,'MaxFE',500,'Pmax',20,'K',10,'Seeds',c.Seeds,'Dimensions',c.Dimensions,'Problems',{c.Problems},'Algorithms',{c.Algorithms},'TaskCount',numel(tasks),'References','Pinned public GetOptimum(2000);exact arrays exported','PrimaryHV','PF-bound normalized exactHV;reference1.1 each objective','ExtraHVReferences',[1.5,2],'Summary','All30 primary IGD includes Inf;conditional finite summaries separate','CSASSVariant','Selected ObjectiveArchive30 candidate;reconstructed new experiments,not recovered historical data'));
end
if ~all(strcmp(c.Algorithms,'CSASS')),assert(~isempty(ver('stats'))&&license('test','Statistics_Toolbox'),'Statistics and Machine Learning Toolbox required.');end
if any(ismember(c.Algorithms,{'HeEMOEA','PCSAEA'})),assert(~isempty(ver('nnet'))&&license('test','Neural_Network_Toolbox'),'Deep Learning Toolbox required by comparison algorithms.');end
assert(abs(csass.hypervolume([0,1;1,0],[1.1,1.1])-.21)<1e-12,'2D HV fixture failed.');
assert(abs(csass.hypervolume([0,1,1;1,0,1;1,1,0],[1.1,1.1,1.1])-.031)<1e-12,'3D HV fixture failed.');
[~,n2]=UniformPoint(100,2);[~,n3]=UniformPoint(100,3);assert(n2==100&&n3==91,'Unexpected reference-direction implementation.');
referenceInfo=repmat(struct('Problem','','M',0,'ActualReferenceCount',0,'SHA256',''),numel(c.Problems),1);
for i=1:numel(c.Problems)
 name=c.Problems{i};b=PortableLedgerProblem(name,c.Dimensions(1),100,500);R=b.Base.GetOptimum(c.ReferencePoints);
 assert(ismember(b.M,[2,3])&&size(R,2)==b.M&&all(isfinite(R),'all')&&all(max(R,[],1)>min(R,[],1)));
 for d=c.Dimensions
  z=feval(name,'D',d,'N',100,'maxFE',500);assert(z.D==d&&z.M==b.M&&numel(z.lower)==d&&numel(z.upper)==d);
  assert(isequal(R,z.GetOptimum(c.ReferencePoints)),'Reference PF depends on D;add dimension-specific files before running.');
 end
 file=fullfile(c.Output,'references',[name,'.csv']);
 if isfile(file),assert(isequal(R,readmatrix(file,'NumHeaderLines',1)),'Reference front changed.');
 else,portable_write_csv(file,cellstr(compose('f%d',1:b.M)),R);end
 referenceInfo(i)=struct('Problem',name,'M',b.M,'ActualReferenceCount',size(R,1),'SHA256',portable_sha(file));
end
deps=struct('MATLAB',version,'Toolboxes',ver,'ParallelLicense',license('test','Distrib_Computing_Toolbox'),'StatisticsLicense',license('test','Statistics_Toolbox'),'DeepLearningLicense',license('test','Neural_Network_Toolbox'),'ThreadsPerWorker',1,'RequestedWorkers',6,'ReferenceInfo',referenceInfo);
portable_write_json(fullfile(c.Output,sprintf('environment_shard%d.json',c.ShardIndex)),deps);
taskFile=fullfile(c.Output,'planned_tasks.csv');if ~isfile(taskFile),writetable(struct2table(tasks),taskFile);end
fprintf('PREFLIGHT passed: %d problems,%d tasks;2/3-objective metrics;selected CSASS source fixed.\n',numel(c.Problems),numel(tasks));
end
