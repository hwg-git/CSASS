function models = train_models(A,p,o)
% Thesis Algorithm 4-2. A contains ONLY true-evaluated observations.
U=2*(A.X-p.lower)./(p.upper-p.lower)-1;
Y=[A.F,A.CV];
models=struct('X',U,'M',p.M,'trainingX',A.X, ...
    'trainingEvaluationIDs',A.EvaluationID,'RBF',[], ...
    'Kriging',{cell(1,p.M+1)},'rbfRank',0);
models.RBF=rbf_fit(U,Y,o);
models.rbfRank=models.RBF.rank;
for j=1:size(Y,2)
    models.Kriging{j}=kriging_fit(U,Y(:,j),o);
end
end

function m=rbf_fit(U,Y,o)
center=mean(Y,1); scale=std(Y,0,1);
scale(scale==0)=1;
Z=(Y-center)./scale;
D=csass_v2.distance(U,U); Phi=kernel(D,o.RBFKernel,o.RBFShape);
[L,S,V]=svd(Phi,'econ'); s=diag(S);
cut=max(size(Phi))*eps(max(s)); keep=s>cut;
if o.RBFRidge==0
    % Minimum-norm solve also handles literal r^2's low rank explicitly.
    coefficients=V(:,keep)*((L(:,keep)'*Z)./s(keep));
else
    coefficients=(Phi+o.RBFRidge*eye(size(Phi)))\Z;
end
m=struct('X',U,'center',center,'scale',scale,'coefficients',coefficients, ...
    'kernel',o.RBFKernel,'shape',o.RBFShape,'rank',sum(keep), ...
    'trainingCount',size(U,1));
end

function Phi=kernel(D,name,c)
switch name
    case 'quadratic', Phi=D.^2;
    case 'multiquadric', Phi=sqrt(D.^2+c^2);
    case 'cubic', Phi=D.^3;
    otherwise, error('Unsupported RBF kernel.');
end
end

function m=kriging_fit(X,y,o)
center=mean(y); scale=std(y);
if scale==0
    m=struct('constant',true,'center',center,'scale',1,'X',X, ...
        'theta',ones(1,size(X,2)),'beta',0,'alpha',zeros(size(y)), ...
        'nugget',o.KrigingNugget,'exitflag',0,'nll',0);
    return;
end
z=(y-center)/scale; d=size(X,2);
dist=zeros(size(X,1),size(X,1),d);
for j=1:d, dist(:,:,j)=abs(X(:,j)-X(:,j)'); end
lo=log(o.KrigingThetaMin); hi=log(o.KrigingThetaMax);
theta0=ones(1,d)/d;
theta0=max(o.KrigingThetaMin*1.01,min(o.KrigingThetaMax/1.01,theta0));
q0=(log(theta0)-lo)/(hi-lo); v0=log(q0./(1-q0));
settings=optimset('Display','off','MaxFunEvals',o.KrigingMaxFunEvals, ...
    'MaxIter',o.KrigingMaxIter,'TolX',1e-3,'TolFun',1e-5);
objective=@(v)likelihood(exp(lo+(hi-lo)./(1+exp(-v))),dist,z,o.KrigingNugget);
[v,value,flag]=fminsearch(objective,v0,settings);
theta=exp(lo+(hi-lo)./(1+exp(-v)));
[~,state]=likelihood(theta,dist,z,o.KrigingNugget);
assert(isfield(state,'alpha') && all(isfinite(state.alpha)),'Kriging fit failed.');
m=struct('constant',false,'center',center,'scale',scale,'X',X, ...
    'theta',theta,'beta',state.beta,'alpha',state.alpha, ...
    'nugget',state.nugget,'exitflag',flag,'nll',value);
end

function [nll,state]=likelihood(theta,dist,z,nugget)
n=numel(z); state=struct();
R=exp(-sum(dist.*reshape(theta,1,1,[]),3));
flag=1;
for attempt=1:7
    [L,flag]=chol(R+nugget*eye(n),'lower');
    if flag==0, break; end
    nugget=nugget*10;
end
if flag~=0, nll=realmax/100; return; end
one=ones(n,1); a=L'\(L\one); b=L'\(L\z);
beta=(one'*b)/(one'*a); residual=z-beta;
alpha=L'\(L\residual); sigma2=max(realmin,(residual'*alpha)/n);
nll=n*log(sigma2)+2*sum(log(diag(L)));
state=struct('beta',beta,'alpha',alpha,'nugget',nugget);
end
