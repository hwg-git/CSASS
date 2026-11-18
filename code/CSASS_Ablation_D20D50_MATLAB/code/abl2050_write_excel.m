function abl2050_write_excel(T,file,sheet)
% Keep finite values numeric; explicitly encode IEEE infinity as text.
% MATLAB writetable otherwise maps Inf to 65535 in Excel output.
E=T;
for i=1:width(T)
 name=T.Properties.VariableNames{i};v=T.(name);
 if isnumeric(v) && any(isinf(v),'all')
  assert(isvector(v) || isempty(v),'Expected one numeric value per table cell.');
  c=num2cell(v);
  for j=1:numel(v)
   if isinf(v(j))
    if v(j)>0,c{j}='Inf';else,c{j}='-Inf';end
   elseif isnan(v(j)),c{j}=[];
   end
  end
  E.(name)=c;
 end
end
writetable(E,file,'Sheet',sheet,'UseExcel',false);
end
