function protocol=abl2050_preflight(root)
% Read-only package/source verification, no optimization or pool startup.
protocol=abl2050_io('json',fullfile(root,'protocol.json'));
names={'N','MaxFE','Pmax','K','Workers','ThreadsPerTrial','RequestedPF','Scale',...
 'NewTasks','CachedTasks','TotalTasks','ExpectedGroups','SeedFirst','SeedLast','EngineReferencePoints'};
values=[100,500,20,10,6,1,10000,1,1800,0,1800,60,1,30,2000];
for i=1:numel(names)
 assert(isfield(protocol,names{i})&&isequal(protocol.(names{i}),values(i)),...
  'Ablation_D20D50:ProtocolChanged','Fixed protocol mismatch: %s',names{i});
end
problems={'CF2','CF7','LIRCMOP1','LIRCMOP7','CF8','LIRCMOP13'};
modes={'adaptive','rbf_only','kriging_only','fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'};
assert(isequal(double(protocol.Dimensions(:)'),[20,50]),'Only D20/D50 are included.');
assert(isequal(string(protocol.Problems(:)),string(problems(:))));
assert(isequal(string(protocol.Modes(:)),string(modes(:))));
assert(strcmp(protocol.RBFKernel,'multiquadric')&&isempty(protocol.CacheGroups));
assert(~protocol.AutomaticRetry&&~protocol.StopByHistoricalIGD);
assert(isequal(double(protocol.HVReferences(:)'),[1.1,3,20]));
assert(protocol.MaxWallHours==72&&protocol.MinFreeRAMGiB==2&&protocol.MinFreeDiskGiB==5&&protocol.ResourceWaitMinutes==30);
lock=abl2050_io('json',fullfile(root,'source_lock.json'));
assert(isfield(lock,'Files')&&~isempty(lock.Files));paths=cell(numel(lock.Files),1);
for i=1:numel(lock.Files)
 rel=char(lock.Files(i).Path);paths{i}=strrep(rel,'\','/');
 assert(isempty(regexp(rel,'(^[\\/]|^[A-Za-z]:|(^|[\\/])\.\.([\\/]|$))','once')));
 file=fullfile(root,strrep(rel,'/',filesep));assert(isfile(file),'Missing source: %s',rel);
 assert(strcmpi(abl2050_io('sha',file),lock.Files(i).SHA256),...
  'Ablation_D20D50:ChangedSource','Source differs from frozen package: %s',rel);
end
assert(numel(unique(lower(string(paths))))==numel(paths));
required={'MAIN_CSASS_ABLATION.m','protocol.json','README_中文.txt','audit/engine_audit.json',...
 'code/abl2050_tasks.m','code/abl2050_inventory.m','code/abl2050_preflight.m',...
 'code/abl2050_engine.m','code/abl2050_trial.m','code/abl2050_summarize.m',...
 'code/abl2050_collect.m','code/abl2050_import_main.m','code/abl2050_autoimport.m','code/abl2050_empty_runs.m',...
 'code/abl2050_ablation_statistics.m','code/abl2050_recompute_hv.m',...
 'baseline/original_paper_IGD.csv'};
assert(all(ismember(required,paths)),'Source lock omits required files.');
tasks=abl2050_tasks(root);assert(numel(tasks)==1800&&numel(unique({tasks.ID}))==1800);
assert(all(strcmp({tasks.Version},'V2'))&&all(ismember({tasks.Mode},modes)));
assert(all(ismember([tasks.D],[20,50]))&&all([tasks.N]==100)&&all([tasks.MaxFE]==500)&&all([tasks.Pmax]==20)&&all([tasks.K]==10));
for p=1:numel(problems)
 for d=[20,50]
  for m=1:numel(modes)
   k=strcmp({tasks.Problem},problems{p})&[tasks.D]==d&strcmp({tasks.Mode},modes{m});
   assert(sum(k)==30&&isequal(sort([tasks(k).Seed]),1:30));
  end
 end
end
for f={'abl2050_trial','abl2050_engine','abl2050_summarize','abl2050_collect','abl2050_recompute_hv','abl2050_import_main'}
 actual=which(f{1});wanted=fullfile(root,'code',[f{1},'.m']);
 assert(strcmpi(strrep(actual,'\','/'),strrep(wanted,'\','/')),...
  'Ablation_D20D50:ShadowedFunction','Function resolves outside this package: %s',f{1});
end
fprintf('PREFLIGHT PASS: fixed1800 IDs,60 groups,D20/D50,source hashes verified; no optimization.\n');
end
