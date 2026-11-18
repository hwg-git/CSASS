function tasks=v2all_tasks(~)
% Fixed manifest: all 72 V2 cells, excluding seven completed D10 caches.
% This exclusion is independent of scores and never selects individual seeds.
problems=[arrayfun(@(x)sprintf('CF%d',x),1:10,'UniformOutput',false),...
    arrayfun(@(x)sprintf('LIRCMOP%d',x),1:14,'UniformOutput',false)];
cached={'CF2','CF7','LIRCMOP1','LIRCMOP2','LIRCMOP3','LIRCMOP4','LIRCMOP7'};
template=struct('ID','','Version','V2','Problem','','D',0,'Seed',0,...
    'Mode','adaptive','N',100,'MaxFE',500,'Pmax',20,'K',10);
tasks=repmat(template,1950,1);n=0;
for p=1:numel(problems)
    for d=[10,20,50]
        if d==10 && ismember(problems{p},cached),continue;end
        for seed=1:30
            n=n+1;tasks(n)=template;tasks(n).Problem=problems{p};
            tasks(n).D=d;tasks(n).Seed=seed;
            tasks(n).ID=sprintf('V2_%s_D%d_seed%02d',problems{p},d,seed);
        end
    end
end
assert(n==1950 && numel(unique({tasks.ID}))==1950,'V2_AllBenchmarks:TaskCount','Fixed task manifest changed.');
end
