function inventory=abl2050_inventory(root,tasks)
% Fixed manifest completion inventory. Imported and computed completions use
% the same identity/FE/mode/13-core-artifact contract. Imports may additionally
% retain exactly three original-source evidence files. No retry/deletion.
canonical=abl2050_tasks(root);
assert(numel(tasks)==1800 && isequal({tasks.ID},{canonical.ID}),...
    'Ablation_D20D50:InventoryScope','Inventory requires the complete fixed1800 manifest.');
n=numel(tasks);done=false(n,1);retained=false(n,1);imported=false(n,1);retainedIDs={};
runsRoot=fullfile(root,'outputs','Ablation_D20D50','runs');
if isfolder(runsRoot)
    listing=dir(runsRoot);observed={listing([listing.isdir]).name};
    observed=observed(~ismember(observed,{'.','..'}));extra=setdiff(observed,{tasks.ID});
    assert(isempty(extra),'Ablation_D20D50:UnexpectedRun',...
        'Unexpected/cached trial directories in new output: %s',strjoin(extra,', '));
end
expectedFiles={'result.json','precision_ledger.csv','final_objectives.csv','final_decisions.csv',...
    'model_selection.csv','prediction_errors.csv','training_ids.csv','stage_flags.csv','fit_times.csv',...
    'final_training_archive.csv','final_surrogate_population_NOT_TRUE.csv','configuration.json','diagnostic_result.mat'};
importEvidence={'source_completed.json','source_result.json','source_configuration.json'};
for i=1:n
    d=fullfile(runsRoot,tasks(i).ID);marker=fullfile(d,'completed.json');
    if isfile(marker)
        m=abl2050_io('json',marker);
        assert(isfield(m,'ID') && strcmp(m.ID,tasks(i).ID),...
            'Ablation_D20D50:MarkerIdentity','Wrong completion ID: %s',marker);
        assert(isfield(m,'Status') && strcmp(m.Status,'completed') && isfield(m,'FE') && m.FE==500,...
            'Ablation_D20D50:MarkerStatus','Invalid completion status/budget: %s',marker);
        for f={'Version','Problem','D','Seed','Mode'}
            assert(isfield(m,f{1}) && isequal(m.(f{1}),tasks(i).(f{1})),...
                'Ablation_D20D50:MarkerTask','Completion task mismatch (%s): %s',f{1},marker);
        end
        imported(i)=(isfield(m,'Origin') && strcmp(m.Origin,'imported')) ||...
            (isfield(m,'Imported') && isequal(m.Imported,true));
        assert(isfield(m,'Files') && ismember(numel(m.Files),[13,16]),...
            'Ablation_D20D50:Artifacts','Completion requires13 core artifacts, optionally3 original-source files: %s',marker);
        listed={m.Files.Path};
        extras=setdiff(listed,expectedFiles);
        assert(numel(unique(listed))==numel(listed) && all(ismember(expectedFiles,listed)) &&...
            (isempty(extras) || (imported(i) && isequal(sort(extras),sort(importEvidence)))),...
            'Ablation_D20D50:Artifacts','Unexpected/duplicate artifact paths: %s',marker);
        for f=1:numel(m.Files)
            assert(isfile(fullfile(d,m.Files(f).Path)) &&...
                ~isempty(regexp(char(m.Files(f).SHA256),'^[0-9a-fA-F]{64}$','once')),...
                'Ablation_D20D50:Artifacts','Missing artifact or invalid SHA256: %s/%s',tasks(i).ID,m.Files(f).Path);
        end
        % Full byte hashes are checked by the complete summary audit.
        done(i)=true;
        assert(~imported(i) || strcmp(tasks(i).Mode,'adaptive'),...
            'Ablation_D20D50:ImportMode','Only full-V2 adaptive records may be imported: %s',tasks(i).ID);
    elseif isfolder(d) || isfile(d)
        retained(i)=true;retainedIDs{end+1}=tasks(i).ID; %#ok<AGROW>
    end
end
inventory=struct('Planned',n,'Completed',sum(done),'ImportedCompleted',sum(imported),...
    'ComputedCompleted',sum(done & ~imported),'Retained',sum(retained),...
    'Pending',sum(~done & ~retained),'CompletedMask',done,'ImportedMask',imported,...
    'RetainedMask',retained,'PendingMask',~done & ~retained,'RetainedIDs',{retainedIDs});
end
