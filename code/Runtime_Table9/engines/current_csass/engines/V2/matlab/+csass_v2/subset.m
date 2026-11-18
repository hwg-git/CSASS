function Q = subset(P,ids)
Q=P;
for f={'X','F','G','CV','Stage','EvaluationID'}
    if isfield(P,f{1}), Q.(f{1})=P.(f{1})(ids,:); end
end
end
