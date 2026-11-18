function protocol=v2all_preflight(root)
% Read-only fixed protocol, source lock, cache identities, and interface audit.
protocol=v2all_io('json',fullfile(root,'protocol.json'));
names={'N','MaxFE','Pmax','K','Workers','ThreadsPerTrial','RequestedPF','Scale',...
    'NewTasks','CachedTasks','TotalTasks','ExpectedGroups','SeedFirst','SeedLast'};
values=[100,500,20,10,6,1,10000,1,1950,210,2160,72,1,30];
for i=1:numel(names)
    assert(isfield(protocol,names{i}) && isequal(protocol.(names{i}),values(i)),...
        'V2_AllBenchmarks:ProtocolChanged','Fixed protocol mismatch: %s',names{i});
end
problems=[arrayfun(@(x)sprintf('CF%d',x),1:10,'UniformOutput',false),...
    arrayfun(@(x)sprintf('LIRCMOP%d',x),1:14,'UniformOutput',false)];
cached={'CF2','CF7','LIRCMOP1','LIRCMOP2','LIRCMOP3','LIRCMOP4','LIRCMOP7'};
assert(isequal(double(protocol.Dimensions(:)'),[10,20,50]),'V2_AllBenchmarks:Dimensions','Only D10/20/50 are authorized.');
assert(isequal(sort(string(protocol.Problems(:))),sort(string(problems(:)))),...
    'V2_AllBenchmarks:Problems','The fixed24 problems must match CF1-CF10 and LIRCMOP1-LIRCMOP14.');
assert(strcmp(protocol.Mode,'adaptive') && strcmp(protocol.RBFKernel,'multiquadric'),...
    'V2_AllBenchmarks:ScienceSettings','Frozen V2 adaptive/MQ settings changed.');
assert(~protocol.AutomaticRetry && ~protocol.StopByHistoricalIGD,...
    'V2_AllBenchmarks:RetryPolicy','Automatic retries or metric-based stopping are not permitted.');
assert(isequal(double(protocol.HVReferences(:)'),[1.1,3,20]),'V2_AllBenchmarks:HVProtocol','Primary HV references changed.');
assert(isfield(protocol,'CacheGroups') && numel(protocol.CacheGroups)==7 &&...
    all(strcmp({protocol.CacheGroups.Version},'V2')) && all([protocol.CacheGroups.D]==10) &&...
    isequal(sort({protocol.CacheGroups.Problem}),sort(cached)),...
    'V2_AllBenchmarks:CacheScope','Expected the seven fixed completed V2 D10 cache groups.');
assert(isfield(protocol,'MaxWallHours') && isscalar(protocol.MaxWallHours) &&...
    isfinite(protocol.MaxWallHours) && protocol.MaxWallHours>0 && protocol.MaxWallHours<=72,...
    'V2_AllBenchmarks:WallProtocol','Session MaxWallHours must be in (0,72].');
lock=v2all_io('json',fullfile(root,'source_lock.json'));
assert(isfield(lock,'Files') && ~isempty(lock.Files),'V2_AllBenchmarks:MissingSourceLock','Empty source lock.');
paths=cell(numel(lock.Files),1);
for i=1:numel(lock.Files)
    f=lock.Files(i);rel=char(f.Path);paths{i}=strrep(rel,'\','/');
    assert(isempty(regexp(rel,'(^[\\/]|^[A-Za-z]:|(^|[\\/])\.\.([\\/]|$))','once')),...
        'V2_AllBenchmarks:SourcePath','Source-lock paths must stay relative: %s',rel);
    file=fullfile(root,strrep(rel,'/',filesep));
    assert(isfile(file),'V2_AllBenchmarks:MissingSource','Missing locked file: %s',rel);
    assert(strcmpi(v2all_io('sha',file),char(f.SHA256)),...
        'V2_AllBenchmarks:ChangedSource','Changed package source: %s',rel);
end
assert(numel(unique(paths))==numel(paths),'V2_AllBenchmarks:DuplicateLock','Duplicate source-lock paths.');
required={'MAIN_CSASS_V2_ALL.m','protocol.json','code/v2all_tasks.m',...
    'code/v2all_inventory.m','code/v2all_io.m','code/v2all_preflight.m',...
    'code/v2all_trial.m','code/v2all_summarize.m','code/v2all_collect.m',...
    'code/v2all_controller_fixture.m','code/v2all_recompute_hv.m','README_中文.txt',...
    'baseline/completed_runs.csv','baseline/provenance.json'};
assert(all(ismember(required,paths)),'V2_AllBenchmarks:IncompleteLock','Source lock omits required package files.');
tasks=v2all_tasks(root);assert(numel(tasks)==1950 && numel(unique({tasks.ID}))==1950);
assert(all(strcmp({tasks.Version},'V2')) && all(strcmp({tasks.Mode},'adaptive')),...
    'V2_AllBenchmarks:TaskVersion','Only frozen V2 adaptive tasks are permitted.');
assert(all(ismember([tasks.D],[10,20,50])) && all([tasks.N]==100) && all([tasks.MaxFE]==500) &&...
    all([tasks.Pmax]==20) && all([tasks.K]==10),'V2_AllBenchmarks:TaskBudget','Fixed task parameters changed.');
B=readtable(fullfile(root,'baseline','completed_runs.csv'),'TextType','string','VariableNamingRule','preserve');
assert(height(B)==210 && numel(unique(B.ID))==210 && all(B.Version=="V2") && all(B.D==10) &&...
    all(B.FE==500) && all(B.Status=="completed"),'V2_AllBenchmarks:CacheContents','Cache must contain210 unique completed V2 FE500 trials.');
expectedCache=cell(210,1);k=0;
for p=1:numel(cached)
    for s=1:30,k=k+1;expectedCache{k}=sprintf('V2_%s_D10_seed%02d',cached{p},s);end
end
assert(isequal(sort(B.ID),sort(string(expectedCache))),'V2_AllBenchmarks:CacheIDs','Cached IDs/seeds changed.');
assert(isempty(intersect(string({tasks.ID}),B.ID)),'V2_AllBenchmarks:CacheDispatch','Cached trials must never be dispatched.');
allIDs=[string({tasks.ID})';B.ID];assert(numel(unique(allIDs))==2160);
for p=1:numel(problems)
    for d=[10,20,50]
        expected=string(arrayfun(@(s)sprintf('V2_%s_D%d_seed%02d',problems{p},d,s),1:30,'UniformOutput',false));
        assert(all(ismember(expected,allIDs)),'V2_AllBenchmarks:TaskManifest','Missing fixed group/seeds: %s D%d',problems{p},d);
    end
end
for f={'v2all_trial','v2all_summarize','v2all_collect','v2all_recompute_hv'}
    actual=which(f{1});wanted=fullfile(root,'code',[f{1},'.m']);
    assert(strcmpi(strrep(actual,'\','/'),strrep(wanted,'\','/')),...
        'V2_AllBenchmarks:ShadowedFunction','Interface resolves outside this package: %s',f{1});
end
fprintf('PREFLIGHT PASS: fixed1950 new +210 cached IDs, source SHA256, 72 groups, interfaces; no optimization run.\n');
end