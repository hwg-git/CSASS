function out=m8_io(action,varargin)
% JSON/CSV helpers and SHA256. Atomic JSON replacement avoids progress gaps.
out=[];
switch char(action)
    case 'json'
        out=jsondecode(fileread(varargin{1}));
    case 'sha'
        fid=fopen(varargin{1},'rb');assert(fid>=0,'Cannot read %s',varargin{1});
        guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
        md=java.security.MessageDigest.getInstance('SHA-256');
        while ~feof(fid),md.update(fread(fid,1048576,'*uint8'));end
        out=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
    case 'writejson'
        path=char(varargin{1});ensure_parent(path);
        temp=[path,'.tmp_',char(java.util.UUID.randomUUID)];
        fid=fopen(temp,'w','n','UTF-8');assert(fid>=0,'Cannot write %s',temp);
        try
            fprintf(fid,'%s',jsonencode(varargin{2},'PrettyPrint',true));fclose(fid);
        catch e
            fclose(fid);rethrow(e);
        end
        src=java.io.File(temp).toPath();dst=java.io.File(path).toPath();
        opts=javaArray('java.nio.file.CopyOption',2);
        opts(1)=java.nio.file.StandardCopyOption.ATOMIC_MOVE;
        opts(2)=java.nio.file.StandardCopyOption.REPLACE_EXISTING;
        % No delete-before-write fallback: a failed replacement retains old JSON.
        java.nio.file.Files.move(src,dst,opts);
    case 'csv'
        path=char(varargin{1});headers=varargin{2};a=varargin{3};ensure_parent(path);
        fid=fopen(path,'w','n','UTF-8');assert(fid>=0,'Cannot write %s',path);
        guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
        fprintf(fid,'%s\n',strjoin(headers,','));
        if ~isempty(a)
            assert(size(a,2)==numel(headers),'CSV header/data dimensions differ.');
            fmt=[repmat('%.17g,',1,size(a,2)-1),'%.17g\n'];fprintf(fid,fmt,a');
        end
    otherwise
        error('Missing8:IOAction','Unknown IO action: %s',action);
end
end
function ensure_parent(path)
p=fileparts(path);if ~isempty(p) && ~isfolder(p),mkdir(p);end
end
