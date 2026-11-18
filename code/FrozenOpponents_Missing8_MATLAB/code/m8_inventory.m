function inv=m8_inventory(root,tasks,fullHash)
if nargin<3,fullHash=false;end
assert(isequal(tasks,m8_tasks(root)),'Use the complete fixed manifest.');
c=m8_config(root);lockHash=m8_io('sha',fullfile(root,'source_lock.json'));
n=numel(tasks);done=false(n,1);retained=false(n,1);ids={};
runs=fullfile(c.Output,'runs');
if isfolder(runs)
 d=dir(runs);names={d([d.isdir]).name};extra=setdiff(names,[{'.','..'},{tasks.ID}]);
 assert(isempty(extra),'Unexpected run folders: %s',strjoin(extra,', '));
end
required={'result.json','result.mat','precision_ledger.csv','final_decisions.csv',...
 'final_objectives.csv','final_constraints.csv','initial_decisions.csv','native_final.csv','configuration.json'};
for i=1:n
 dest=fullfile(runs,tasks(i).ID);marker=fullfile(dest,'completed.json');
 if isfile(marker)
  m=m8_io('json',marker);
  assert(strcmp(m.Status,'completed')&&m.FE==500&&m.InitialN==100&&strcmp(m.SourceCodeLockSHA256,lockHash));
  for f={'ID','Algorithm','Problem','D','M','Seed'}
   assert(isequal(m.(f{1}),tasks(i).(f{1})),'Task identity changed: %s',marker);
  end
  assert(numel(m.Files)==numel(required)&&isequal(sort({m.Files.Path}),sort(required)));
  for j=1:numel(m.Files)
   file=fullfile(dest,m.Files(j).Path);assert(isfile(file),'Missing saved artifact: %s',file);
   if fullHash,assert(strcmpi(m8_io('sha',file),m.Files(j).SHA256),'Modified saved artifact: %s',file);end
  end
  done(i)=true;
 elseif isfolder(dest)||isfile(dest)
  retained(i)=true;ids{end+1}=tasks(i).ID; %#ok<AGROW>
 end
end
inv=struct('Planned',n,'Completed',sum(done),'Retained',sum(retained),'Pending',sum(~done&~retained),...
 'CompletedMask',done,'RetainedMask',retained,'PendingMask',~done&~retained,'RetainedIDs',{ids});
end
