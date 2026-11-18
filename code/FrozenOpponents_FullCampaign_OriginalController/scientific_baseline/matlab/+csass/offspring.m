function X = offspring(P,p,o)
% Binary fitness tournament, SBX, polynomial mutation. Reconstruction choices.
N=size(P.X,1); D=p.D;
fit=csass.fitness([P.F,P.CV],zeros(size(P.CV)));
a=randi(N,2*ceil(N/2),1); b=randi(N,2*ceil(N/2),1);
selected=a; selected(fit(b)<fit(a))=b(fit(b)<fit(a));
U=(P.X(selected,:)-p.lower)./(p.upper-p.lower);
A=U(1:2:end,:); B=U(2:2:end,:);
r=rand(size(A)); eta=o.CrossoverEta;
beta=zeros(size(A)); t=r<=0.5;
beta(t)=(2*r(t)).^(1/(eta+1));
beta(~t)=(2-2*r(~t)).^(-1/(eta+1));
beta=beta.*(-1).^randi([0,1],size(beta));
beta(rand(size(beta))<0.5)=1;
beta(repmat(rand(size(A,1),1)>o.CrossoverProbability,1,D))=1;
V=[(A+B+beta.*(A-B))/2;(A+B-beta.*(A-B))/2];
V=max(0,min(1,V(1:N,:)));
site=rand(size(V))<min(1,o.MutationExpected/D);
r=rand(size(V)); eta=o.MutationEta;
left=site & r<=0.5; right=site & r>0.5;
V(left)=V(left)+(2*r(left)+(1-2*r(left)).*(1-V(left)).^(eta+1)).^(1/(eta+1))-1;
V(right)=V(right)+1-(2*(1-r(right))+2*(r(right)-0.5).*V(right).^(eta+1)).^(1/(eta+1));
V=max(0,min(1,V));
X=p.lower+V.*(p.upper-p.lower);
end
