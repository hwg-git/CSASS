function portable_summarize(root,c,shard)
% Completed records are immutable; cache decoded data to avoid rereading them.
persistent cachedOutput recordCache choiceCache statCache
if isempty(cachedOutput)||~strcmp(cachedOutput,c.Output)
 cachedOutput=c.Output;recordCache=containers.Map('KeyType','char','ValueType','any');choiceCache=containers.Map('KeyType','char','ValueType','any');statCache=containers.Map('KeyType','char','ValueType','any');
end
folder=fullfile(c.Output,'tables');if ~isfolder(folder),mkdir(folder);end
rs=dir(fullfile(c.Output,'runs','*','result.json'));
for i=1:numel(rs)
 [~,id]=fileparts(rs(i).folder);if isKey(recordCache,id),continue;end
 if ~isfile(fullfile(rs(i).folder,'completed.json')),continue;end
 r=portable_read_json(fullfile(rs(i).folder,'result.json'));if r.NonfiniteIGD,r.IGD=Inf;end
 recordCache(id)=r;
 if strcmp(r.Algorithm,'CSASS')
  a=readmatrix(fullfile(rs(i).folder,'model_selection.csv'),'NumHeaderLines',1);
  choiceCache(id)=struct('ID',id,'Problem',r.Problem,'D',r.D,'ObjectiveRBFStages',sum(a(:,4)==1),'ObjectiveKrigingStages',sum(a(:,4)==2),'ConstraintRBFStages',sum(a(:,5)==1),'ConstraintKrigingStages',sum(a(:,5)==2),'ObjectiveSwitches',sum(diff(a(:,4))~=0),'ConstraintSwitches',sum(diff(a(:,5))~=0),'UndefinedObjectiveR2Stages',sum(any(isnan(a(:,[8,10])),2)),'UndefinedConstraintR2Stages',sum(any(isnan(a(:,[9,11])),2)));
 end
end
suffix='';if shard>0&&c.ShardCount>1,suffix=sprintf('_shard%d',shard);end
tasks=portable_tasks(c);planned=numel(tasks);
if recordCache.Count==0
 portable_write_json(fullfile(folder,['status',suffix,'.json']),struct('Completed',0,'Planned',planned,'ProgramFailures',numel(dir(fullfile(c.Output,'runs','*','failure.json'))),'Full30Groups',0));return;
end
data=values(recordCache);T=normalize_text(struct2table([data{:}]),{'ID','Status','Problem','Algorithm','Outcome'});T=sortrows(T,{'Problem','D','Algorithm','Seed'});
G=table();
for pi=1:numel(c.Problems)
 for d=c.Dimensions
  for ai=1:numel(c.Algorithms)
   problem=c.Problems{pi};alg=c.Algorithms{ai};z=T(strcmp(T.Problem,problem)&T.D==d&strcmp(T.Algorithm,alg),:);n=height(z);
   assert(numel(unique(z.Seed))==n&&n<=30,'Duplicate/excess seeds.');m=objective_count(problem);
   im=NaN;is=NaN;hm=NaN;hs=NaN;h15=NaN;h2=NaN;cm=NaN;cs=NaN;nv=0;
   if n>0,valid=z.IGD(isfinite(z.IGD));nv=numel(valid);if nv>0,cm=mean(valid);cs=std(valid);end;end
   if n==30,im=mean(z.IGD);is=std(z.IGD);hm=mean(z.HV);hs=std(z.HV);h15=mean(z.HVRef1p5);h2=mean(z.HVRef2p0);end
   row=table({problem},d,m,{alg},n,30,im,is,hm,hs,nv,n-nv,sum(z.HV==0),sum(z.FeasibleND==0),cm,cs,h15,h2, ...
    'VariableNames',{'Problem','D','M','Algorithm','NCompleted','NPlanned','IGDMean30','IGDStd30','HVMean30','HVStd30','FiniteIGDRuns','NonfiniteIGDRuns','ZeroHVRuns','NoFeasibleSetRuns','ConditionalFiniteIGDMean','ConditionalFiniteIGDStd','HVRef1p5Mean30','HVRef2p0Mean30'});
   G=[G;row]; %#ok<AGROW>
  end
 end
