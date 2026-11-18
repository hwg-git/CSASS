function VALIDATE_PACKAGE
% No optimization or model fitting. Benchmark points and artificial IO fixtures only.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'));vroot=fullfile(root,'validation','attempt02');
MAIN_CSASS_ALL('plan');MAIN_CSASS_ALL('selftest6');
c=portable_config(root,'formal');c.Output=fullfile(vroot,'preflight');
portable_preflight(root,c);portable_setup(root,'CSASS');
fixtures=cell(72,6);row=0;
for pi=1:numel(c.Problems)
 for d=c.Dimensions
  name=c.Problems{pi};a=feval(name,'D',d,'N',100,'maxFE',500);b=PortableLedgerProblem(name,d,100,500);
  X=(a.lower+a.upper)/2;s=a.Evaluation(X);t=b.Evaluation(X);
  assert(all(isfinite(s.objs),'all')&&all(isfinite(s.cons),'all')&&isequal(s.objs,t.objs)&&isequal(s.cons,t.cons));
  assert(isequal(b.H.CV,sum(max(0,s.cons),2))&&b.FE==1&&b.InitialN==1);
  row=row+1;fixtures(row,:)={name,d,b.M,size(s.cons,2),1,true};
 end
end
assert(row==72);writetable(cell2table(fixtures,'VariableNames',{'Problem','D','M','ConstraintCount','WrapperFixtureRows','ExactMatch'}),fullfile(vroot,'benchmark_fixture_checks.csv'));
for alg=c.Algorithms
 portable_setup(root,alg{1});
 if strcmp(alg{1},'CSASS'),assert(strcmp(which('csass_run'),fullfile(root,'scientific_baseline','matlab','csass_run.m')));
 else,a=feval(alg{1},'save',1,'outputFcn',@(~,~)[]);assert(strcmp(class(a),alg{1}));end
end
portable_setup(root,'CSASS');
s=csass.metrics([0,1;1,0],[0,1;1,0],[1.1,1.1]);assert(s.IGD==0&&abs(s.HV-.21)<1e-12);
s=csass.metrics([0,1,1;1,0,1;1,1,0],[0,1,1;1,0,1;1,1,0],[1.1,1.1,1.1]);assert(s.IGD==0&&abs(s.HV-.031)<1e-12);
fixture=portable_config(root,'formal');fixture.Output=fullfile(vroot,'ARTIFICIAL_NOT_EXPERIMENTS');fixture.Problems={'CF2'};fixture.Dimensions=10;fixture.Algorithms={'ANSGAIII','CTAEA','CSASS'};
assert(~isfolder(fixture.Output),'Preserve earlier validation.');mkdir(fullfile(fixture.Output,'runs'));
for seed=1:30
 for ai=1:3
  alg=fixture.Algorithms{ai};id=sprintf('%s_CF2_D10_seed%02d',alg,seed);dest=fullfile(fixture.Output,'runs',id);mkdir(dest);
  igd=2+seed/100;hv=.1+seed/1000;nf=false;nd=10;
  if strcmp(alg,'CSASS'),igd=1+seed/100;hv=.2+seed/1000;elseif strcmp(alg,'CTAEA'),igd=Inf;hv=0;nf=true;nd=0;end
  r=struct('ID',id,'Status','completed','Algorithm',alg,'Problem','CF2','D',10,'Seed',seed,'M',2,'NominalN',100,'ActualN',100,'InitialN',100,'FE',500,'IGD',igd,'NonfiniteIGD',nf,'HV',hv,'HVRef1p5',hv+.1,'HVRef2p0',hv+.2,'FeasibleND',nd,'PositiveCVSamples',0,'HVExcludedCount',0,'RuntimeSeconds',0,'ElapsedWithExportsSeconds',0,'NativeSavedFE',500,'ReferenceCount',2000,'Outcome','ARTIFICIAL_IO_FIXTURE','ArtificialFixture',true);
  portable_write_json(fullfile(dest,'result.json'),r);portable_write_json(fullfile(dest,'completed.json'),struct('ArtificialFixture',true));
  if strcmp(alg,'CSASS')
   z=ones(40,13);z(:,1)=(1:40)';z(:,2)=(100:10:490)';z(:,3)=(110:10:500)';
   portable_write_csv(fullfile(dest,'model_selection.csv'),cellstr(compose('column%d',1:13)),z);
  end
 end
end
portable_summarize(root,fixture,0);
G=readtable(fullfile(fixture.Output,'tables','complete30_summary.csv'));
assert(height(G)==3&&all(G.NCompleted==30));a=G(strcmp(G.Algorithm,'CSASS'),:);assert(abs(a.IGDMean30-1.155)<1e-12);
a=G(strcmp(G.Algorithm,'CTAEA'),:);assert(isinf(a.IGDMean30)&&isnan(a.IGDStd30)&&a.NoFeasibleSetRuns==30);
S=readtable(fullfile(fixture.Output,'tables','statistical_comparisons.csv'));assert(height(S)==4&&all(strcmp(S.Symbol,'+')));
assert(isfile(fullfile(fixture.Output,'tables','RESULTS.xlsx')));readcell(fullfile(fixture.Output,'tables','RESULTS.xlsx'),'Sheet','CF_2obj_IGD');
report=struct('Status','pass','OptimizationRuns',0,'ModelFits',0,'FormalTasks',12960,'Problems',24,'Dimensions',[10,20,50],'SeedsPerGroup',30,'Algorithms',6,'BenchmarkFixturePointPairs',72,'WrapperAndDirectProblemExactMatch',true,'MetricFixtures2and3Objective',true,'FiveComparatorClassesAndCSASSFunctionResolved',true,'ResumeControlSelftest',true,'ArtificialIOFixtureGroups',3,'CSVAndExcelExport',true,'StatisticsFixture',true,'RequestedWorkers',6,'ActualSixProcessExecutionTestedHere',false,'MATLAB',version);
portable_write_json(fullfile(root,'VALIDATION_REPORT.json'),report);fprintf('VALIDATE_PACKAGE_PASS: no optimization/model fitting;12960-task plan and IO checked.\n');
end
