function c=m8_preflight(root)
% Verify frozen sources, references and task scope. No evaluation or training.
c=m8_config(root);
assert(isequal(c.Problems,{'CF2','CF3','CF4','CF6','LIRCMOP5','LIRCMOP6','LIRCMOP9','LIRCMOP10'}));
assert(isequal(c.Algorithms,{'ANSGAIII','HeEMOEA','MOL2SMEA','PCSAEA','CTAEA'}));
assert(isequal(c.Dimensions,[10,20,50])&&isequal(c.Seeds,1:30));
assert(c.N==100&&c.MaxFE==500&&c.Workers==6&&c.ThreadsPerTrial==1&&c.MaxWallHours==24);
assert(c.TotalTasks==3600&&c.ExpectedGroups==120&&c.TotalTrueEvaluationBudget==1800000);
assert(c.IGDReferenceRequest==10000&&c.DiagnosticIGDReferenceRequest==2000);
assert(c.PrimaryHVReference==1.1&&isequal(c.HVReferences(:)',[1.1,3,20]));
assert(~c.AutomaticRetry&&~c.StopByHistoricalIGD&&~c.ImportExistingRuns&&c.CSASSRuns==0);
lock=m8_io('json',fullfile(root,'source_lock.json'));paths=cell(numel(lock.Files),1);
for i=1:numel(lock.Files)
 f=lock.Files(i);rel=char(f.Path);paths{i}=strrep(rel,'\','/');
 assert(isempty(regexp(rel,'(^[\\/]|^[A-Za-z]:|(^|[\\/])\.\.([\\/]|$))','once')));
 file=fullfile(root,rel);assert(isfile(file),'Missing package file: %s',rel);
 assert(strcmpi(m8_io('sha',file),f.SHA256),'Source/reference changed: %s',rel);
end
assert(numel(unique(paths))==numel(paths));
required={'MAIN_MISSING8.m','protocol.json','code/m8_trial.m','code/PortableLedgerProblem.m',...
 'code/portable_setup.m','code/m8_inventory.m','code/m8_preflight.m','code/m8_metrics.m',...
 'code/m8_summarize.m','code/m8_audit_saved_sets.m','code/m8_collect.m'};
assert(all(ismember(required,paths)),'Incomplete source lock.');
assert(numel(m8_tasks(root))==3600);
for i=1:numel(c.Problems)
 for n=[2000,10000]
  a=readmatrix(fullfile(root,'references',['PF',num2str(n)],[c.Problems{i},'.csv']),'NumHeaderLines',1);
  assert(~isempty(a)&&size(a,2)==2&&all(isfinite(a),'all')&&all(max(a,[],1)>min(a,[],1)));
 end
end
fprintf('PREFLIGHT PASS: fixed3600 tasks,120 groups, five unchanged opponents, frozenPF10000. No optimization.\n');
end