end
tablecsv(T,fullfile(folder,['all_runs',suffix,'.csv']));tablecsv(G,fullfile(folder,['group_progress',suffix,'.csv']));tablecsv(G(G.NCompleted==30,:),fullfile(folder,['complete30_summary',suffix,'.csv']));
paper=readtable(fullfile(root,'original_paper_IGD.csv'));paper=removevars(paper,'M');
comparison=innerjoin(G,paper,'Keys',{'Problem','D','Algorithm'});
comparison.Full30RelativeDifferencePercent=NaN(height(comparison),1);
good=comparison.NCompleted==30&isfinite(comparison.IGDMean30)&isfinite(comparison.PaperIGDMean)&comparison.PaperIGDMean~=0;
comparison.Full30RelativeDifferencePercent(good)=100*(comparison.IGDMean30(good)./comparison.PaperIGDMean(good)-1);
tablecsv(comparison,fullfile(folder,['paper_IGD_comparison',suffix,'.csv']));
for pi=1:numel(c.Problems)
 problem=c.Problems{pi};
 for d=c.Dimensions
  a=T(strcmp(T.Problem,problem)&T.D==d&strcmp(T.Algorithm,'CSASS'),:);if height(a)~=30,continue;end
  for ai=1:numel(c.Algorithms)
   alg=c.Algorithms{ai};if strcmp(alg,'CSASS'),continue;end
   b=T(strcmp(T.Problem,problem)&T.D==d&strcmp(T.Algorithm,alg),:);if height(b)~=30,continue;end
   for metric={'IGD','HV'}
    key=sprintf('%s_D%d_%s_%s',problem,d,alg,metric{1});if isKey(statCache,key),continue;end
    x=a.(metric{1});y=b.(metric{1});allvalues=[x;y];
    if all(allvalues==allvalues(1)),pv=1;else,assert(exist('ranksum','file')==2,'ranksum required for statistical tables.');pv=ranksum(x,y,'method','approximate');end
    symbol='=';score=sum(x<y','all')+.5*sum(x==y','all');if strcmp(metric{1},'HV'),score=900-score;end
    if pv<.05,if score>450,symbol='+';elseif score<450,symbol='-';end;end
    statCache(key)=struct('Problem',problem,'D',d,'Competitor',alg,'Metric',metric{1},'PValue',pv,'Symbol',symbol,'CSASSValidObservations',30,'CompetitorValidObservations',30,'InfRetained',true);
   end
  end
 end
end
stats=table();if statCache.Count,v=values(statCache);stats=normalize_text(struct2table([v{:}]),{'Problem','Competitor','Metric','Symbol'});tablecsv(stats,fullfile(folder,['statistical_comparisons',suffix,'.csv']));end
freq=table();if choiceCache.Count,v=values(choiceCache);freq=normalize_text(struct2table([v{:}]),{'ID','Problem'});tablecsv(freq,fullfile(folder,['model_choice_counts',suffix,'.csv']));end
groups={'CF_2obj','CF_3obj','LIRCMOP_2obj','LIRCMOP_3obj'};paperTables=cell(4,2);
for gi=1:4
 for mi=1:2
  metric={'IGD','HV'};metric=metric{mi};A=layout_table(G,stats,groups{gi},metric);
  paperTables{gi,mi}=A;tablecsv(A,fullfile(folder,[groups{gi},'_',metric,suffix,'.csv']));
 end
