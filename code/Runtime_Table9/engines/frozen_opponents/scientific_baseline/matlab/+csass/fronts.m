function rank = fronts(F,CV)
dom = csass.dominance(F,CV);
n = size(F,1); rank = zeros(n,1); remaining = true(n,1); level=0;
while any(remaining)
    level = level+1;
    ids = find(remaining);
    first = ids(~any(dom(ids,ids),1));
    assert(~isempty(first),'Invalid dominance graph.');
    rank(first)=level;
    remaining(first)=false;
end
end
