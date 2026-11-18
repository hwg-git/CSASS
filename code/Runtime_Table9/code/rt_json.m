function rt_json(file,value)
tmp=[file,'.tmp_',char(java.util.UUID.randomUUID())];
fid=fopen(tmp,'w','n','UTF-8'); assert(fid>=0,'Cannot write %s',tmp);
try
    fprintf(fid,'%s\n',jsonencode(value)); fclose(fid);
catch err
    fclose(fid); rethrow(err);
end
[ok,msg]=movefile(tmp,file,'f'); assert(ok,'%s',msg);
end
