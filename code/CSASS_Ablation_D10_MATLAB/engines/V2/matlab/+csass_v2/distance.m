function D = distance(X,Y)
% Euclidean row distances; no Statistics Toolbox dependency.
D = sqrt(max(0,sum(X.^2,2)+sum(Y.^2,2)'-2*(X*Y')));
if isequal(X,Y), D(1:size(D,1)+1:end)=0; end
end
