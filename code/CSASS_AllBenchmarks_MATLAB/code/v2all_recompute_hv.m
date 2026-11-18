function report=v2all_recompute_hv(root,references)
% Recalculate exact HV from saved final sets only. No training or evaluation.
if nargin<2||isempty(references),references=[1.1,3,20];end
validateattributes(references,{'numeric'},{'vector','real','finite','positive','nonempty'});
references=unique(references(:)','stable');assert(numel(references)<=30,'At most30 references per saved-data request.');
cfg=v2all_preflight(root);v2all_engine_setup(root);
B=readtable(fullfile(root,'baseline','completed_runs.csv'),'TextType','string');
cols={'ID','Version','Problem','D','Seed','M','FeasibleND','HVr1p1','HVr3','HVr20','FinalObjectivesAvailable'};
T=B(:,cols);T.Origin=repmat("cached",height(T),1);
tasks=v2all_tasks(root);inventory=v2all_inventory(root,tasks);
newRows=cell(inventory.Completed,1);j=0;
for k=find(inventory.CompletedMask)'
 task=tasks(k);d=fullfile(root,'outputs','V2_AllBenchmarks','runs',task.ID);
 mark=v2all_io('json',fullfile(d,'completed.json'));
 whichFile=strcmp({mark.Files.Path},'result.json');assert(sum(whichFile)==1);
 assert(strcmpi(v2all_io('sha',fullfile(d,'result.json')),mark.Files(whichFile).SHA256));
 q=v2all_io('json',fullfile(d,'result.json'));
 assert(strcmp(q.ID,task.ID)&&strcmp(q.Problem,task.Problem)&&q.D==task.D&&q.Seed==task.Seed&&q.FE==500);
 m=2+double(ismember(task.Problem,{'CF8','CF9','CF10','LIRCMOP13','LIRCMOP14'}));
 r=table(string(q.ID),"V2",string(q.Problem),q.D,q.Seed,m,q.FeasibleND,...
  q.HVr1p1,q.HVr3,q.HVr20,true,'VariableNames',cols);r.Origin="new";
 j=j+1;newRows{j}=r;
end
if j>0,T=[T;vertcat(newRows{:})];end
P=table();
for problem=string(cfg.Problems(:))'
 for d=cfg.Dimensions(:)',P=[P;table(problem,d,'VariableNames',{'Problem','D'})];end %#ok<AGROW>
end
rows=cell(height(T)*numel(references),1);count=0;sets=0;missing=0;
pfCache=containers.Map('KeyType','char','ValueType','any');
for i=1:height(T)
 key=char(T.Problem(i));
 if ~isKey(pfCache,key)
  Fref=readmatrix(fullfile(root,'references','PF10000',[key,'.csv']),'NumHeaderLines',1);
  pfCache(key)=struct('Minimum',min(Fref,[],1),'Range',max(Fref,[],1)-min(Fref,[],1),...
   'Rows',size(Fref,1),'M',size(Fref,2));
 end
 pf=pfCache(key);assert(all(pf.Range>0));
 available=logical(T.FinalObjectivesAvailable(i));origin=char(T.Origin(i));
 if strcmp(origin,'new'),d=fullfile(root,'outputs','V2_AllBenchmarks','runs',char(T.ID(i)));
 else,d=fullfile(root,'baseline','solutions',char(T.ID(i)));end
 f=fullfile(d,'final_objectives.csv');
 if available
  assert(isfile(f),'A promised saved objective set is missing: %s',f);
  if strcmp(origin,'new')
   mark=v2all_io('json',fullfile(d,'completed.json'));
   k=strcmp({mark.Files.Path},'final_objectives.csv');assert(sum(k)==1);
   assert(strcmpi(v2all_io('sha',f),mark.Files(k).SHA256),'Final-set hash differs: %s',f);
  end
  F=readmatrix(f,'NumHeaderLines',1);
  if isempty(F),F=zeros(0,pf.M);end
  assert(size(F,2)==pf.M&&all(isfinite(F),'all')&&size(F,1)==T.FeasibleND(i));
  U=(F-pf.Minimum)./pf.Range;sets=sets+1;
  state="recomputed_from_saved_set";if isempty(F),state="saved_empty_feasible_set";end
 else
  U=zeros(0,pf.M);missing=missing+1;state="cached_final_set_not_available";
 end
 for r=references
  value=NaN;if available,value=csass_v2.hypervolume(U,repmat(r,1,pf.M));end
  old=NaN;
  if r==1.1,old=T.HVr1p1(i);elseif r==3,old=T.HVr3(i);elseif r==20,old=T.HVr20(i);end
  difference=NaN;
  if available&&isfinite(old)
   difference=value-old;
   assert(abs(difference)<=1e-9*max(1,abs(old)),'HV postprocessing differs from saved metric: %s',T.ID(i));
  end
  count=count+1;
  rows{count}=table(T.ID(i),T.Version(i),T.Problem(i),T.D(i),T.Seed(i),pf.M,r,...
   available,T.FeasibleND(i),value,old,difference,state,T.Origin(i),pf.Rows,...
   'VariableNames',{'ID','Version','Problem','D','Seed','M','Reference','FinalSetAvailable',...
   'FeasibleND','HV','PreviouslyReportedHV','DifferenceFromReported','Status','Origin','ActualPFRows'});
 end
end
R=vertcat(rows{:});G=table();
for i=1:height(P)
 for r=references
  k=R.Problem==P.Problem(i)&R.D==P.D(i)&R.Reference==r;Q=R(k,:);valid=isfinite(Q.HV);
  mu=NaN;sd=NaN;oldMean=NaN;oldStd=NaN;
  if height(Q)==30&&all(valid),mu=mean(Q.HV);sd=std(Q.HV,0);end
  if height(Q)==30&&all(isfinite(Q.PreviouslyReportedHV)),oldMean=mean(Q.PreviouslyReportedHV);oldStd=std(Q.PreviouslyReportedHV,0);end
  row=table("V2",P.Problem(i),P.D(i),r,height(Q),sum(valid),30-height(Q),...
   sum(~Q.FinalSetAvailable),sum(valid&Q.HV==0),mu,sd,oldMean,oldStd,...
   'VariableNames',{'Version','Problem','D','Reference','CompletedRuns','SavedSetsRecomputed',...
   'PendingRuns','MissingCachedSets','ZeroHVRuns','HVMean30','HVStd30','PreviouslyReportedMean30','PreviouslyReportedStd30'});
  G=[G;row]; %#ok<AGROW>
 end
end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));token=char(java.util.UUID.randomUUID);
dest=fullfile(root,'outputs','V2_AllBenchmarks','hv_postprocess',[stamp,'_',token(1:8)]);mkdir(dest);
v2all_write_table(fullfile(dest,'hv_runs.csv'),R);v2all_write_table(fullfile(dest,'hv_groups.csv'),G);
report=struct('Status','saved_data_processed','OptimizationRuns',0,'TrueEvaluations',0,'NewModelFits',0,...
 'References',references,'Normalization','Frozen PF10000 minimum/range for each problem, same for all runs',...
 'CompletedRunRecords',height(T),'SetsRecomputed',sets,'CachedSetsNotAvailable',missing,...
 'ExpectedRuns',cfg.TotalTasks,'AllNewExperimentsComplete',height(T)==cfg.TotalTasks,...
 'AllCompletedSetsAvailable',missing==0,'ExcelWritten',false,'OutputDirectory',dest,...
 'OriginalTablesOverwritten',false,'MissingSetRule','HV remains unavailable; previously reported HV is a separate column');
try
 file=fullfile(dest,'HV_recomputed.xlsx');v2all_write_excel(R,file,'Runs');v2all_write_excel(G,file,'Groups');report.ExcelWritten=true;
catch e,report.ExcelError=e.message;warning('V2_AllBenchmarks:HVExcel','CSV saved; Excel: %s',e.message);end
v2all_io('writejson',fullfile(dest,'audit.json'),report);
fprintf('Saved-set HV: %d recomputed, %d cache sets unavailable, no optimization.\n%s\n',sets,missing,dest);
end
