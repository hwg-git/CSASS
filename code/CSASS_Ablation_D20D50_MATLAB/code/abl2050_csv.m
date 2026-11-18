function abl2050_csv(file,headers,A,append)
% Full-precision numeric CSV; no scientific values are rounded for storage.
if nargin<4,append=false;end
assert(size(A,2)==numel(headers));
if append,mode='a';else,mode='w';end
fid=fopen(file,mode,'n','UTF-8');assert(fid>=0,'Cannot write %s',file);
guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
if ~append,fprintf(fid,'%s\n',strjoin(headers,','));end
if ~isempty(A),fmt=[repmat('%.17g,',1,size(A,2)-1),'%.17g\n'];fprintf(fid,fmt,A');end
end
