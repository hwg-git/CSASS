function root = setup_csass()
% Add only this standalone project's paths (no installation changes).
root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root,'benchmark_adapter'));
addpath(fullfile(root,'..','vendor','platemo_problems'));
addpath(fullfile(root,'..','vendor','platemo_helpers'));
end
