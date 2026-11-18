function ids = novel(X,seen,lower,upper,tol)
% Reject near-duplicate normalized decisions, including within this batch.
range=upper-lower;
U=(X-lower)./range; V=(seen-lower)./range;
ids=zeros(0,1);
for i=1:size(U,1)
    if isempty(V) || all(max(abs(V-U(i,:)),[],2)>tol)
        ids(end+1,1)=i; %#ok<AGROW>
        V(end+1,:)=U(i,:); %#ok<AGROW>
    end
end
end
