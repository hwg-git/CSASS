function x=portable_read_json(p)
for i=1:100
 try,x=jsondecode(fileread(p));return;catch e,if i==100,rethrow(e);end;pause(.02);end
end
end
