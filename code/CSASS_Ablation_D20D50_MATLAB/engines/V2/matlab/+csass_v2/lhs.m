function U = lhs(n,d)
% One random point in each marginal stratum. Uses the caller's RNG stream.
U = zeros(n,d);
for j=1:d
    U(:,j) = (randperm(n)'-rand(n,1))/n;
end
end
