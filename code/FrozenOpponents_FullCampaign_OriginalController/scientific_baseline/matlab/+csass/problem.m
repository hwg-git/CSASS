function p = problem(name,D)
% CF1--CF10 and LIRCMOP1--LIRCMOP14, pinned official benchmark definitions.
if nargin<2, D=10; end
name = upper(char(name));
valid = [compose('CF%d',1:10),compose('LIRCMOP%d',1:14)];
assert(any(strcmp(name,valid)),'Unknown benchmark name.');
validateattributes(D,{'numeric'},{'scalar','integer','>=',4});
b = feval(name);
b.D = D;
b.Setting();
p = struct('name',name,'D',b.D,'M',b.M,'lower',b.lower, ...
    'upper',b.upper,'evaluate',@(X)evaluate(b,X), ...
    'reference',@(n)b.GetOptimum(n));
end

function [F,G] = evaluate(b,X)
assert(size(X,2)==b.D && all(isfinite(X),'all'));
assert(all(X>=b.lower-1e-12 & X<=b.upper+1e-12,'all'));
P = b.Evaluation(X);
F = vertcat(P.objs);
G = vertcat(P.cons);
assert(size(F,1)==size(X,1) && all(isfinite(F),'all'));
assert(size(G,1)==size(X,1) && all(isfinite(G),'all'));
end