end
failure=dir(fullfile(c.Output,'runs','*','failure.json'));full=sum(G.NCompleted==30);
state='running';if height(T)==planned,state='complete';end
portable_write_json(fullfile(folder,['status',suffix,'.json']),struct('Status',state,'Completed',height(T),'Planned',planned,'ProgramFailures',numel(failure),'Full30Groups',full,'ExpectedGroups',height(G),'UpdatedUTC',char(datetime('now','TimeZone','UTC'))));
if c.WriteExcel
 try
  file=fullfile(folder,['RESULTS',suffix,'.xlsx']);excelwrite(T,file,'AllRuns');excelwrite(G,file,'GroupProgress');excelwrite(comparison,file,'OriginalPaperIGD');
  if ~isempty(stats),excelwrite(stats,file,'Statistics');end;if ~isempty(freq),excelwrite(freq,file,'ModelChoices');end
  for gi=1:4,for mi=1:2,metric={'IGD','HV'};excelwrite(paperTables{gi,mi},file,[groups{gi},'_',metric{mi}]);end;end
 catch e,fprintf(2,'Excel locked/unavailable;CSV and raw runs remain saved: %s\n',e.message);end
end
end
function m=objective_count(name)
if startsWith(name,'CF'),m=2+(str2double(name(3:end))>=8);else,m=2+(str2double(name(8:end))>=13);end
end
function T=normalize_text(T,names)
for i=1:numel(names),k=names{i};if ismember(k,T.Properties.VariableNames)&&(ischar(T.(k))||isstring(T.(k))),T.(k)=cellstr(T.(k));end;end
end
function A=layout_table(G,S,group,metric)
algs={'ANSGAIII','HeEMOEA','MOL2SMEA','PCSAEA','CTAEA','CSASS'};
prefix='CF';m=2;if startsWith(group,'LIRCMOP'),prefix='LIRCMOP';end;if endsWith(group,'3obj'),m=3;end
mask=startsWith(G.Problem,prefix)&G.M==m;instances=unique(G(mask,{'Problem','D'}),'rows');
if ~isempty(instances)
 number=cellfun(@(x)str2double(regexprep(x,'[^0-9]','')),instances.Problem);[~,order]=sortrows([number,instances.D],[1,2]);instances=instances(order,:);
end
cells=cell(height(instances),8);
for i=1:height(instances)
 p=instances.Problem{i};d=instances.D(i);cells{i,1}=p;cells{i,2}=d;
 for ai=1:6
  z=G(strcmp(G.Problem,p)&G.D==d&strcmp(G.Algorithm,algs{ai}),:);
  if isempty(z),value='Not in selected scope';
  elseif z.NCompleted~=30,value=sprintf('Pending (%d/30)',z.NCompleted);
  else
   if strcmp(metric,'IGD'),mu=z.IGDMean30;sd=z.IGDStd30;else,mu=z.HVMean30;sd=z.HVStd30;end
   value=sprintf('%.4e (%.2e)',mu,sd);
   if ai~=6&&~isempty(S),j=find(strcmp(S.Problem,p)&S.D==d&strcmp(S.Competitor,algs{ai})&strcmp(S.Metric,metric),1);if ~isempty(j),value=[value,' ',S.Symbol{j}];end;end
  end
  cells{i,ai+2}=value;
 end
end
A=cell2table(cells,'VariableNames',{'Problem','D','ANSGAIII','HeEMOEA','MOL2SMEA','PCSAEA','CTAEA','CSASS'});
end
function tablecsv(T,file)
[folder,name,ext]=fileparts(file);temp=fullfile(folder,[name,'_pending_',char(java.util.UUID.randomUUID()),ext]);
writetable(T,temp);
for k=1:10,[ok,~]=movefile(temp,file,'f');if ok,return;end;pause(.05);end
fprintf(2,'CSV target locked;new snapshot kept at %s\n',temp);
end
function excelwrite(T,file,sheet)
C=[T.Properties.VariableNames;table2cell(T)];
for i=2:size(C,1),for j=1:size(C,2),if isnumeric(C{i,j})&&isscalar(C{i,j})&&~isfinite(C{i,j}),C{i,j}=num2str(C{i,j});end;end;end
writecell(C,file,'Sheet',sheet);
end
