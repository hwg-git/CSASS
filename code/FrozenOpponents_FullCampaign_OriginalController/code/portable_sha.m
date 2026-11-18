function h=portable_sha(file)
f=fopen(file,'rb');assert(f>=0);cleanup=onCleanup(@()fclose(f));md=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f),bytes=fread(f,1048576,'*uint8');md.update(bytes);end
h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
end
