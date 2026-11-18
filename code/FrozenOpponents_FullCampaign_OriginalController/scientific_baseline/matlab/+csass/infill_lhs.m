function [X,nSupplement,log] = infill_lhs(P,models,choice,H,p,o,K)
% Diagnostic fallback: when fewer than K novel population points exist,
% generate one N-sized LHS pool instead of up to five extra GA batches.
% Novelty tolerance, model choice and true budget unchanged; see infill rank below.
novel=csass.novel(P.X,H.X,p.lower,p.upper,o.DuplicateTolerance);
C=csass.subset(P,novel);initial=size(C.X,1);source=zeros(initial,1);
nSupplement=0;raw=zeros(0,p.D);
if initial<K
 raw=p.lower+csass.lhs(max(o.N,K),p.D).*(p.upper-p.lower);
 ids=csass.novel(raw,[H.X;C.X],p.lower,p.upper,o.DuplicateTolerance);
 extra=csass.predict(models,raw(ids,:),p,choice,H,o);
 C.X=[C.X;extra.X];C.F=[C.F;extra.F];C.CV=[C.CV;extra.CV];
 source=[source;ones(numel(ids),1)];nSupplement=numel(ids);
end
assert(size(C.X,1)>=K,'Cannot select a full novel batch.');
% Diagnostic change ONLY at K-point infill: ordinary Pareto on [F,CV].
G=[C.F,C.CV];zeroCV=zeros(size(C.CV));
rank=csass.fronts(G,zeroCV);fit=csass.fitness(G,zeroCV);
[~,ids]=sortrows([rank,fit,(1:numel(rank))'],[1,2,3]);selected=ids(1:K);
X=C.X(selected,:);order=zeros(size(C.X,1),1);order(selected)=(1:K)';
log=struct('initialNovel',initial,'generatedLHS',size(raw,1),...
 'acceptedLHS',nSupplement,'selectedPopulation',sum(source(selected)==0),...
 'selectedLHS',sum(source(selected)==1),'candidateX',C.X,'candidateF',C.F,...
 'candidateCV',C.CV,'source',source,'rank',rank,'fitness',fit,...
 'selectedOrder',order,'rawLHS',raw);
end
