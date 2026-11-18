function [ids,stats] = inner_pareto(Q,p,o)
% Only inner surrogate environment uses ordinary Pareto on [F,CV].
% Zero external CV selects the existing environment's ordinary Pareto path;
% actual and predicted CV stored in Q are unchanged. No dedup or random calls.
n=size(Q.X,1);G=[Q.F,Q.CV];ids=csass.environment(G,zeros(n,1),o.N);
uniqueBefore=numel(csass.novel(Q.X,zeros(0,p.D),p.lower,p.upper,o.DuplicateTolerance));
uniqueAfter=numel(csass.novel(Q.X(ids,:),zeros(0,p.D),p.lower,p.upper,o.DuplicateTolerance));
assert(numel(ids)==o.N && numel(unique(ids))==o.N && all(Q.CV>=0));
stats=[n,uniqueBefore,o.N,uniqueAfter,sum(Q.CV(ids)>0),sum(Q.CV==0)];
end
