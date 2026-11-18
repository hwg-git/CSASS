function portable_setup(root,algorithm)
% All algorithms share ONLY the full PlatEMO PROBLEM/SOLUTION superclass.
% Do not call standalone setup_csass: it would add a conflicting minimal class.
protocol=fullfile(root,'protocol_algorithms');parts=strsplit(path,pathsep);
for i=1:numel(parts)
 if strncmpi(parts{i},[protocol,filesep],numel(protocol)+1),rmpath(parts{i});end
end
v=fullfile(root,'vendor','PlatEMO');
addpath(fullfile(v,'Problems'),fullfile(v,'Algorithms'),fullfile(v,'Algorithms','Utility functions'));
addpath(fullfile(root,'scientific_baseline','matlab'),fullfile(root,'scientific_baseline','vendor','platemo_problems'),fullfile(root,'code'));
if ~strcmp(algorithm,'CSASS')
 names={'ANSGAIII','HeEMOEA','MOL2SMEA','PCSAEA','CTAEA'};folders={'A-NSGA-III','HeE-MOEA','MO-L2SMEA','PC-SAEA','C-TAEA'};
 j=find(strcmp(names,algorithm));assert(numel(j)==1);addpath(genpath(fullfile(protocol,folders{j})));
end
rehash path;
assert(strcmp(which('PROBLEM'),fullfile(v,'Problems','PROBLEM.m')),'Wrong PROBLEM class. Start a fresh MATLAB session without other PlatEMO paths.');
end
