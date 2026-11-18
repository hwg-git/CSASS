function report = rt_summarize(root,out)
% Summarize the fixed manifest. CSV is authoritative; no trial is rerun.
root=char(root);out=char(out);
manifestFile=fullfile(root,'manifest.csv');
assert(isfile(manifestFile),'rt:ManifestMissing','Missing manifest: %s',manifestFile);
M=readtable(manifestFile,'TextType','string','VariableNamingRule','preserve');
required={'Order','ID','Problem','D','Algorithm','Seed','N','MaxFE','Pmax','K'};
assert(all(ismember(required,M.Properties.VariableNames)),...
    'rt:ManifestColumns','Manifest is missing required columns.');
assert(numel(unique(string(M.ID)))==height(M),'rt:DuplicateIDs','Manifest IDs must be unique.');
M=sortrows(M,'Order');
tablesDir=fullfile(out,'tables');if ~isfolder(tablesDir),mkdir(tablesDir);end
template=struct('Order',NaN,'ID',"",'Problem',"",'D',NaN,'Algorithm',"",...
    'Seed',NaN,'Status',"not_started",'FE',NaN,'InitialN',NaN,'FeasibleND',NaN,...
    'RuntimeSeconds',NaN,'TrialWallSeconds',NaN,'IGD',NaN,'HV11',NaN,...
    'RecordSource',"",'SummaryIssue',"");
records=repmat(template,height(M),1);
for i=1:height(M)
    t=table2struct(M(i,:));s=template;
    s.Order=number(t.Order);s.ID=string(t.ID);s.Problem=string(t.Problem);
    s.D=number(t.D);s.Algorithm=string(t.Algorithm);s.Seed=number(t.Seed);
    runDir=fullfile(out,'runs',char(s.ID));marker=fullfile(runDir,'complete.json');
    if isfile(marker)
        try
            completed=jsondecode(fileread(marker));
            csvFile=fullfile(runDir,'result_row.csv');
            if isfile(csvFile)
                Q=readtable(csvFile,'TextType','string','VariableNamingRule','preserve');
                assert(height(Q)==1,'rt:RowCount','result_row.csv must have exactly one row.');
                q=table2struct(Q(1,:));s.RecordSource="result_row.csv";
            else
                assert(isfield(completed,'Row'),'rt:MissingRow','complete.json has no Row.');
                q=completed.Row;s.RecordSource="complete.json.Row";
            end
            check_row(q,t);
            for f={'FE','InitialN','FeasibleND','RuntimeSeconds','TrialWallSeconds','IGD','HV11'}
                s.(f{1})=number(q.(f{1}));
            end
            s.Status="completed";
        catch err
            s.Status="invalid_complete";
            s.SummaryIssue=string(err.identifier)+": "+string(err.message);
        end
    elseif isfile(fullfile(runDir,'failure.json')) || isfile(fullfile(runDir,'failed.json'))
        s.Status="failed";
    elseif isfolder(runDir)
        s.Status="incomplete";
    end
    records(i)=s;
end
R=struct2table(records);
groups=unique(M(:,{'Problem','D','Algorithm'}),'rows','stable');
gTemplate=struct('Problem',"",'D',NaN,'Algorithm',"",'ExpectedRuns',0,...
    'CompletedRuns',0,'FailedRuns',0,'IncompleteRuns',0,'NotStartedRuns',0,...
    'InvalidCompletedRuns',0,'FormalStatisticsReady',false,...
    'RuntimeMeanSeconds',NaN,'RuntimeSDSamples',NaN,...
    'ProvisionalRuntimeMeanSeconds',NaN,'ProvisionalRuntimeSDSamples',NaN,...
    'RuntimeTotalSeconds',0,'RuntimeMinSeconds',NaN,'RuntimeMaxSeconds',NaN);
stats=repmat(gTemplate,height(groups),1);
for i=1:height(groups)
    g=gTemplate;g.Problem=string(groups.Problem(i));g.D=number(groups.D(i));
    g.Algorithm=string(groups.Algorithm(i));
    take=R.Problem==g.Problem & R.D==g.D & R.Algorithm==g.Algorithm;
    T=R(take,:);ok=T.Status=="completed";v=T.RuntimeSeconds(ok);
    g.ExpectedRuns=height(T);g.CompletedRuns=sum(ok);g.FailedRuns=sum(T.Status=="failed");
    g.InvalidCompletedRuns=sum(T.Status=="invalid_complete");
    g.IncompleteRuns=sum(T.Status=="incomplete" | T.Status=="invalid_complete");
    g.NotStartedRuns=sum(T.Status=="not_started");
    g.FormalStatisticsReady=g.ExpectedRuns==30 && g.CompletedRuns==30;
    if ~isempty(v)
        g.RuntimeTotalSeconds=sum(v);g.RuntimeMinSeconds=min(v);g.RuntimeMaxSeconds=max(v);
        if g.FormalStatisticsReady
            g.RuntimeMeanSeconds=mean(v);g.RuntimeSDSamples=std(v,0);
        else
            g.ProvisionalRuntimeMeanSeconds=mean(v);
            if numel(v)>1,g.ProvisionalRuntimeSDSamples=std(v,0);end
        end
    end
    stats(i)=g;
end
S=struct2table(stats);
G=S(:,{'Problem','D','Algorithm','ExpectedRuns','CompletedRuns','FailedRuns',...
    'IncompleteRuns','NotStartedRuns','InvalidCompletedRuns','FormalStatisticsReady'});
