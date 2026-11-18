function [RBF,Kriging] = predict_models(models,X,p)
U=2*(X-p.lower)./(p.upper-p.lower)-1;
m=models.RBF; D=csass.distance(U,m.X);
switch m.kernel
    case 'quadratic', Phi=D.^2;
    case 'multiquadric', Phi=sqrt(D.^2+m.shape^2);
    case 'cubic', Phi=D.^3;
end
RBF=(Phi*m.coefficients).*m.scale+m.center;
Kriging=zeros(size(RBF));
for j=1:size(Kriging,2)
    k=models.Kriging{j};
    if k.constant
        Kriging(:,j)=k.center;
    else
        C=zeros(size(U,1),size(k.X,1));
        for d=1:size(U,2), C=C+k.theta(d)*abs(U(:,d)-k.X(:,d)'); end
        Kriging(:,j)=k.center+k.scale*(k.beta+exp(-C)*k.alpha);
    end
end
assert(all(isfinite(RBF),'all') && all(isfinite(Kriging),'all'), ...
    'Nonfinite surrogate prediction; run aborted rather than silently repaired.');
end
