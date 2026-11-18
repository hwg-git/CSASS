function P = predict(models,X,p,choice,H,o)
[R,K]=csass_v2.predict_models(models,X,p);
Y=R;
if choice(1)==2, Y(:,1:p.M)=K(:,1:p.M); end
if choice(2)==2, Y(:,end)=K(:,end); end
F=Y(:,1:p.M); CV=abs(Y(:,end));
% Restore actual responses for decisions that have already been evaluated.
U=(X-p.lower)./(p.upper-p.lower);
V=(H.X-p.lower)./(p.upper-p.lower);
for i=1:size(X,1)
    k=find(max(abs(V-U(i,:)),[],2)<=o.DuplicateTolerance,1);
    if ~isempty(k), F(i,:)=H.F(k,:); CV(i)=H.CV(k); end
end
P=struct('X',X,'F',F,'CV',CV);
end
