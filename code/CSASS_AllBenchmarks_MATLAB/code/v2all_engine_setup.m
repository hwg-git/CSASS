function v2all_engine_setup(root)
% Load unchanged V2 and the 24 frozen, isolated mathematical benchmarks.
root=char(root);
paths={fullfile(root,'code'),fullfile(root,'benchmarks','adapter'), ...
    fullfile(root,'benchmarks','problems'),fullfile(root,'benchmarks','helpers'), ...
    fullfile(root,'engines','V2','matlab')};
for i=1:numel(paths)
    assert(isfolder(paths{i}),'Missing packaged dependency: %s',paths{i});
    addpath(paths{i},'-begin');
end
checks={ ...
    'csass_run_v2',fullfile(root,'engines','V2','matlab','csass_run_v2.m'); ...
    'csass_v2.options',fullfile(root,'engines','V2','matlab','+csass_v2','options.m'); ...
    'REVIEW_PROBLEM',fullfile(root,'benchmarks','adapter','REVIEW_PROBLEM.m'); ...
    'REVIEW_SOLUTION',fullfile(root,'benchmarks','adapter','REVIEW_SOLUTION.m'); ...
    'REVIEW_UniformPoint',fullfile(root,'benchmarks','helpers','REVIEW_UniformPoint.m'); ...
    'REVIEW_NDSort',fullfile(root,'benchmarks','helpers','REVIEW_NDSort.m')};
problems=[compose('CF%d',1:10),compose('LIRCMOP%d',1:14)];
for k=1:numel(problems)
    name=['REVIEW_',char(problems{k})];
    checks(end+1,:)={name,fullfile(root,'benchmarks','problems',[name,'.m'])}; %#ok<AGROW>
end
for i=1:size(checks,1)
    actual=which(checks{i,1});
    assert(~isempty(actual),'Dependency not found: %s',checks{i,1});
    actualFile=java.io.File(actual);expectedFile=java.io.File(checks{i,2});
    actual=char(actualFile.getCanonicalPath());expected=char(expectedFile.getCanonicalPath());
    assert(strcmpi(actual,expected),'PATH conflict for %s: %s',checks{i,1},actual);
end
end
