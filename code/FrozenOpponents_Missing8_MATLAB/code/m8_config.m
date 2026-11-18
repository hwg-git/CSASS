function c=m8_config(root)
c=m8_io('json',fullfile(root,'protocol.json'));
c.Problems=cellstr(string(c.Problems(:)'));
c.Algorithms=cellstr(string(c.Algorithms(:)'));
c.Dimensions=c.Dimensions(:)';c.Seeds=c.Seeds(:)';
c.Output=fullfile(root,'outputs','Missing8_Opponents');
end
