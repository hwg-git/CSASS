function m8_dependencies(root)
assert(ispc&&strcmp(computer('arch'),'win64'),'This package contains Windows64 LIBSVM MEX files.');
assert(~isempty(ver('stats'))&&license('test','Statistics_Toolbox'),'Statistics and Machine Learning Toolbox required.');
assert(~isempty(ver('nnet'))&&license('test','Neural_Network_Toolbox'),'Deep Learning Toolbox required by HeEMOEA and PCSAEA.');
oldpath=path;guard=onCleanup(@()path(oldpath)); %#ok<NASGU>
for name={'ANSGAIII','HeEMOEA','MOL2SMEA','PCSAEA','CTAEA'}
 portable_setup(root,name{1});
 assert(startsWith(which(name{1}),fullfile(root,'protocol_algorithms')),'Wrong algorithm source.');
end
fprintf('DEPENDENCIES PASS: Windows64, Statistics, Deep Learning, frozen algorithm paths.\n');
end
