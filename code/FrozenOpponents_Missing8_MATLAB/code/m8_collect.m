function zipPath=m8_collect(root)
% Preserve all existing completed/failed/partial records plus frozen sources.
% No experiment execution; snapshots never overwrite source or prior returns.
root=char(java.io.File(root).getCanonicalPath());
out=fullfile(root,'outputs','Missing8_Opponents');assert(isfolder(out),'No output directory exists yet.');
returns=fullfile(root,'returns');if ~isfolder(returns),mkdir(returns);end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));uid=char(java.util.UUID.randomUUID());
name=['CSASS_MISSING8_RESULTS_' stamp '_' uid(1:8)];stage=fullfile(returns,name);assert(~isfolder(stage));mkdir(stage);
records=cell(0,5);copyErrors=cell(0,3);
% Explicit top-level allowlist excludes old results, previous returns, and temp.
folders={'code','references','vendor','protocol_algorithms','scientific_baseline','audit'};
for i=1:numel(folders),copyTree(fullfile(root,folders{i}),folders{i});end
files=dir(root);files=files(~[files.isdir]);
for i=1:numel(files)
 [~,~,ext]=fileparts(files(i).name);
 if ismember(lower(ext),{'.m','.json','.csv','.txt','.md'}),copyOne(fullfile(root,files(i).name),files(i).name);end
end
copyTree(out,fullfile('outputs','Missing8_Opponents'));
writetable(cell2table(records,'VariableNames',{'ArchiveMember','Source','Bytes','SHA256','ByteExactCopy'}),fullfile(stage,'return_manifest.csv'));
writetable(cell2table(copyErrors,'VariableNames',{'Source','ArchiveMember','Error'}),fullfile(stage,'copy_errors.csv'));
receipt=struct('Collector','m8_collect','OriginalFilesModified',false,'FilesCopied',size(records,1),'CopyErrors',size(copyErrors,1), ...
 'OptimizationRunsByCollector',0,'TrueEvaluationsByCollector',0,'CompletedFailedAndPartialRecordsIncluded',true, ...
 'Scope','8 problems x 3 dimensions x 5 opponents x 30 fixed seeds =3600 tasks; no CSASS trials.', ...
 'Note','If collection was requested while running, file hash/race issues are retained in copy_errors.csv; audit the returned completed markers before use.');
fid=fopen(fullfile(stage,'return_receipt.json'),'w','n','UTF-8');assert(fid>=0);guard=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(receipt,'PrettyPrint',true));clear guard;
zipPath=fullfile(returns,[name '.zip']);assert(~isfile(zipPath));zip(zipPath,{name},returns);
fprintf('Saved existing-run return: %s\n',zipPath);
if ~isempty(copyErrors),fprintf(2,'Collection has %d copy issues; see copy_errors.csv. Original files were preserved.\n',size(copyErrors,1));end

 function copyTree(folder,prefix)
  if ~isfolder(folder),return;end
  list=dir(fullfile(folder,'**','*'));list=list(~[list.isdir]);
  for k=1:numel(list),source=fullfile(list(k).folder,list(k).name);relative=source(numel(folder)+2:end);copyOne(source,fullfile(prefix,relative));end
 end
 function copyOne(source,member)
  try
   target=fullfile(stage,member);assert(~isfile(target),'Duplicate archive member.');parent=fileparts(target);if ~isfolder(parent),mkdir(parent);end
   before=sha(source);info=dir(source);[ok,msg]=copyfile(source,target);assert(ok,msg);
   assert(strcmp(before,sha(target))&&strcmp(before,sha(source)),'Source changed during collection or copy hash mismatch.');
   records(end+1,:)={strrep(member,'\','/'),source,info.bytes,before,true};
  catch err,copyErrors(end+1,:)={source,strrep(member,'\','/'),err.message};end
 end
end
function h=sha(file)
fid=fopen(file,'rb');assert(fid>=0);guard=onCleanup(@()fclose(fid));md=java.security.MessageDigest.getInstance('SHA-256');
while true,b=fread(fid,1048576,'*uint8');if isempty(b),break;end;md.update(b);end
h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
