function zipPath=v2d10_collect(root)
% Package saved results and frozen provenance only; no optimization is run.
out=fullfile(root,'outputs','V2_Ablation_D10');
if ~isfolder(out),mkdir(out);end
file=java.io.RandomAccessFile(fullfile(out,'coordinator.lock'),'rw');
try
    lock=file.getChannel().tryLock();
catch e
    file.close();error('V2_Ablation_D10:CollectBusy','Wait for the running controller before collecting: %s',e.message);
end
if isempty(lock)
    file.close();error('V2_Ablation_D10:CollectBusy','A controller is running; collect after it finishes or stops.');
end
guard=onCleanup(@()close_lock(lock,file)); %#ok<NASGU>
v2d10_summarize(root,true);
% Explicit roots exclude returns and all unrelated output activities.
folders={'outputs/V2_Ablation_D10','baseline','audit','code','engines','benchmarks','references'};
singles={'MAIN_CSASS_V2_D10.m','protocol.json','source_lock.json','README_中文.txt'};
rootFull=char(java.io.File(root).getCanonicalPath());prefix=[rootFull,filesep];
relativeFiles={};
for i=1:numel(folders)
    folder=fullfile(rootFull,strrep(folders{i},'/',filesep));
    assert(isfolder(folder),'V2_Ablation_D10:CollectMissing','Missing package folder: %s',folders{i});
    listing=dir(fullfile(folder,'**','*'));
    for j=1:numel(listing)
        if listing(j).isdir,continue;end
        name=listing(j).name;
        % Locks and interrupted atomic-write temporaries are not scientific data.
        if endsWith(name,'.lock') || contains(name,'.tmp_'),continue;end
        full=char(java.io.File(fullfile(listing(j).folder,name)).getCanonicalPath());
        assert(startsWith(lower(full),lower(prefix)),...
            'V2_Ablation_D10:CollectPath','A collected file resolves outside this package: %s',full);
        relativeFiles{end+1}=full(numel(prefix)+1:end); %#ok<AGROW>
    end
end
for i=1:numel(singles)
    assert(isfile(fullfile(rootFull,singles{i})),...
        'V2_Ablation_D10:CollectMissing','Missing package file: %s',singles{i});
    relativeFiles{end+1}=singles{i}; %#ok<AGROW>
end
relativeFiles=sort(unique(relativeFiles));
for i=1:numel(relativeFiles)
    rel=strrep(relativeFiles{i},'\','/');
    assert(~startsWith(rel,'returns/') && ~contains(rel,'../'),...
        'V2_Ablation_D10:CollectRecursion','Return archives must not include themselves.');
end
dest=fullfile(rootFull,'returns');if ~isfolder(dest),mkdir(dest);end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
token=char(java.util.UUID.randomUUID);
base=['CSASS_V2_D10_RESULTS_',stamp,'_',token(1:8)];
zipPath=fullfile(dest,[base,'.zip']);temporary=fullfile(dest,[base,'.partial.zip']);
assert(~isfile(zipPath) && ~isfile(temporary),'V2_Ablation_D10:CollectCollision','Archive filename already exists.');
zip(temporary,relativeFiles,rootFull);
z=java.util.zip.ZipFile(temporary);zGuard=onCleanup(@()z.close()); %#ok<NASGU>
assert(z.size()>=numel(relativeFiles),'V2_Ablation_D10:CollectZip','Archive entry count is incomplete.');
assert(~isempty(z.getEntry('protocol.json')) && ~isempty(z.getEntry('source_lock.json')),...
    'V2_Ablation_D10:CollectZip','Archive is missing the fixed protocol or source lock.');
clear zGuard;
[ok,msg]=movefile(temporary,zipPath);assert(ok,'V2_Ablation_D10:CollectMove','%s',msg);
fprintf('COLLECTION COMPLETE: %d saved files. No optimization was run.\n',numel(relativeFiles));
fprintf('Send this ZIP back for analysis:\n%s\n',zipPath);
end
function close_lock(lock,file)
try,if lock.isValid(),lock.release();end,catch, end
try,file.close();catch, end
end
