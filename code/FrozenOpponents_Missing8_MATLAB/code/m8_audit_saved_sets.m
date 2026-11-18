function audit=m8_audit_saved_sets(root)
% Independently recalculate completed final-set metrics without true evaluations.
tasks=m8_tasks(root);output=fullfile(root,'outputs','Missing8_Opponents');
assert(numel(tasks)==3600);refs=containers.Map('KeyType','char','ValueType','any');
maxerr=zeros(1,5);files=cell(numel(tasks),3);failures=cell(0,2);verified=0;
for i=1:numel(tasks)
 t=tasks(i);run=fullfile(output,'runs',t.ID);
 try
  assert(isfile(fullfile(run,'completed.json')),'Missing completed marker.');
  r=jsondecode(fileread(fullfile(run,'result.json')));
  assert(strcmp(r.ID,t.ID)&&strcmp(r.Algorithm,t.Algorithm)&&strcmp(r.Problem,t.Problem)&&r.D==t.D&&r.Seed==t.Seed);
  assert(strcmp(r.Status,'completed')&&r.FE==500&&r.InitialN==100);
  marker=jsondecode(fileread(fullfile(run,'completed.json')));
  if isfield(marker,'Files')
   for f=1:numel(marker.Files)
    member=marker.Files(f).Path;assert(isempty(regexp(member,'[\\/:]','once'))&&~contains(member,'..'),'Unsafe completed-marker member.');
    assert(strcmp(fileSHA(fullfile(run,member)),marker.Files(f).SHA256),'Completed artifact hash mismatch.');
   end
  end
  if ~isKey(refs,t.Problem)
   a=matrix(fullfile(root,'references','PF10000',[t.Problem '.csv']));
   b=matrix(fullfile(root,'references','PF2000',[t.Problem '.csv']));
   refs(t.Problem)=struct('PF10000',a,'PF2000',b,'Min',min(a,[],1),'Range',max(a,[],1)-min(a,[],1));
  end
  ref=refs(t.Problem);assert(r.ReferenceCount10000==size(ref.PF10000,1)&&r.ReferenceCount2000==size(ref.PF2000,1));F=matrix(fullfile(run,'final_objectives.csv'));
  G=matrix(fullfile(run,'final_constraints.csv'));X=matrix(fullfile(run,'final_decisions.csv'));
  assert(size(F,1)==r.FeasibleND&&size(F,2)==2&&size(X,2)==t.D);
  assert(size(F,1)==size(G,1)&&size(F,1)==size(X,1));
  assert(all(sum(max(0,G),2)==0),'Saved final set contains an infeasible point.');
  stored=load(fullfile(run,'result.mat'),'H','finalids','result');H=stored.H;ids=stored.finalids(:);
  assert(size(H.X,1)==500&&size(H.X,2)==t.D&&size(H.F,1)==500&&size(H.G,1)==500);
  assert(isequal(H.EvaluationID,(1:500)')&&numel(H.Stage)==500&&sum(H.Stage==0)==100);
  assert(isequal(H.CV,sum(max(0,H.G),2)),'Ledger constraint violation rule mismatch.');
  assert(isempty(ids)||(all(ids>=1&ids<=500)&&all(ids==floor(ids))));
  assert(isequal(F,H.F(ids,:))&&isequal(X,H.X(ids,:))&&isequal(G,H.G(ids,:)),'Saved final set does not match indexed true evaluations.');
  L=matrix(fullfile(run,'precision_ledger.csv'));
  assert(isequal(L,[H.EvaluationID,H.Stage,H.X,H.F,H.G,H.CV]),'Precision CSV and numeric truth ledger disagree.');
  initial=matrix(fullfile(run,'initial_decisions.csv'));assert(isequal(initial,H.X(1:100,:)));
  assert(strcmp(stored.result.ID,t.ID)&&stored.result.FE==500&&stored.result.InitialN==100);
  for k=1:size(F,1),assert(~any(all(F<=F(k,:),2)&any(F<F(k,:),2)),'Saved final set includes a dominated point.');end
  U=(F-ref.Min)./ref.Range;
  actual=[independentIGD(F,ref.PF10000),independentIGD(F,ref.PF2000),independentHV(U,1.1),independentHV(U,3),independentHV(U,20)];
  names={'IGD10000','IGD2000','HVr1p1','HVr3','HVr20'};
  for k=1:5
   stored=r.(names{k});if ischar(stored)||isstring(stored),stored=str2double(stored);end
   if isempty(stored)&&k<=2&&r.FeasibleND==0,stored=Inf;end
   assert(isscalar(stored)&&~isnan(stored),'Missing recorded metric.');
   if isinf(actual(k)),assert(isinf(stored)&&stored>0);err=0;
   else,err=abs(actual(k)-stored);assert(err<=1e-9*max(1,abs(actual(k))),'Recorded metric disagrees with saved set.');end
   maxerr(k)=max(maxerr(k),err);
  end
  files(i,:)={t.ID,fileSHA(fullfile(run,'result.json')),fileSHA(fullfile(run,'final_objectives.csv'))};verified=verified+1;
 catch err,failures(end+1,:)={t.ID,err.message};end %#ok<AGROW>
 if mod(i,300)==0,fprintf('Saved-set audit %d / 3600.\n',i);end
end
audit=struct('Status','pass','ExpectedRuns',3600,'VerifiedRuns',verified,'FailureCount',size(failures,1), ...
 'MaximumMetricAbsoluteErrors',maxerr,'MetricOrder',{{'IGD10000','IGD2000','HVr1p1','HVr3','HVr20'}}, ...
 'Recalculation','Independent IGD accumulation and two-objective HV sweep; 500-row truth ledger, initial 100 rows, finalids membership, CSV/MAT agreement and completed artifact hashes.', ...
 'OptimizationRuns',0,'TrueEvaluations',0,'ModelFits',0,'OriginalFilesModified',false);
if ~isempty(failures),audit.Status='fail';end
folder=fullfile(output,'tables');if ~isfolder(folder),mkdir(folder);end
writetable(cell2table(files,'VariableNames',{'ID','ResultSHA256','FinalSetSHA256'}),fullfile(folder,'final_audit_files.csv'));
writetable(cell2table(failures,'VariableNames',{'ID','Error'}),fullfile(folder,'final_audit_failures.csv'));
temp=fullfile(folder,['final_audit_' char(java.util.UUID.randomUUID()) '.json']);fid=fopen(temp,'w','n','UTF-8');assert(fid>=0);guard=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(audit,'PrettyPrint',true));clear guard;
[ok,msg]=movefile(temp,fullfile(folder,'final_audit.json'),'f');if ~ok,fprintf(2,'Audit snapshot retained at %s (%s)\n',temp,msg);end
end
function v=independentIGD(F,P)
if isempty(F),v=Inf;return;end
best=Inf(size(P,1),1);
for j=1:size(F,1),distance=sqrt(sum((P-F(j,:)).^2,2));best=min(best,distance);end
v=sum(best)/size(P,1);
end
function v=independentHV(F,r)
F=F(all(F<r,2),:);assert(isempty(F)||size(F,2)==2);
if isempty(F),v=0;return;end
F=sortrows(F,[1 2]);best=r;v=0;
for j=1:size(F,1),if F(j,2)<best,v=v+(r-F(j,1))*(best-F(j,2));best=F(j,2);end,end
end
function a=matrix(file)
text=fileread(file);lines=regexp(text,'\r?\n','split');m=numel(strsplit(strtrim(lines{1}),','));
body=strjoin(lines(2:end),newline);
if isempty(strtrim(body)),a=zeros(0,m);else,a=readmatrix(file,'NumHeaderLines',1);assert(size(a,2)==m);end
assert(all(isfinite(a),'all'));
end
function h=fileSHA(file)
fid=fopen(file,'rb');assert(fid>=0);guard=onCleanup(@()fclose(fid));md=java.security.MessageDigest.getInstance('SHA-256');
while true,b=fread(fid,1048576,'*uint8');if isempty(b),break;end;md.update(b);end
h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
