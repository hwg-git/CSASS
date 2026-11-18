function receipt=m8_selftest(root)
% Synthetic file/metrics/controller checks; no objective calls, fitting, or pool.
tasks=m8_tasks(root);assert(numel(tasks)==3600&&numel(unique({tasks.ID}))==3600);
groups=strcat(string({tasks.Problem}),"_D",string([tasks.D]),"_",string({tasks.Algorithm}));
[~,~,g]=unique(groups);assert(numel(unique(groups))==120&&all(accumarray(g(:),1)==30));
assert(all([tasks.N]==100)&&all([tasks.MaxFE]==500)&&all([tasks.M]==2));
work=fullfile(root,'qa',['selftest_',char(java.util.UUID.randomUUID)]);mkdir(work);
metrics=m8_metrics_fixture(fullfile(work,'metrics_fixture'));
copyfile(fullfile(root,'protocol.json'),fullfile(work,'protocol.json'));
copyfile(fullfile(root,'source_lock.json'),fullfile(work,'source_lock.json'));
lockHash=m8_io('sha',fullfile(work,'source_lock.json'));
out=fullfile(work,'outputs','Missing8_Opponents','runs');mkdir(out);
files={'result.json','result.mat','precision_ledger.csv','final_decisions.csv','final_objectives.csv',...
 'final_constraints.csv','initial_decisions.csv','native_final.csv','configuration.json'};
dest=fullfile(out,tasks(1).ID);mkdir(dest);list=repmat(struct('Path','','SHA256',''),numel(files),1);
for i=1:numel(files)
 f=fullfile(dest,files{i});fid=fopen(f,'w');assert(fid>=0);fprintf(fid,'synthetic fixture, not experimental data\n');fclose(fid);
 list(i)=struct('Path',files{i},'SHA256',m8_io('sha',f));
end
m=tasks(1);m.Status='completed';m.FE=500;m.InitialN=100;m.SourceCodeLockSHA256=lockHash;m.Files=list;
m8_io('writejson',fullfile(dest,'completed.json'),m);
mkdir(fullfile(out,tasks(2).ID));mkdir(fullfile(out,tasks(3).ID));
m8_io('writejson',fullfile(out,tasks(2).ID,'failure.json'),struct('Status','failed','Fixture',true));
inv=m8_inventory(work,tasks,true);
assert(inv.Completed==1&&inv.Retained==2&&inv.Pending==3597);
assert(~any(inv.PendingMask(1:3))&&all(inv.PendingMask(4:end)));
f=fullfile(dest,'final_objectives.csv');fid=fopen(f,'a');fprintf(fid,'changed\n');fclose(fid);
rejected=false;try,m8_inventory(work,tasks,true);catch,rejected=true;end
assert(rejected,'Modified completed artifact was not rejected.');
% Atomic replacement keeps file present and changes JSON content.
j=fullfile(work,'atomic.json');m8_io('writejson',j,struct('Value',1));m8_io('writejson',j,struct('Value',2));
v=m8_io('json',j);assert(v.Value==2);
% OS file lock rejects a second owner and releases without deleting evidence.
file=java.io.RandomAccessFile(fullfile(work,'fixture.lock'),'rw');lock=file.getChannel().tryLock();
assert(~isempty(lock));second=java.io.RandomAccessFile(fullfile(work,'fixture.lock'),'rw');busy=false;
try,l2=second.getChannel().tryLock();busy=isempty(l2);catch,busy=true;end
assert(busy);second.close();lock.release();file.close();
receipt=struct('Status','pass','TaskCount',3600,'Groups',120,'SyntheticCompleted',1,'Retained',2,...
 'NeverStarted',3597,'TamperRejected',true,'AtomicReplacementPass',true,'LockPass',true,...
 'Metrics',metrics,'OptimizationRuns',0,'TrueEvaluations',0,'ModelFits',0,'PoolsStarted',0,'FixtureRoot',work);
m8_io('writejson',fullfile(work,'selftest_receipt.json'),receipt);
fprintf('SELFTEST PASS: fixed manifest, metrics, retained trials, tamper rejection, atomic writes, locking; zero evaluations.\n');
end
