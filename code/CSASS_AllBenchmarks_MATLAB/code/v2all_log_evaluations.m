function v2all_log_evaluations(dest,t,X,F,G)
% Called AFTER true evaluation. Only log; never return or alter scientific data.
persistent activeDir offset
file=fullfile(dest,'precision_ledger.csv');
if isempty(activeDir)||~strcmp(activeDir,dest)
 activeDir=dest;offset=0;assert(~isfile(file),'Ledger already exists; no implicit retry.');
end
assert(size(X,2)==t.D&&size(X,1)==size(F,1)&&size(F,1)==size(G,1));
assert(all(isfinite(X),'all')&&all(isfinite(F),'all')&&all(isfinite(G),'all'));
assert(offset+size(X,1)<=500,'True evaluation budget would exceed 500.');
ids=(offset+(1:size(X,1)))';stages=max(0,ceil((ids-100)/10));
heads=[{'EvaluationID','Stage'},cellstr(compose('x%d',1:size(X,2))),...
 cellstr(compose('f%d',1:size(F,2))),cellstr(compose('g%d',1:size(G,2))),{'CV'}];
v2all_csv(file,heads,[ids,stages,X,F,G,sum(max(G,0),2)],offset>0);
offset=offset+size(X,1);
end
