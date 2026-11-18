function portable_write_csv(file,names,data,append)
if nargin<4,append=false;end
assert(numel(names)==size(data,2)&&numel(unique(names))==numel(names));
if append,mode='a';else,assert(~isfile(file),'Preserve existing raw CSV.');mode='w';end
f=fopen(file,mode);assert(f>=0);cleanup=onCleanup(@()fclose(f));
if ~append,fprintf(f,'%s\n',strjoin(names,','));end
for i=1:size(data,1)
 fprintf(f,'%.17g',data(i,1));fprintf(f,',%.17g',data(i,2:end));fprintf(f,'\n');
end
end
