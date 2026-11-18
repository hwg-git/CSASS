function P = REVIEW_SOLUTION(X,F,G,varargin) %#ok<INUSD>
% Row-wise containers sufficient for benchmark Evaluation methods only.
assert(size(X,1)==size(F,1) && size(X,1)==size(G,1));
P = struct('decs',num2cell(X,2),'objs',num2cell(F,2), ...
           'cons',num2cell(G,2));
end
