function audit=v2all_summarize(root,writeExcel)
% Saved-data statistics. Light rolling summaries skip all trace/MAT content.
if nargin<2,writeExcel=true;end
cfg=v2all_preflight(root);tasks=v2all_tasks(root);inv=v2all_inventory(root,tasks);
B=readtable(fullfile(root,'baseline','completed_runs.csv'),'TextType','string');
assert(height(B)==cfg.CachedTasks && all(B.FE==500) && all(B.Status=="completed") && all(B.Version=="V2"));
assert(numel(unique(B.ID))==height(B) && isempty(intersect(B.ID,string({tasks.ID})')));
cols={'ID','Version','Problem','D','Seed','FE','M','FeasibleND','IGD10000','IGD2000',...
 'HVr1p1','HVr3','HVr20','FinalObjectivesAvailable','Source','SourceSHA256'};
T=B(:,cols);T.RuntimeSeconds=nan(height(T),1);T.Origin=repmat("cached",height(T),1);
T.TraceAvailable=false(height(T),1);newRows=cell(inv.Completed,1);row=0;validatedFiles=0;
for i=find(inv.CompletedMask)'
 task=tasks(i);d=fullfile(root,'outputs','V2_AllBenchmarks','runs',task.ID);
 marker=v2all_io('json',fullfile(d,'completed.json'));
 assert(isfield(marker,'Files') && numel(marker.Files)>=13);
 names=string({marker.Files.Path});assert(numel(unique(names))==numel(names));
 for j=1:numel(marker.Files)
  rel=char(marker.Files(j).Path);
  assert(isempty(regexp(rel,'(^[\\/]|^[A-Za-z]:|(^|[\\/])\.\.([\\/]|$))','once')));
  f=fullfile(d,rel);assert(isfile(f),'Missing completed artifact: %s',f);
  if writeExcel || strcmp(rel,'result.json')
   assert(strcmpi(v2all_io('sha',f),marker.Files(j).SHA256),'Artifact hash mismatch: %s',f);
   validatedFiles=validatedFiles+1;
  end
 end
 r=v2all_io('json',fullfile(d,'result.json'));
 assert(strcmp(r.ID,task.ID)&&strcmp(r.Version,task.Version)&&strcmp(r.Problem,task.Problem));
 assert(r.D==task.D&&r.Seed==task.Seed&&r.FE==500&&r.N==100&&r.Pmax==20&&r.K==10);
 assert(r.RequestedPF==10000&&r.Scale==1&&strcmp(r.status,'completed'));
 M=2+double(ismember(task.Problem,{'CF8','CF9','CF10','LIRCMOP13','LIRCMOP14'}));
 if isfield(r,'M'),assert(r.M==M);end
 if r.FeasibleND==0
  assert(r.NonfiniteIGD&&r.HVr1p1==0&&r.HVr3==0&&r.HVr20==0);
  r.IGD10000=Inf;r.IGD2000=Inf;
 else
  assert(isscalar(r.IGD10000)&&isfinite(r.IGD10000)&&r.IGD10000>=0);
  assert(isscalar(r.IGD2000)&&isfinite(r.IGD2000)&&r.IGD2000>=0);
 end
 assert(all(isfinite([r.HVr1p1,r.HVr3,r.HVr20]))&&r.HVr1p1>=0&&r.HVr3>=r.HVr1p1&&r.HVr20>=r.HVr3);
 R=table(string(r.ID),string(r.Version),string(r.Problem),r.D,r.Seed,r.FE,M,r.FeasibleND,...
  r.IGD10000,r.IGD2000,r.HVr1p1,r.HVr3,r.HVr20,true,string(fullfile('runs',task.ID)),...
  string(v2all_io('sha',fullfile(d,'completed.json'))),'VariableNames',cols);
 R.RuntimeSeconds=r.RuntimeSeconds;R.Origin="new";R.TraceAvailable=true;
 row=row+1;newRows{row}=R;
end
if row>0,T=[T;vertcat(newRows{:})];end
assert(numel(unique(T.ID))==height(T)&&all(T.FE==500));
G=v2all_group_statistics(T);problems=string(cfg.Problems(:));P=table();
for p=1:numel(problems)
 for D=cfg.Dimensions(:)'
  take=T.Problem==problems(p)&T.D==D;cache=any(B.Problem==problems(p)&B.D==D);
  pending=string({tasks.Problem})'==problems(p)&[tasks.D]'==D;
  origin="new";if cache,origin="cached";end
  R=table("V2",problems(p),D,30,origin,sum(take),sum(isfinite(T.IGD10000(take))),...
   sum(inv.PendingMask&pending),sum(inv.RetainedMask&pending),...
   'VariableNames',{'Version','Problem','D','Planned','Origin','Completed','FiniteIGDRuns','Pending','Retained'});
  P=[P;R]; %#ok<AGROW>
  k=G.Problem==problems(p)&G.D==D;
  if ~any(k)
   empty=G(1,:);empty.Version="V2";empty.Problem=problems(p);empty.D=D;
   for c=4:width(empty)-1,empty{1,c}=NaN;end
   empty.Runs=0;empty.FiniteIGDRuns=0;empty.FeasibleRuns=0;empty.ZeroHVRuns=0;empty.IGDDisplay="PENDING [0/30]";
   G=[G;empty]; %#ok<AGROW>
  end
 end
end
assert(height(P)==cfg.ExpectedGroups && all(P.Completed<=30));
[~,order]=ismember(G.Problem+"_"+string(G.D),P.Problem+"_"+string(P.D));
[~,order]=sort(order);G=G(order,:);T=sortrows(T,{'Problem','D','Seed'});
paper=readtable(fullfile(root,'baseline','original_paper_IGD.csv'),'TextType','string');
C=G(:,{'Version','Problem','D','Runs','FiniteIGDRuns','IGDMean30','IGDStd30','IGDConditionalMean','IGDConditionalStd','IGDDisplay'});
C.PaperIGDMean=nan(height(C),1);C.PaperIGDStd=nan(height(C),1);
C.RelativeMeanDifferencePct=nan(height(C),1);C.ConditionalDifferencePct=nan(height(C),1);
for i=1:height(C)
 k=paper.Algorithm=="CSASS"&paper.Problem==C.Problem(i)&paper.D==C.D(i);
 assert(sum(k)==1);C.PaperIGDMean(i)=paper.PaperIGDMean(k);C.PaperIGDStd(i)=paper.PaperIGDStd(k);
 if isfinite(C.IGDMean30(i))&&isfinite(C.PaperIGDMean(i))&&C.PaperIGDMean(i)~=0
  C.RelativeMeanDifferencePct(i)=100*(C.IGDMean30(i)/C.PaperIGDMean(i)-1);
 end
 if isfinite(C.IGDConditionalMean(i))&&isfinite(C.PaperIGDMean(i))&&C.PaperIGDMean(i)~=0
  C.ConditionalDifferencePct(i)=100*(C.IGDConditionalMean(i)/C.PaperIGDMean(i)-1);
 end
end
out=fullfile(root,'outputs','V2_AllBenchmarks','tables');if ~isfolder(out),mkdir(out);end
v2all_write_table(fullfile(out,'all_runs.csv'),T);v2all_write_table(fullfile(out,'group_summary.csv'),G);
v2all_write_table(fullfile(out,'paper_IGD_comparison.csv'),C);v2all_write_table(fullfile(out,'group_progress.csv'),P);
complete=inv.Completed==cfg.NewTasks&&inv.Retained==0&&all(P.Completed==30)&&height(T)==cfg.TotalTasks;
status='in_progress';if complete,status='pass';elseif inv.Retained>0,status='retained_incomplete';end
audit=struct('Status',status,'AllExperimentsComplete',complete,'NewPlanned',cfg.NewTasks,'NewComplete',inv.Completed,...
 'ReusedComplete',cfg.CachedTasks,'CombinedComplete',height(T),'ExpectedGroups',cfg.ExpectedGroups,'RetainedIncomplete',inv.Retained,...
 'RequestedPF',10000,'ObjectiveScale',1,'HVReferences',[1.1,3,20],...
 'FullArtifactHashAudit',logical(writeExcel),'ArtifactFilesVerified',validatedFiles,...
 'AllGroupsUse30FixedSeeds',true,'AutomaticRetry',false,'FilteredRuns',0,...
 'SavedFinalSetsAvailable',sum(T.FinalObjectivesAvailable),'CachedFinalSetsUnavailable',sum(~B.FinalObjectivesAvailable),...
 'TraceCoverage','New completed tasks only; cache performance and available final sets remain separately identified',...
 'TraceRefreshed',logical(writeExcel),...
 'SourceLockSHA256',v2all_io('sha',fullfile(root,'source_lock.json')),...
 'GeneratedUTC',char(datetime('now','TimeZone','UTC')),'ExcelWritten',false,...
 'ExcelInfinityEncoding','Text Inf / -Inf only; never numeric 65535',...
 'SwitchCountConvention','Used-model adjacent stages1-40 within each trial; final next decision excluded');
if writeExcel
 [S,E,flags,byStage,errorStage]=v2all_trace_statistics(root,tasks(inv.CompletedMask));
 traceTables={S,E,flags,byStage,errorStage};
 traceNames={'selection_frequency','prediction_accuracy','stage_flags','selection_by_stage','prediction_by_stage'};
 for i=1:numel(traceTables)
  if ~isempty(traceTables{i}),v2all_write_table(fullfile(out,[traceNames{i},'.csv']),traceTables{i});end
 end
 tmp=fullfile(out,['results_',char(java.util.UUID.randomUUID),'.xlsx']);
 try
  v2all_write_excel(T,tmp,'All_runs');v2all_write_excel(G,tmp,'Group_summary');
  v2all_write_excel(C,tmp,'Paper_comparison');v2all_write_excel(P,tmp,'Progress');
  sheets={'Model_selection','Prediction_accuracy','Stage_flags','Selection_by_stage','Prediction_by_stage'};
  for i=1:numel(traceTables),if ~isempty(traceTables{i}),v2all_write_excel(traceTables{i},tmp,sheets{i});end,end
  [ok,msg]=movefile(tmp,fullfile(out,'results.xlsx'),'f');assert(ok,'%s',msg);audit.ExcelWritten=true;
 catch err
  audit.ExcelError=err.message;warning('V2_AllBenchmarks:ExcelExport','CSV saved; Excel export: %s',err.message);
 end
end
v2all_io('writejson',fullfile(out,'audit.json'),audit);
fprintf('Summary: %d/%d new +%d cached; complete groups %d/%d. %s\n',...
 inv.Completed,cfg.NewTasks,cfg.CachedTasks,sum(P.Completed==30),cfg.ExpectedGroups,out);
end
