function value=rt_sha256(file)
fid=fopen(file,'rb'); assert(fid>=0,'Missing file: %s',file);
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
md=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid), b=fread(fid,1048576,'*uint8'); if ~isempty(b), md.update(b); end; end
b=typecast(md.digest(),'uint8'); value=lower(reshape(dec2hex(b,2)',1,[]));
end
