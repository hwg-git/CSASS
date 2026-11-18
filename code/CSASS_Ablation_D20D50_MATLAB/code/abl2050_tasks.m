function tasks=abl2050_tasks(~)
% Fixed D20/D50 extension. No D10 tasks, adaptive imports fill the same IDs.
problems={'CF2','CF7','LIRCMOP1','LIRCMOP7','CF8','LIRCMOP13'};
modes={'adaptive','rbf_only','kriging_only','fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'};
template=struct('ID','','Version','V2','Problem','','D',0,'Seed',0,...
 'Mode','','N',100,'MaxFE',500,'Pmax',20,'K',10);
tasks=repmat(template,1800,1);n=0;
for p=1:numel(problems)
 for d=[20,50]
  for m=1:numel(modes)
   for seed=1:30
    n=n+1;tasks(n)=template;tasks(n).Problem=problems{p};
    tasks(n).D=d;tasks(n).Mode=modes{m};tasks(n).Seed=seed;
    tasks(n).ID=sprintf('V2_%s_D%d_%s_seed%02d',problems{p},d,modes{m},seed);
   end
  end
 end
end
assert(n==1800&&numel(unique({tasks.ID}))==1800,'Ablation_D20D50:TaskCount','Fixed1800 manifest changed.');
end
