function o = options(user)
% Thesis-supported defaults plus explicitly recorded reconstruction choices.
o = struct('N',100,'MaxFE',500,'Pmax',20,'K',10,'Seed',1, ...
    'Mode','adaptive','RBFKernel','quadratic','RBFShape',1, ...
    'RBFRidge',0,'KrigingMaxFunEvals',120,'KrigingMaxIter',80, ...
    'KrigingThetaMin',1e-3,'KrigingThetaMax',1e2, ...
    'KrigingNugget',1e-10,'CrossoverProbability',1, ...
    'CrossoverEta',20,'MutationExpected',1,'MutationEta',20, ...
    'FeasibilityTolerance',0,'DuplicateTolerance',1e-10, ...
    'R2VarianceTolerance',0,'ReferencePoints',2000, ...
    'HVReference',[],'OutputDirectory','','Verbose',true);
if nargin>0
    keys = fieldnames(user);
    for i=1:numel(keys)
        assert(isfield(o,keys{i}),'Unknown option: %s',keys{i});
        o.(keys{i}) = user.(keys{i});
    end
end
for f={'N','MaxFE','Pmax','K','Seed','KrigingMaxFunEvals','KrigingMaxIter','ReferencePoints'}
    validateattributes(o.(f{1}),{'numeric'},{'scalar','integer','nonnegative'});
end
assert(o.N>=4 && o.MaxFE>=o.N && o.K>=2 && o.Pmax>=1);
assert(o.KrigingMaxFunEvals>=1 && o.KrigingMaxIter>=1 && o.ReferencePoints>=10);
assert(o.KrigingThetaMin>0 && o.KrigingThetaMax>o.KrigingThetaMin);
assert(o.KrigingNugget>0 && o.RBFRidge>=0 && o.RBFShape>0);
assert(o.DuplicateTolerance>0 && o.FeasibilityTolerance>=0);
assert(o.R2VarianceTolerance>=0);
assert(o.CrossoverProbability>=0 && o.CrossoverProbability<=1);
assert(o.CrossoverEta>0 && o.MutationEta>0 && o.MutationExpected>=0);
assert(any(strcmp(o.Mode,{'adaptive','rbf_only','kriging_only', ...
    'fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'})));
assert(any(strcmp(o.RBFKernel,{'quadratic','multiquadric','cubic'})));
end
