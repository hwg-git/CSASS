function portable_write_json(file,x)
temp=tempname(fileparts(file));f=fopen(temp,'w','n','UTF-8');assert(f>=0);fprintf(f,'%s',jsonencode(x,'PrettyPrint',true));fclose(f);
for j=1:200,[ok,msg]=movefile(temp,file,'f');if ok,return;end;pause(.01);end;error('JSON write: %s',msg);
end
