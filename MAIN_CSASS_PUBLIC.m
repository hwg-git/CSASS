function MAIN_CSASS_PUBLIC(action, mode)
% Public release dispatcher. No experiment runs without an explicit 'run'.
% Start in the release root, in a fresh MATLAB session.
if nargin<1 || isempty(action), action='help'; end
if nargin<2 || isempty(mode), mode='preflight'; end
action=lower(char(action)); mode=lower(char(mode));
root=fileparts(mfilename('fullpath'));
if ismember(action,{'help','list'})
    fprintf(['CSASS reproducibility release\n', ...
        '  MAIN_CSASS_PUBLIC(''benchmark'',''preflight''|''run'')\n', ...
        '  MAIN_CSASS_PUBLIC(''ablation10'',''preflight''|''run'')\n', ...
        '  MAIN_CSASS_PUBLIC(''ablation2050'',''preflight''|''run'')\n', ...
        '  MAIN_CSASS_PUBLIC(''runtime'',''preflight''|''run'')\n', ...
        '  MAIN_CSASS_PUBLIC(''sensitivity'',''plan''|''preflight''|''run''|''status'')\n', ...
        '  MAIN_CSASS_PUBLIC(''opponents_missing8'',''preflight''|''run'')\n', ...
        '  MAIN_CSASS_PUBLIC(''opponents_full'',''plan''|''preflight''|''run''|''status'')\n', ...
        'No optimization has been started. Read README before run.\n', ...
        'The archived all-algorithm controller also contains an older CSASS;\n', ...
        'it is retained for provenance and is NOT a public CSASS entry point.\n']);
    return;
end
assert(ismember(mode,{'plan','preflight','run','summarize','status','collect'}), ...
    'Use explicit plan, preflight, run, summarize, status or collect.');
oldPath=path; restorePath=onCleanup(@()path(oldPath)); %#ok<NASGU>
switch action
    case 'benchmark'
        folder='CSASS_AllBenchmarks_MATLAB'; entry='MAIN_CSASS_V2_ALL';
    case 'ablation10'
        folder='CSASS_Ablation_D10_MATLAB'; entry='MAIN_CSASS_V2_D10';
    case 'ablation2050'
        folder='CSASS_Ablation_D20D50_MATLAB'; entry='MAIN_CSASS_ABLATION';
    case 'runtime'
        folder='Runtime_Table9'; entry='MAIN_CSASS_RUNTIME';
        if strcmp(mode,'plan'), mode='preflight'; end
    case 'opponents_missing8'
        folder='FrozenOpponents_Missing8_MATLAB'; entry='MAIN_MISSING8';
    case 'sensitivity'
        assert(~strcmp(mode,'collect'),'Sensitivity supports plan,preflight,run,status,summarize; its output is already saved as CSV/MAT.');
        addpath(fullfile(root,'code','public_tools'),'-begin');
        PUBLIC_CF7_SENSITIVITY(root,mode); return;
    case 'opponents_full'
        assert(~strcmp(mode,'collect'),'Opponents_full supports plan,preflight,run,status,summarize; its output is already saved in reproduced/opponents_full.');
        addpath(fullfile(root,'code','public_tools'),'-begin');
        PUBLIC_OPPONENTS_FULL(root,mode); return;
    otherwise
        error('Unknown action. Run MAIN_CSASS_PUBLIC(''help'').');
end
if strcmp(mode,'status') && ~strcmp(action,'runtime'), mode='summarize'; end
folder=fullfile(root,'code',folder);
assert(isfile(fullfile(folder,[entry,'.m'])),'Missing release component: %s',entry);
addpath(folder,'-begin'); rehash path;
assert(strcmpi(which(entry),fullfile(folder,[entry,'.m'])), ...
    'MATLAB PATH conflict. Start a fresh MATLAB session in this release root.');
feval(entry,mode);
end
