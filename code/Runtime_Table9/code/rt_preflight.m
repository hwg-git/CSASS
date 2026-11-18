function env=rt_preflight(root)
% Hash/path/metadata checks only. Does not call Solve, Evaluation or csass_run_v2.
oldPath=path; restorePath=onCleanup(@()path(oldPath)); %#ok<NASGU>
restoredefaultpath; addpath(root,fullfile(root,'code'));
assert(ispc,'This package records the Windows timing environment.');
assert(~verLessThan('matlab','9.9'),'MATLAB R2020b or newer required.');
assert(usejava('jvm'),'MATLAB JVM is required for hashing and atomic locks.');
if exist('gcp','file')==2
    p=gcp('nocreate'); assert(isempty(p),'Close the parallel pool before this serial timing experiment.');
end
assert(exist('pdist2','file')~=0 && exist('lhsdesign','file')~=0 && exist('kmeans','file')~=0, ...
    'Statistics and Machine Learning Toolbox is required by the frozen opponents.');
assert(license('test','Statistics_Toolbox'),'Statistics toolbox license unavailable.');
nn={'newrb','newpnn','mapminmax','dist'};
for k=1:numel(nn), assert(exist(nn{k},'file')~=0,'Deep Learning Toolbox dependency missing: %s',nn{k}); end
assert(license('test','Neural_Network_Toolbox'),'Deep Learning Toolbox license unavailable.');
S=jsondecode(fileread(fullfile(root,'package_manifest.json')));
for i=1:numel(S)
    assert(strcmp(rt_sha256(fullfile(root,strrep(S(i).RelativePath,'/',filesep))),S(i).SHA256), ...
        'Source or protocol checksum mismatch: %s. Use an unchanged package.',S(i).RelativePath);
end
T=readtable(fullfile(root,'manifest.csv'),'TextType','string');
assert(height(T)==480 && numel(unique(T.ID))==480 && all(T.Order==(1:480)'));
assert(all(T.D==10 & T.N==100 & T.MaxFE==500 & T.Pmax==20 & T.K==10));
problems={'CF1','CF7','LIRCMOP1','LIRCMOP7'};
algs={'HeEMOEA','MOL2SMEA','PCSAEA','CSASS'};
for p=1:4
    for a=1:4
        seeds=sort(T.Seed(T.Problem==problems{p} & T.Algorithm==algs{a}));
        assert(isequal(seeds,(1:30)'),'Manifest group mismatch.');
    end
end
current=fullfile(root,'engines','current_csass');
frozen=fullfile(root,'engines','frozen_opponents');
addpath(fullfile(current,'code')); v2all_engine_setup(current);
for i=1:4
    PF=readmatrix(fullfile(current,'references','PF10000',[problems{i},'.csv']));
    assert(size(PF,2)==2 && all(isfinite(PF),'all') && all(max(PF)-min(PF)>0));
end
addpath(fullfile(frozen,'code'));
for i=1:3
    portable_setup(frozen,algs{i});
    f=which(algs{i});
    assert(startsWith(lower(f),lower(fullfile(frozen,'protocol_algorithms'))),'Algorithm PATH conflict.');
end
% Query machine configuration outside all trial timers. No settings changed.
env=struct('CreatedUTC',rt_now(),'Host',getenv('COMPUTERNAME'),'MATLAB',version, ...
    'Architecture',computer,'BLAS',version('-blas'),'LAPACK',version('-lapack'), ...
    'Threads',maxNumCompThreads,'CPUModel','','PhysicalCores',0,'LogicalProcessors',0, ...
    'RAMBytes',0,'OS','','PowerPlan','','OtherMATLABProcesses',0, ...
    'PackageSHA256',rt_sha256(fullfile(root,'package_manifest.json')),'Toolboxes',ver);
cmd=['powershell -NoProfile -NonInteractive -Command "', ...
    '$c=@(Get-CimInstance Win32_Processor); $o=Get-CimInstance Win32_OperatingSystem; ', ...
    '$s=Get-CimInstance Win32_ComputerSystem; ', ...
    '[pscustomobject]@{HostName=$s.Name; CPU=($c.Name -join ''; ''); ', ...
    'Cores=($c | Measure-Object NumberOfCores -Sum).Sum; ', ...
    'Logical=($c | Measure-Object NumberOfLogicalProcessors -Sum).Sum; ', ...
    'RAM=$s.TotalPhysicalMemory; OS=$o.Caption; ', ...
    'MATLABProcesses=@(Get-CimInstance Win32_Process | Where-Object {$_.Name -eq ''MATLAB.exe''} | ', ...
    'Select-Object ProcessId,ParentProcessId)} | ConvertTo-Json -Depth 4 -Compress"'];
[status,raw]=system(cmd);
assert(status==0,'Cannot read Windows machine metadata: %s',raw);
e=jsondecode(strtrim(raw));
env.Host=e.HostName; env.CPUModel=e.CPU; env.PhysicalCores=e.Cores; env.LogicalProcessors=e.Logical;
env.RAMBytes=e.RAM; env.OS=e.OS;
% Windows batch startup may retain a MATLAB launcher parent. It is not a
% second compute session. Exclude this process and its MATLAB ancestors only.
procs=e.MATLABProcesses; own=feature('getpid'); allowed=own;
if ~isempty(procs)
    pid=[procs.ProcessId]; parent=[procs.ParentProcessId]; cursor=own;
    while any(pid==cursor)
        next=parent(find(pid==cursor,1));
        if ~ismember(next,pid) || ismember(next,allowed), break; end
        allowed(end+1)=next; cursor=next; %#ok<AGROW>
    end
    env.OtherMATLABProcesses=sum(~ismember(pid,allowed));
end
env.MATLABProcessID=own; env.MATLABProcessSnapshot=procs;
[status,power]=system('powercfg /getactivescheme');
assert(status==0,'Cannot record Windows power plan.'); env.PowerPlan=strtrim(power);
fprintf('PREFLIGHT PASS: %d locked source/protocol files, 480 planned trials, zero evaluations performed.\n',numel(S));
fprintf('Machine: %s | %s | MATLAB %s\n',env.Host,env.CPUModel,env.MATLAB);
fprintf('Current compute threads: %d. The run action sets one and restores it on exit.\n',env.Threads);
if env.OtherMATLABProcesses>0
    fprintf('Other MATLAB processes: %d. Close them before run.\n',env.OtherMATLABProcesses);
end
end
