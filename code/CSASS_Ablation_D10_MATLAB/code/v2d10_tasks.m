function tasks=v2d10_tasks(~)
% Fixed 30-group ablation; only predefined completed cache groups excluded.
% IDs include model-selection mode; no seed/result-dependent filtering.
problems={'CF2','CF7','LIRCMOP1','LIRCMOP7','CF8','LIRCMOP13'};
modes={'adaptive','rbf_only','kriging_only',...
    'fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'};
template=struct('ID','','Version','V2','Problem','','D',0,'Seed',0,...
    'Mode','','N',100,'MaxFE',500,'Pmax',20,'K',10);
tasks=repmat(template,540,1);n=0;
for p=1:numel(problems)
    for d=10
        for m=1:numel(modes)
            cached=d==10 && (ismember(problems{p},{'CF7','LIRCMOP7'}) ||...
                (ismember(problems{p},{'CF2','LIRCMOP1'}) && strcmp(modes{m},'adaptive')));
            if cached,continue;end
            for seed=1:30
                n=n+1;tasks(n)=template;tasks(n).Problem=problems{p};
                tasks(n).D=d;tasks(n).Mode=modes{m};tasks(n).Seed=seed;
                tasks(n).ID=sprintf('V2_%s_D%d_%s_seed%02d',problems{p},d,modes{m},seed);
            end
        end
    end
end
assert(n==540 && numel(unique({tasks.ID}))==540,'V2_Ablation_D10:TaskCount','Fixed task manifest changed.');
end
