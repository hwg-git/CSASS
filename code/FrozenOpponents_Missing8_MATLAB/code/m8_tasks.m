function tasks=m8_tasks(root)
c=m8_config(root);
tasks=repmat(struct('ID','','Algorithm','','Problem','','D',0,'M',2,'Seed',0,'N',100,'MaxFE',500),c.TotalTasks,1);
i=0;
for p=1:numel(c.Problems)
 for d=c.Dimensions
  for s=c.Seeds
   for a=1:numel(c.Algorithms)
    i=i+1;name=c.Algorithms{a};problem=c.Problems{p};
    tasks(i)=struct('ID',sprintf('%s_%s_D%d_seed%02d',name,problem,d,s),...
     'Algorithm',name,'Problem',problem,'D',d,'M',2,'Seed',s,'N',100,'MaxFE',500);
   end
  end
 end
end
assert(i==c.TotalTasks&&numel(unique({tasks.ID}))==i,'Invalid task manifest.');
end
