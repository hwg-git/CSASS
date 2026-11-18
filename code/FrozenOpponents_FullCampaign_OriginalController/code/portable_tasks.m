function tasks=portable_tasks(c)
tasks=repmat(struct('ID','','Algorithm','','Problem','','D',0,'Seed',0,'Index',0),0,1);n=0;
for pi=1:numel(c.Problems)
 for D=c.Dimensions
  for seed=c.Seeds
   for ai=1:numel(c.Algorithms)
    n=n+1;a=c.Algorithms{ai};p=c.Problems{pi};tasks(n)=struct('ID',sprintf('%s_%s_D%d_seed%02d',a,p,D,seed),'Algorithm',a,'Problem',p,'D',D,'Seed',seed,'Index',n);
   end
  end
 end
end
if strcmp(c.Mode,'validation')
 tasks=tasks(strcmp({tasks.Problem},'CF8')|strcmp({tasks.Algorithm},'CSASS'));
 tasks=reshape(tasks,1,[]);for k=1:numel(tasks),tasks(k).Index=k;end
end
end
