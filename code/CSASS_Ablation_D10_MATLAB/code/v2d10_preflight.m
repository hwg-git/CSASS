function protocol=v2d10_preflight(root)
% Read-only frozen source, 30-group manifest, and 360-cache identity checks.
protocol=v2d10_io('json',fullfile(root,'protocol.json'));
names={'N','MaxFE','Pmax','K','Workers','ThreadsPerTrial','RequestedPF','Scale',...
    'NewTasks','CachedTasks','TotalTasks','ExpectedGroups','SeedFirst','SeedLast','EngineReferencePoints'};
values=[100,500,20,10,1,1,10000,1,540,360,900,30,1,30,2000];
for i=1:numel(names)
    assert(isfield(protocol,names{i}) && isequal(protocol.(names{i}),values(i)),...
        'V2_Ablation_D10:ProtocolChanged','Fixed protocol mismatch: %s',names{i});
end
problems={'CF2','CF7','LIRCMOP1','LIRCMOP7','CF8','LIRCMOP13'};
modes={'adaptive','rbf_only','kriging_only','fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'};
assert(isequal(double(protocol.Dimensions(:)'),10),'V2_Ablation_D10:Dimensions','Only D10 authorized.');
assert(isequal(sort(string(protocol.Problems(:))),sort(string(problems(:)))),...
    'V2_Ablation_D10:Problems','Six fixed ablation problems changed.');
assert(isequal(string(protocol.Modes(:)),string(modes(:))) && strcmp(protocol.RBFKernel,'multiquadric'),...
    'V2_Ablation_D10:Modes','Five modes or frozen MQ kernel changed.');
assert(~protocol.AutomaticRetry && ~protocol.StopByHistoricalIGD,...
    'V2_Ablation_D10:RetryPolicy','Automatic retries and metric-based stopping are prohibited.');
assert(isequal(double(protocol.HVReferences(:)'),[1.1,3,20]),'V2_Ablation_D10:HVProtocol','Primary HV references changed.');
assert(isfield(protocol,'MaxWallHours') && isscalar(protocol.MaxWallHours) &&...
    isfinite(protocol.MaxWallHours) && protocol.MaxWallHours>0 && protocol.MaxWallHours<=12,...
    'V2_Ablation_D10:WallProtocol','Session MaxWallHours must be in (0,12].');
assert(protocol.MinimumFreeMemoryGB==1 && protocol.MinimumFreeDiskGB==3,...
    'V2_Ablation_D10:ResourceGuard','The local resource guard is fixed to >1GB memory and >3GB free disk.');
expectedCache=cell(360,1);expectedCacheGroups=cell(12,1);n=0;ng=0;
for p=1:numel(problems)
    for m=1:numel(modes)
        cached=ismember(problems{p},{'CF7','LIRCMOP7'}) ||...
            (ismember(problems{p},{'CF2','LIRCMOP1'}) && strcmp(modes{m},'adaptive'));
        if ~cached,continue;end
        ng=ng+1;expectedCacheGroups{ng}=sprintf('V2_%s_D10_%s',problems{p},modes{m});
        for s=1:30,n=n+1;expectedCache{n}=sprintf('V2_%s_D10_%s_seed%02d',problems{p},modes{m},s);end
    end
end
assert(isfield(protocol,'CacheGroups') && numel(protocol.CacheGroups)==12,'V2_Ablation_D10:CacheGroups','Expected12 cached groups.');
actualCacheGroups=cell(12,1);
for i=1:12
    c=protocol.CacheGroups(i);assert(strcmp(c.Version,'V2') && c.D==10);
    actualCacheGroups{i}=sprintf('%s_%s_D%d_%s',c.Version,c.Problem,c.D,c.Mode);
end
assert(isequal(sort(actualCacheGroups),sort(expectedCacheGroups)),'V2_Ablation_D10:CacheScope','Predefined cache groups changed.');
lock=v2d10_io('json',fullfile(root,'source_lock.json'));
assert(isfield(lock,'Files') && ~isempty(lock.Files),'V2_Ablation_D10:MissingSourceLock','Empty source lock.');
paths=cell(numel(lock.Files),1);
for i=1:numel(lock.Files)
    f=lock.Files(i);rel=char(f.Path);paths{i}=strrep(rel,'\','/');
    assert(isempty(regexp(rel,'(^[\\/]|^[A-Za-z]:|(^|[\\/])\.\.([\\/]|$))','once')),...
        'V2_Ablation_D10:SourcePath','Source-lock paths must stay relative: %s',rel);
    file=fullfile(root,strrep(rel,'/',filesep));
    assert(isfile(file),'V2_Ablation_D10:MissingSource','Missing locked file: %s',rel);
    assert(strcmpi(v2d10_io('sha',file),char(f.SHA256)),'V2_Ablation_D10:ChangedSource','Changed package source: %s',rel);
end
assert(numel(unique(paths))==numel(paths),'V2_Ablation_D10:DuplicateLock','Duplicate source-lock paths.');
required={'MAIN_CSASS_V2_D10.m','protocol.json','code/v2d10_tasks.m',...
    'code/v2d10_inventory.m','code/v2d10_io.m','code/v2d10_preflight.m','code/v2d10_engine.m',...
    'code/v2d10_trial.m','code/v2d10_summarize.m','code/v2d10_collect.m','code/v2d10_import_main.m',...
    'code/v2d10_controller_fixture.m','code/v2d10_recompute_hv.m','README_中文.txt',...
    'baseline/completed_runs.csv','baseline/provenance.json'};
assert(all(ismember(required,paths)),'V2_Ablation_D10:IncompleteLock','Source lock omits required files.');
tasks=v2d10_tasks(root);assert(numel(tasks)==540 && numel(unique({tasks.ID}))==540);
assert(all(strcmp({tasks.Version},'V2')) && all(ismember({tasks.Mode},modes)),...
    'V2_Ablation_D10:TaskVersion','Only the five frozen V2 modes permitted.');
assert(all([tasks.D]==10) && all([tasks.N]==100) && all([tasks.MaxFE]==500) &&...
    all([tasks.Pmax]==20) && all([tasks.K]==10),'V2_Ablation_D10:TaskBudget','Fixed task parameters changed.');
B=readtable(fullfile(root,'baseline','completed_runs.csv'),'TextType','string','VariableNamingRule','preserve');
assert(height(B)==360 && numel(unique(B.ID))==360 && all(B.Version=="V2") && all(B.D==10) &&...
    all(B.FE==500) && all(B.Status=="completed"),'V2_Ablation_D10:CacheContents','Cache must contain360 unique completed V2 FE500 trials.');
assert(isequal(sort(B.ID),sort(string(expectedCache))),'V2_Ablation_D10:CacheIDs','Cached IDs/seeds changed.');
for i=1:height(B)
    assert(B.ID(i)==string(sprintf('V2_%s_D%d_%s_seed%02d',B.Problem(i),B.D(i),B.Mode(i),B.Seed(i))),...
        'V2_Ablation_D10:CacheFields','Cache identity/mode fields mismatch.');
end
assert(isempty(intersect(string({tasks.ID}),B.ID)),'V2_Ablation_D10:CacheDispatch','Cached trials must not be dispatched.');
allIDs=[string({tasks.ID})';B.ID];assert(numel(unique(allIDs))==900);
for p=1:numel(problems)
    for d=10
        for m=1:numel(modes)
            expected=string(arrayfun(@(s)sprintf('V2_%s_D%d_%s_seed%02d',problems{p},d,modes{m},s),1:30,'UniformOutput',false));
            assert(all(ismember(expected,allIDs)),'V2_Ablation_D10:TaskManifest','Missing fixed group/seeds: %s D%d %s',problems{p},d,modes{m});
        end
    end
end
for f={'v2d10_trial','v2d10_engine','v2d10_summarize','v2d10_collect','v2d10_recompute_hv','v2d10_import_main'}
    actual=which(f{1});wanted=fullfile(root,'code',[f{1},'.m']);
    assert(strcmpi(strrep(actual,'\','/'),strrep(wanted,'\','/')),...
        'V2_Ablation_D10:ShadowedFunction','Interface resolves outside this package: %s',f{1});
end
fprintf('PREFLIGHT PASS: fixed540 +360 cached IDs, 30 groups, frozen source SHA256/interfaces; no optimization.\n');
end