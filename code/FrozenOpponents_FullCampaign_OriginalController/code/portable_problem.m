function p=portable_problem(b,name)
% Full-engine bridge preserves the standalone scientific csass_run unchanged.
p=struct('name',char(name),'D',b.D,'M',b.M,'lower',b.lower,'upper',b.upper, ...
 'evaluate',@(X)evaluate(b,X),'reference',@(N)b.Base.GetOptimum(N));
end
function [F,G]=evaluate(b,X)
assert(all(X>=b.lower-1e-12&X<=b.upper+1e-12,'all'));s=b.Evaluation(X);F=s.objs;G=s.cons;
end
