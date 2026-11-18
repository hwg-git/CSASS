function c=portable_config(root,mode)
c=struct('Mode',char(mode),'N',100,'MaxFE',500,'Pmax',20,'K',10, ...
 'ReferencePoints',2000,'HVReference',1.1,'NativeReferencePopulation',91, ...
 'PopulationPolicy','Nominal100; ANSGAIII/CTAEA actual100 for2obj,91 for3obj; other algorithms100', ...
 'Workers',6,'UseParallel',true,'WriteExcel',true,'CloseOwnedPool',true, ...
 'MaxTaskSeconds',1200,'MaxWallHours',168,'StopOnError',true,'ShardIndex',1,'ShardCount',1);
c.Output=fullfile(root,'outputs','AllBenchmarks_SelectedCandidate');
c.Problems=[arrayfun(@(i)sprintf('CF%d',i),1:10,'UniformOutput',false),arrayfun(@(i)sprintf('LIRCMOP%d',i),1:14,'UniformOutput',false)];
c.Algorithms={'ANSGAIII','HeEMOEA','MOL2SMEA','PCSAEA','CTAEA','CSASS'};
c.Dimensions=[10,20,50];c.Seeds=1:30;
switch char(mode)
 case {'formal','preflight','summarize'}
 case 'csass30',c.Algorithms={'CSASS'};c.Output=fullfile(root,'outputs','CSASS_Only');
 case {'smoke','csass_smoke'}
  c.Problems={'CF2','CF8','LIRCMOP1','LIRCMOP13'};c.Dimensions=10;c.Seeds=1;c.MaxWallHours=1;
  c.Output=fullfile(root,'validation','smoke4');
  if strcmp(mode,'csass_smoke'),c.Algorithms={'CSASS'};c.Output=fullfile(root,'validation','csass_smoke4');end
 otherwise,error('Use formal,plan,preflight,smoke,csass_smoke,summarize,drain,resume6 or selftest6.');
end
end
