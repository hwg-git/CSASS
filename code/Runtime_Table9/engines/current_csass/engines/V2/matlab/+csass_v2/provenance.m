function info = provenance()
root=fileparts(fileparts(mfilename('fullpath')));
project=fileparts(root);
files=[dir(fullfile(root,'**','*.m'));dir(fullfile(project,'vendor','**','*.m'))];
entries=struct('file',{},'sha256',{});
for i=1:numel(files)
    path=fullfile(files(i).folder,files(i).name);
    fid=fopen(path,'rb'); assert(fid>=0); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    md=java.security.MessageDigest.getInstance('SHA-256'); md.update(bytes);
    digest=typecast(md.digest(),'uint8');
    entries(i).file=strrep(erase(path,[project,filesep]),filesep,'/');
    entries(i).sha256=lower(reshape(dec2hex(digest,2)',1,[]));
end
info=struct('createdUTC',char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd HH:mm:ss XXX')),'MATLAB',version, ...
    'architecture',computer,'BLAS',version('-blas'),'sourceFiles',entries);
vendorFile=fullfile(project,'vendor','PROVENANCE.json');
if isfile(vendorFile), info.benchmarkSource=jsondecode(fileread(vendorFile)); end
end
