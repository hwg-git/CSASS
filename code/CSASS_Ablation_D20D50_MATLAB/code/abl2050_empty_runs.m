function T=abl2050_empty_runs()
% Typed zero-row schema. This package has no cached or fabricated trials.
names={'ID','Version','Problem','D','Mode','Seed','FE','M','FeasibleND',...
 'IGD10000','IGD2000','HVr1p1','HVr3','HVr20','FinalObjectivesAvailable',...
 'Source','SourceSHA256','Status'};
types=repmat({'double'},1,numel(names));
types(ismember(names,{'ID','Version','Problem','Mode','Source','SourceSHA256','Status'}))={'string'};
types(strcmp(names,'FinalObjectivesAvailable'))={'logical'};
T=table('Size',[0,numel(names)],'VariableTypes',types,'VariableNames',names);
end
