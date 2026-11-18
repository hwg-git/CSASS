function state=m8_summarize(root,writeExcel)
% Aggregate fixed planned IDs. Preserve failed/incomplete rows and all zeros.
% No optimization, statistical comparison with CSASS, or favorable selection.
if nargin<2,writeExcel=true;end
tasks=m8_tasks(root);assert(numel(tasks)==3600,'Expected locked 3600-task scope.');
output=fullfile(root,'outputs','Missing8_Opponents');folder=fullfile(output,'tables');
if ~isfolder(folder),mkdir(folder);end
metrics={'IGD10000','IGD2000','HVr1p1','HVr3','HVr20'};
template=struct('ID','','Algorithm','','Problem','','D',0,'M',2,'Seed',0,'Status','not_started', ...
 'FE',NaN,'InitialN',NaN,'IGD10000',NaN,'IGD2000',NaN,'HVr1p1',NaN,'HVr3',NaN,'HVr20',NaN, ...
 'FeasibleND',NaN,'RuntimeSeconds',NaN,'ReferenceCount10000',NaN,'ReferenceCount2000',NaN,'Error','');
records=repmat(template,numel(tasks),1);
for i=1:numel(tasks)
 t=tasks(i);r=template;r.ID=t.ID;r.Algorithm=t.Algorithm;r.Problem=t.Problem;r.D=t.D;r.Seed=t.Seed;
 run=fullfile(output,'runs',t.ID);
 if isfile(fullfile(run,'completed.json'))
  try
   marker=jsondecode(fileread(fullfile(run,'completed.json')));
   q=jsondecode(fileread(fullfile(run,'result.json')));
   assert(strcmp(q.ID,t.ID)&&strcmp(q.Algorithm,t.Algorithm)&&strcmp(q.Problem,t.Problem)&&q.D==t.D&&q.Seed==t.Seed,'Result identity mismatch.');
   assert(strcmp(q.Status,'completed')&&q.FE==500&&q.InitialN==100&&q.M==2,'Completed result budget/population/objective mismatch.');
   if isfield(marker,'ID'),assert(strcmp(marker.ID,t.ID));end
   if isfield(marker,'FE'),assert(marker.FE==500);end
   names=fieldnames(template);
   for k=1:numel(names),key=names{k};if isfield(q,key),r.(key)=q.(key);end,end
   for k=1:numel(metrics)
    key=metrics{k};v=r.(key);if ischar(v)||isstring(v),v=str2double(v);end
    if isempty(v)&&startsWith(key,'IGD')&&q.FeasibleND==0,v=Inf;end
    assert(isnumeric(v)&&isscalar(v)&&~isnan(v),'Missing/malformed metric: %s',key);
    if startsWith(key,'HV'),assert(isfinite(v)&&v>=0);else,assert(v>=0);end
    r.(key)=v;
   end
   for key={'FeasibleND','RuntimeSeconds','ReferenceCount10000','ReferenceCount2000'}
    v=r.(key{1});assert(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>=0,'Missing/malformed numeric metadata.');
   end
   r.Status='completed';
  catch err
   r=template;r.ID=t.ID;r.Algorithm=t.Algorithm;r.Problem=t.Problem;r.D=t.D;r.Seed=t.Seed;
   r.Status='audit_failed';r.Error=err.message;
  end
 elseif isfile(fullfile(run,'failure.json'))
  r.Status='failed';
  try,q=jsondecode(fileread(fullfile(run,'failure.json')));if isfield(q,'Error'),r.Error=q.Error;end;catch,end
 elseif isfolder(run)
  r.Status='incomplete';
 end
 records(i)=r;
