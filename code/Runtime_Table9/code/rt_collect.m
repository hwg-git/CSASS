function zipPath = rt_collect(root,out)
% Package current source, environment, all retained runs and CSV summaries.
% No experiments are started, and no original result file is removed.
root=canonical(root);out=canonical(out);
report=rt_summarize(root,out);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));token=char(java.util.UUID.randomUUID());
tempRoot=fullfile(out,'temp');if ~isfolder(tempRoot),mkdir(tempRoot);end
stage=fullfile(tempRoot,['collect_' stamp '_' token]);mkdir(stage);
guard=onCleanup(@()remove_stage(stage,tempRoot));
packageName='CSASS_Runtime_Table9';package=fullfile(stage,packageName);
mkdir(package);mkdir(fullfile(package,'source'));mkdir(fullfile(package,'output'));
sourceFiles=list_files(root,'source',out);
outputFiles=list_files(out,'output','');
assert(any(strcmp(sourceFiles,'manifest.csv')),'rt:PackageManifest','Cannot package without manifest.csv.');
assert(any(strcmp(sourceFiles,'protocol.json')),'rt:PackageProtocol','Cannot package without protocol.json.');
copy_files(root,fullfile(package,'source'),sourceFiles);
copy_files(out,fullfile(package,'output'),outputFiles);
metadata=struct('PackageType','CSASS_Table9_runtime_source_and_all_retained_records',...
    'CreatedUTC',char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")),...
    'SourceRoot',root,'OutputRoot',out,'SourceFileCount',numel(sourceFiles),...
    'OutputFileCount',numel(outputFiles),'Summary',report,...
    'EnvironmentJSONPresent',isfile(fullfile(out,'environment.json')),...
    'EnvironmentMATPresent',isfile(fullfile(out,'environment.mat')),...
    'OriginalDataModified',false,'CSVAuthoritative',true,...
    'Exclusions','Locks, temporary directories/files, existing archives and nested output directories in source are excluded.',...
    'ChecksumScope','SHA256 for every packaged file except hash_manifest.csv itself.');
write_utf8(fullfile(package,'package_metadata.json'),jsonencode(metadata));
files=list_files(package,'checksum','');
paths=cell(numel(files),1);bytes=zeros(numel(files),1);hashes=cell(numel(files),1);
for i=1:numel(files)
    paths{i}=strrep(files{i},filesep,'/');f=fullfile(package,files{i});info=dir(f);
    bytes(i)=info.bytes;hashes{i}=file_sha256(f);
end
H=table(string(paths),bytes,string(hashes),'VariableNames',{'Path','Bytes','SHA256'});
writetable(H,fullfile(package,'hash_manifest.csv'));
zipPath=fullfile(fileparts(out),['CSASS_Table9_Runtime_RESULTS_' stamp '_' token '.zip']);
assert(~isfile(zipPath),'rt:PackageCollision','Refusing to overwrite an existing package.');
zip(zipPath,{packageName},stage);
assert(isfile(zipPath),'rt:PackageMissing','ZIP creation did not produce the expected file.');
fprintf('Runtime data package saved to:\n%s\n',zipPath);
end

function files=list_files(base,mode,excludeRoot)
files=walk(base,'',mode,excludeRoot);
files=sort(files);
end

function files=walk(base,relative,mode,excludeRoot)
files={};folder=fullfile(base,relative);items=dir(folder);
for i=1:numel(items)
    e=items(i);name=e.name;
    if strcmp(name,'.')||strcmp(name,'..'),continue;end
    rel=fullfile(relative,name);full=fullfile(base,rel);low=lower(name);
    if e.isdir
        if any(strcmp(low,{'locks','lock','temp','tmp','.git','__pycache__'})) || endsWith(low,'.lock'),continue;end
        if strcmp(mode,'source') && any(strcmp(low,{'outputs','output','runs','tables'})),continue;end
        if ~isempty(excludeRoot) && path_within(full,excludeRoot),continue;end
        files=[files;walk(base,rel,mode,excludeRoot)]; %#ok<AGROW>
    else
        [~,~,ext]=fileparts(low);
        if any(strcmp(ext,{'.zip','.rar','.7z','.gz','.tar','.lock','.tmp','.part'})),continue;end
        if contains(low,'.tmp_')||startsWith(low,'~$'),continue;end
        files{end+1,1}=rel; %#ok<AGROW>
    end
end
end

function copy_files(from,to,files)
for i=1:numel(files)
    dest=fullfile(to,files{i});parent=fileparts(dest);
    if ~isfolder(parent),mkdir(parent);end
    [ok,msg]=copyfile(fullfile(from,files{i}),dest);
    assert(ok,'rt:PackageCopy','Cannot copy %s: %s',files{i},msg);
end
end

function h=file_sha256(path)
md=java.security.MessageDigest.getInstance('SHA-256');
fid=fopen(path,'rb');assert(fid>=0,'rt:HashRead','Cannot read %s',path);
guard=onCleanup(@()fclose(fid));
while true
    block=fread(fid,1048576,'*uint8');if isempty(block),break;end
    md.update(typecast(block(:),'int8'));
end
digest=typecast(md.digest(),'uint8');h=lower(reshape(dec2hex(digest,2).',1,[]));
end

function write_utf8(path,text)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0,'rt:PackageWrite','Cannot write %s',path);
guard=onCleanup(@()fclose(fid));
fwrite(fid,unicode2native(text,'UTF-8'),'uint8');
end

function p=canonical(p)
p=char(java.io.File(char(p)).getCanonicalPath());
end

function yes=path_within(candidate,parent)
c=canonical(candidate);p=canonical(parent);
yes=strcmpi(c,p)||startsWith(lower(c),[lower(p) filesep]);
end

function remove_stage(stage,tempRoot)
% Verify the resolved directory before deleting only this disposable copy.
s=canonical(stage);t=canonical(tempRoot);
assert(~strcmpi(s,t)&&path_within(s,t),'rt:CleanupScope','Unsafe staging cleanup path.');
[~,name]=fileparts(s);assert(startsWith(name,'collect_'),'rt:CleanupName','Unexpected staging directory name.');
if isfolder(s)
    [ok,msg]=rmdir(s,'s');
    if ~ok,warning('rt:Cleanup','Could not remove disposable staging copy: %s',msg);end
end
end