pairs=unique(M(:,{'Problem','D'}),'rows','stable');
algs=unique(string(M.Algorithm),'stable');C=pairs;
for a=1:numel(algs)
    col=repmat("pending",height(pairs),1);
    for i=1:height(pairs)
        at=S.Problem==string(pairs.Problem(i)) & S.D==number(pairs.D(i)) & S.Algorithm==algs(a);
        assert(sum(at)==1,'rt:GroupShape','Manifest is not a full problem-by-algorithm grid.');
        q=S(at,:);
        if q.FormalStatisticsReady
            col(i)=string(sprintf('%.4e (%.2e)',q.RuntimeMeanSeconds,q.RuntimeSDSamples));
        else
            col(i)=string(sprintf('pending (%d/%d)',q.CompletedRuns,q.ExpectedRuns));
        end
    end
    C.(matlab.lang.makeValidName(char(algs(a))))=col;
end
atomic_csv(R,fullfile(tablesDir,'run_results.csv'));
atomic_csv(G,fullfile(tablesDir,'group_progress.csv'));
atomic_csv(S,fullfile(tablesDir,'runtime_summary.csv'));
atomic_csv(C,fullfile(tablesDir,'runtime_table.csv'));
report=struct('Status','summarized','GeneratedUTC',utc_now(),'ExpectedRuns',height(M),...
    'CompletedRuns',sum(R.Status=="completed"),'FailedRuns',sum(R.Status=="failed"),...
    'IncompleteRuns',sum(R.Status=="incomplete" | R.Status=="invalid_complete"),...
    'InvalidCompletedRuns',sum(R.Status=="invalid_complete"),...
    'NotStartedRuns',sum(R.Status=="not_started"),'Groups',height(S),...
    'GroupsWith30Completed',sum(S.FormalStatisticsReady),...
    'CSVAuthoritative',true,'InfIGDRetained',true,'ExcelStatus','not_attempted',...
    'ExcelError','','TablesDirectory',tablesDir,'ExcelFile',fullfile(tablesDir,'runtime_results.xlsx'));
% Never destroy a prior workbook if this machine cannot write Excel files.
xlsxTemp=fullfile(tablesDir,['runtime_results.tmp_' char(java.util.UUID.randomUUID()) '.xlsx']);
try
    writetable(R,xlsxTemp,'Sheet','RunResults','UseExcel',false);
    writetable(G,xlsxTemp,'Sheet','GroupProgress','UseExcel',false);
    writetable(S,xlsxTemp,'Sheet','RuntimeSummary','UseExcel',false);
    writetable(C,xlsxTemp,'Sheet','RuntimeTable','UseExcel',false);
    [ok,msg]=movefile(xlsxTemp,report.ExcelFile,'f');
    assert(ok,'rt:ExcelMove','%s',msg);report.ExcelStatus='written';
catch err
    report.ExcelStatus='failed_csv_available';report.ExcelError=err.message;
    if isfile(xlsxTemp),delete(xlsxTemp);end
    warning('rt:ExcelExport','Excel export failed; authoritative CSV files remain saved: %s',err.message);
end
atomic_text(jsonencode(report),fullfile(tablesDir,'summary_status.json'));
end

function check_row(q,t)
fields={'ID','Problem','D','Algorithm','Seed','Status','FE','InitialN','FeasibleND',...
    'RuntimeSeconds','TrialWallSeconds','IGD','HV11'};
assert(isstruct(q)&&isscalar(q)&&all(isfield(q,fields)),...
    'rt:RowFields','Completed row is missing required fields.');
for k={'ID','Problem','Algorithm'}
    f=k{1};assert(isscalar(string(q.(f)))&&string(q.(f))==string(t.(f)),...
        'rt:Identity','Completed %s does not match the manifest.',f);
end
for k={'D','Seed'}
    f=k{1};assert(number(q.(f))==number(t.(f)),'rt:Identity','Completed %s differs from manifest.',f);
end
assert(string(q.Status)=="completed",'rt:Status','Completed row Status must be completed.');
assert(number(q.FE)==number(t.MaxFE),'rt:Budget','Completed FE differs from MaxFE.');
assert(number(q.InitialN)==number(t.N),'rt:InitialN','InitialN differs from the fixed nominal N.');
nf=number(q.FeasibleND);assert(isfinite(nf)&&nf>=0&&nf==floor(nf),'rt:FeasibleND','Invalid FeasibleND.');
for k={'RuntimeSeconds','TrialWallSeconds','HV11'}
    f=k{1};v=number(q.(f));assert(isfinite(v)&&v>=0,'rt:Metric','Invalid %s.',f);
end
v=number(q.IGD);assert(~isnan(v)&&v>=0,'rt:IGD','IGD must be nonnegative finite or +Inf; use result_row.csv to preserve Inf.');
end

function v=number(x)
assert(isscalar(x),'rt:Scalar','Expected scalar numeric field.');
v=str2double(string(x));
end

function atomic_csv(T,path)
tmp=[path '.tmp_' char(java.util.UUID.randomUUID()) '.csv'];
try
    writetable(T,tmp);[ok,msg]=movefile(tmp,path,'f');assert(ok,'rt:CSVMove','%s',msg);
catch err
    if isfile(tmp),delete(tmp);end
    rethrow(err);
end
end

function atomic_text(text,path)
tmp=[path '.tmp_' char(java.util.UUID.randomUUID())];
fid=fopen(tmp,'w','n','UTF-8');assert(fid>=0,'rt:Write','Cannot write %s',tmp);
try
    fwrite(fid,unicode2native(text,'UTF-8'),'uint8');fclose(fid);fid=-1;
    [ok,msg]=movefile(tmp,path,'f');assert(ok,'rt:JSONMove','%s',msg);
catch err
    if fid>=0,fclose(fid);end
    if isfile(tmp),delete(tmp);end
    rethrow(err);
end
end

function s=utc_now()
s=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end
