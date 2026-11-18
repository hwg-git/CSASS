function result = abl2050_engine(root,task,userOptions)
% Run a fixed audited complete engine; this function owns no campaign loop.
% EvaluationCallback(X,F,G) is for recording only, outside scientific options.
if nargin<3 || isempty(userOptions),userOptions=struct();end
assert(isstruct(userOptions)&&isscalar(userOptions),'Options must be a scalar struct.');
abl2050_engine_setup(root);
assert(isfield(task,'Version')&&isfield(task,'Problem')&&isfield(task,'D')&&isfield(task,'Seed'));
engine=char(task.Version);name=upper(char(task.Problem));
assert(strcmp(engine,'V2'),'This campaign runs only the frozen V2 engine.');
valid={'CF2','CF7','LIRCMOP1','LIRCMOP7','CF8','LIRCMOP13'};
assert(any(strcmp(name,valid))&&isscalar(task.D)&&ismember(task.D,[20,50]),'Only the six fixed ablation benchmarks at D20/D50 are allowed.');
validateattributes(task.Seed,{'numeric'},{'scalar','integer','>=',1,'<=',30});
modes={'adaptive','rbf_only','kriging_only','fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'};
assert(isfield(task,'Mode') && any(strcmp(task.Mode,modes)),'Unknown ablation mode.');
assert(strcmp(task.ID,sprintf('V2_%s_D%d_%s_seed%02d',name,task.D,task.Mode,task.Seed)),'Task ID does not match problem/dimension/mode/seed.');
fixedTask={'N',100;'MaxFE',500;'Pmax',20;'K',10};
for i=1:size(fixedTask,1)
    if isfield(task,fixedTask{i,1})
        assert(isequal(task.(fixedTask{i,1}),fixedTask{i,2}),'Task setting is locked: %s',fixedTask{i,1});
    end
end
callback=[];
if isfield(userOptions,'EvaluationCallback')
    callback=userOptions.EvaluationCallback;
    assert(isempty(callback)||isa(callback,'function_handle'),'EvaluationCallback must be a function handle.');
    userOptions=rmfield(userOptions,'EvaluationCallback');
end
requested=struct('N',100,'MaxFE',500,'Pmax',20,'K',10,'Seed',task.Seed, ...
    'Mode',task.Mode,'RBFKernel','multiquadric','ReferencePoints',2000, ...
    'OutputDirectory','','Verbose',false);
fixed=csass_v2.options(requested);
fields=fieldnames(userOptions);
for i=1:numel(fields)
    key=fields{i};
    assert(isfield(fixed,key)&&isequaln(userOptions.(key),fixed.(key)), ...
        'Scientific setting is locked or unknown: %s',key);
end
p=csass_v2.problem(name,task.D);
evaluateBase=p.evaluate;
if ~isempty(callback),p.evaluate=@evaluate_recorded;end
result=csass_run_v2(p,fixed);
assert(result.FE==500&&size(result.history.X,1)==500&&numel(result.stages)==40);
assert(size(result.initialX,1)==100&&result.options.K==10);
assert(strcmp(result.options.Mode,task.Mode),'Returned engine mode mismatch.');
assert(~isfield(result.options,'EvaluationCallback'));
    function [F,G]=evaluate_recorded(X)
        [F,G]=evaluateBase(X);
        beforeCallback=rng;
        restoreRNG=onCleanup(@()rng(beforeCallback)); %#ok<NASGU>
        callback(X,F,G);
    end
end