end
T=struct2table(records);T=sortrows(T,{'Problem','D','Algorithm','Seed'});
groups=unique(T(:,{'Problem','D','Algorithm'}),'rows');assert(height(groups)==120);
groupRows=cell(height(groups),1);
for i=1:height(groups)
 p=groups.Problem{i};d=groups.D(i);a=groups.Algorithm{i};v=T(strcmp(T.Problem,p)&T.D==d&strcmp(T.Algorithm,a),:);
 assert(height(v)==30&&isequal(sort(v.Seed)',1:30));complete=strcmp(v.Status,'completed');w=v(complete,:);n=height(w);
 row=struct('Problem',p,'D',d,'Algorithm',a,'PlannedRuns',30,'CompletedRuns',n, ...
  'FailedRuns',sum(strcmp(v.Status,'failed')),'IncompleteRuns',sum(strcmp(v.Status,'incomplete')), ...
  'AuditFailedRuns',sum(strcmp(v.Status,'audit_failed')),'NotStartedRuns',sum(strcmp(v.Status,'not_started')), ...
  'FeasibleRuns',sum(w.FeasibleND>0),'FiniteIGDRuns',sum(isfinite(w.IGD10000)), ...
  'ZeroHVr1p1Runs',sum(w.HVr1p1==0),'ZeroHVr3Runs',sum(w.HVr3==0),'ZeroHVr20Runs',sum(w.HVr20==0), ...
  'RuntimeMean',NaN,'RuntimeStd',NaN);
 for k=1:numel(metrics)
  key=metrics{k};values=w.(key);mu=NaN;sd=NaN;
  if n==30&&all(isfinite(values)),mu=mean(values);sd=std(values,0);end
  row.([key 'Mean30'])=mu;row.([key 'Std30'])=sd;
 end
 if n==30&&all(isfinite(w.RuntimeSeconds)),row.RuntimeMean=mean(w.RuntimeSeconds);row.RuntimeStd=std(w.RuntimeSeconds,0);end
 groupRows{i}=row;
end
G=struct2table(vertcat(groupRows{:}));
csvsave(T,fullfile(folder,'all_runs.csv'));csvsave(G,fullfile(folder,'group_progress.csv'));csvsave(G(G.CompletedRuns==30,:),fullfile(folder,'complete30_summary.csv'));
layouts=cell(1,numel(metrics));
for k=1:numel(metrics),layouts{k}=layout(G,metrics{k});csvsave(layouts{k},fullfile(folder,['opponents_' metrics{k} '.csv']));end
state=struct('Status','in_progress','ExpectedRuns',3600,'CompletedRuns',sum(strcmp(T.Status,'completed')), ...
 'FailedRuns',sum(strcmp(T.Status,'failed')),'IncompleteRuns',sum(strcmp(T.Status,'incomplete')), ...
 'AuditFailedRuns',sum(strcmp(T.Status,'audit_failed')),'NotStartedRuns',sum(strcmp(T.Status,'not_started')), ...
 'ExpectedGroups',120,'Full30Groups',sum(G.CompletedRuns==30),'ReferenceRequest',10000, ...
 'TrueEvaluationBudget',500,'InitialPopulation',100,'IndependentRunsPerGroup',30, ...
 'PrimaryHVReference',1.1,'SensitivityHVReferences',[3 20],'AllZeroHVRetained',true, ...
 'IGDSummaryPolicy','Full30 finite mean/sample SD, otherwise N/A; no failed-run exclusion or conditional mean used in primary tables.', ...
 'NoCSASSComparisons','This package contains five opponents only; no significance claims against CSASS are generated.', ...
 'UpdatedUTC',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss')));
if state.CompletedRuns==3600,state.Status='experiments_complete';end
if writeExcel
 try
  workbook=fullfile(folder,'RESULTS.xlsx');temp=fullfile(folder,['RESULTS_' char(java.util.UUID.randomUUID()) '.xlsx']);
  excelwrite(T,temp,'AllRuns');excelwrite(G,temp,'Groups');
  for k=1:numel(metrics),excelwrite(layouts{k},temp,metrics{k});end
  [ok,msg]=movefile(temp,workbook,'f');
  if ~ok,state.ExcelStatus=['target_locked_snapshot_kept: ' temp];fprintf(2,'Excel target locked; retained %s (%s)\n',temp,msg);else,state.ExcelStatus='written';end
 catch err,state.ExcelStatus=['unavailable: ' err.message];fprintf(2,'CSV/results remain saved; Excel export: %s\n',err.message);
 end
end
jsonsave(state,fullfile(folder,'status.json'));
end
function A=layout(G,metric)
algorithms={'ANSGAIII','HeEMOEA','MOL2SMEA','PCSAEA','CTAEA'};
problems={'CF2','CF3','CF4','CF6','LIRCMOP5','LIRCMOP6','LIRCMOP9','LIRCMOP10'};
C=cell(24,7);i=0;
for pi=1:numel(problems)
 for d=[10 20 50]
  i=i+1;C{i,1}=problems{pi};C{i,2}=d;
  for ai=1:5
   z=G(strcmp(G.Problem,problems{pi})&G.D==d&strcmp(G.Algorithm,algorithms{ai}),:);assert(height(z)==1);
   if z.CompletedRuns<30,value=sprintf('Pending (%d/30)',z.CompletedRuns);
   elseif ~isfinite(z.([metric 'Mean30'])),value='N/A';
   else,value=sprintf('%.4e (%.2e)',z.([metric 'Mean30']),z.([metric 'Std30']));end
   C{i,ai+2}=value;
  end
 end
end
A=cell2table(C,'VariableNames',[{'Problem','D'},algorithms]);
end
function csvsave(T,file)
[folder,name,ext]=fileparts(file);temp=fullfile(folder,[name '_' char(java.util.UUID.randomUUID()) ext]);writetable(T,temp);
[ok,msg]=movefile(temp,file,'f');if ~ok,fprintf(2,'CSV target locked; retained %s (%s)\n',temp,msg);end
end
function jsonsave(s,file)
[folder,name,ext]=fileparts(file);temp=fullfile(folder,[name '_' char(java.util.UUID.randomUUID()) ext]);fid=fopen(temp,'w','n','UTF-8');assert(fid>=0);guard=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(s,'PrettyPrint',true));clear guard;
[ok,msg]=movefile(temp,file,'f');if ~ok,fprintf(2,'JSON target locked; retained %s (%s)\n',temp,msg);end
end
function excelwrite(T,file,sheet)
C=[T.Properties.VariableNames;table2cell(T)];
for i=2:size(C,1),for j=1:size(C,2),if isnumeric(C{i,j})&&isscalar(C{i,j})&&~isfinite(C{i,j}),C{i,j}=num2str(C{i,j});end,end,end
writecell(C,file,'Sheet',sheet);
end
