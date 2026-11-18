function report=abl2050_validate_references(root)
% Reference-front validation only: never call Evaluation or an optimizer.
abl2050_engine_setup(root);
before=rng;restore=onCleanup(@()rng(before)); %#ok<NASGU>
checks=repmat(struct('Problem','','Requested',0,'ActualRows',0,'Objectives',0,'MaxAbsoluteDifference',0),12,1);
dimensionChecks=repmat(struct('Problem','','D',0,'M',0,'FactoryBoundsMatch',false),12,1);
index=0;
dimensionIndex=0;problems=["CF2","CF7","LIRCMOP1","LIRCMOP7","CF8","LIRCMOP13"];
for problem=1:numel(problems)
    name=char(problems{problem});
    expectedM=2;
    if any(strcmp(name,{'CF8','CF9','CF10','LIRCMOP13','LIRCMOP14'})),expectedM=3;end
    for D=[20,50]
        p=csass_v2.problem(name,D);b=feval(['REVIEW_',name]);b.D=D;b.Setting();
        assert(p.D==D&&b.D==D&&p.M==expectedM&&b.M==expectedM,'Unexpected problem dimensions: %s D%d',name,D);
        assert(numel(p.lower)==D&&numel(p.upper)==D&&all(p.upper>p.lower));
        assert(isequal(p.lower,b.lower)&&isequal(p.upper,b.upper)&&b.FE==0);
        dimensionIndex=dimensionIndex+1;
        dimensionChecks(dimensionIndex)=struct('Problem',name,'D',D,'M',p.M,'FactoryBoundsMatch',true);
    end
    b=feval(['REVIEW_',name]);b.D=20;b.Setting();initialFE=b.FE;
    for requested=[2000,10000]
        expected=b.GetOptimum(requested);
        file=fullfile(root,'references',sprintf('PF%d',requested),[name,'.csv']);
        saved=readmatrix(file,'NumHeaderLines',1);
        assert(isequal(size(saved),size(expected)),'Reference-front shape mismatch: %s',file);
        assert(all(isfinite(saved),'all'),'Nonfinite reference front: %s',file);
        delta=max(abs(saved-expected),[],'all');
        assert(delta<=5e-13,'Reference-front values mismatch: %s (%.17g)',file,delta);
        assert(b.FE==initialFE,'Reference validation must not evaluate candidates.');
        index=index+1;
        checks(index)=struct('Problem',name,'Requested',requested, ...
            'ActualRows',size(saved,1),'Objectives',size(saved,2),'MaxAbsoluteDifference',delta);
    end
end
assert(isequal(rng,before),'Reference generation unexpectedly changed RNG state.');
assert(index==12&&dimensionIndex==12);
report=struct('Status','pass','OptimizationRuns',0,'TrueEvaluations',0, ...
    'Checks',checks,'DimensionChecks',dimensionChecks,'Tolerance',5e-13);
end
