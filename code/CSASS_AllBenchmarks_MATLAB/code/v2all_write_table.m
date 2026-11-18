function v2all_write_table(file,T)
folder=fileparts(file);if ~isfolder(folder),mkdir(folder);end
temp=[file,'.tmp_',char(java.util.UUID.randomUUID),'.csv'];
writetable(T,temp,'FileType','text','Encoding','UTF-8');
[ok,msg]=movefile(temp,file,'f');assert(ok,'%s',msg);
end
