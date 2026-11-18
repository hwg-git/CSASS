function inventory=v2all_inventory(root,tasks)
% Only matching fixed-task completion markers are accepted. No retry/deletion.
canonical=v2all_tasks(root);
assert(numel(tasks)==1950 && isequal({tasks.ID},{canonical.ID}),...
    'V2_AllBenchmarks:InventoryScope','Inventory must use the complete fixed1950 new manifest.');
n=numel(tasks);done=false(n,1);retained=false(n,1);retainedIDs={};
runsRoot=fullfile(root,'outputs','V2_AllBenchmarks','runs');
if isfolder(runsRoot)
    listing=dir(runsRoot);observed={listing([listing.isdir]).name};
    observed=observed(~ismember(observed,{'.','..'}));
    extra=setdiff(observed,{tasks.ID});
    assert(isempty(extra),'V2_AllBenchmarks:UnexpectedRun',...
        'Unexpected/cached trial directories in new output: %s',strjoin(extra,', '));
end
for i=1:n
    d=fullfile(runsRoot,tasks(i).ID);marker=fullfile(d,'completed.json');
    if isfile(marker)
        m=v2all_io('json',marker);
        assert(isfield(m,'ID') && strcmp(m.ID,tasks(i).ID),...
            'V2_AllBenchmarks:MarkerIdentity','Wrong completion ID: %s',marker);
        assert(isfield(m,'Status') && strcmp(m.Status,'completed') && isfield(m,'FE') && m.FE==500,...
            'V2_AllBenchmarks:MarkerStatus','Invalid completion status/budget: %s',marker);
        for f={'Version','Problem','D','Seed'}
            assert(isfield(m,f{1}) && isequal(m.(f{1}),tasks(i).(f{1})),...
                'V2_AllBenchmarks:MarkerTask','Completion task mismatch (%s): %s',f{1},marker);
        end
        done(i)=true;
    elseif isfolder(d) || isfile(d)
        retained(i)=true;retainedIDs{end+1}=tasks(i).ID; %#ok<AGROW>
    end
end
inventory=struct('Planned',n,'Completed',sum(done),'Retained',sum(retained),...
    'Pending',sum(~done & ~retained),'CompletedMask',done,...
    'RetainedMask',retained,'PendingMask',~done & ~retained,'RetainedIDs',{retainedIDs});
end
