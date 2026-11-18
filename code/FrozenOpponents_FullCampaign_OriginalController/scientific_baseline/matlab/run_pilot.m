function summary = run_pilot()
% Bounded verification only: 2 problems x 1 seed x 5 controlled variants.
% NOT the manuscript's 30-run experiment. All settings/seeds fixed in advance.
root=setup_csass(); stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
out=fullfile(root,'..','results',['pilot_',stamp]); mkdir(out);
problems={'CF2','LIRCMOP1'};
modes={'adaptive','rbf_only','kriging_only', ...
    'fixed_rbf_obj_kriging_con','fixed_kriging_obj_rbf_con'};
rows=cell(0,9);
for j=1:numel(problems)
    commonInitial=[];
    for k=1:numel(modes)
        opts=struct('Seed',1,'Mode',modes{k},'OutputDirectory', ...
            fullfile(out,[problems{j},'_',modes{k}]));
        r=csass_run(csass.problem(problems{j},10),opts);
        if isempty(commonInitial), commonInitial=r.initialX;
        else, assert(isequal(commonInitial,r.initialX),'Initial designs differ.'); end
        used=vertcat(r.stages.usedChoice);
        rows(end+1,:)={problems{j},10,modes{k},r.FE,r.metrics.IGD, ...
            r.metrics.HV,size(r.finalF,1),mean(used(:,1)==2),mean(used(:,2)==2)}; %#ok<AGROW>
    end
end
summary=cell2table(rows,'VariableNames',{'Problem','D','Mode','FE','IGD','HV', ...
    'FeasibleNDCount','ObjectiveKrigingProportion','ConstraintKrigingProportion'});
writetable(summary,fullfile(out,'pilot_summary.csv')); disp(summary);
end
