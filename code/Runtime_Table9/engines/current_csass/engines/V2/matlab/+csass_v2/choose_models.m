function [choice,score] = choose_models(Y,R,K,previous,o)
% Thesis Algorithm 4-4. Undefined scores retain previous task choice.
m=size(Y,2)-1;
score.rbf=r2(Y,R,o.R2VarianceTolerance);
score.kriging=r2(Y,K,o.R2VarianceTolerance);
score.rbfRMSE=sqrt(mean((Y-R).^2,1));
score.krigingRMSE=sqrt(mean((Y-K).^2,1));
score.rbfMAE=mean(abs(Y-R),1);
score.krigingMAE=mean(abs(Y-K),1);
score.aggregateRBF=[mean(score.rbf(1:m)),score.rbf(end)];
score.aggregateKriging=[mean(score.kriging(1:m)),score.kriging(end)];
choice=previous;
for task=1:2
    a=score.aggregateRBF(task); b=score.aggregateKriging(task);
    if ~isnan(a) && ~isnan(b)
        if a>b, choice(task)=1;
        elseif b>a, choice(task)=2;
        end
    end
end
end

function value=r2(Y,P,tol)
% Apply a common response scale to numerator/denominator before squaring.
% Default tol=0: only zero response variance is undefined, as in the manuscript.
scale=max(abs(Y),[],1); scale(scale==0)=1;
Z=Y./scale; Q=P./scale;
ss=sum((Z-mean(Z,1)).^2,1);
value=1-sum((Z-Q).^2,1)./ss;
undefined=ss==0;
if tol>0, undefined=undefined | ss<=tol*sum(Z.^2,1); end
value(undefined)=NaN;
end
