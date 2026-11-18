function G=v2all_group_statistics(T)
% Whole-batch statistics: missing/Inf runs are never omitted from full means.
G=table();if isempty(T),return;end
keys=unique(T(:,{'Version','Problem','D'}),'rows','stable');
for i=1:height(keys)
 sel=string(T.Version)==string(keys.Version(i)) & string(T.Problem)==string(keys.Problem(i)) & T.D==keys.D(i);
 Q=T(sel,:);assert(numel(unique(Q.Seed))==height(Q),'Duplicate seeds within a group.');
 finite=isfinite(Q.IGD10000);values=Q.IGD10000(finite);n=height(Q);
 fm=NaN;fs=NaN;cm=NaN;cs=NaN;
 if ~isempty(values),cm=mean(values);cs=std(values,0);end
 if n==30&&all(finite),fm=cm;fs=cs;end
 fullHV=[NaN,NaN,NaN];sdHV=fullHV;
 if n==30
  hv=[Q.HVr1p1,Q.HVr3,Q.HVr20];assert(all(isfinite(hv),'all')&&all(hv>=0,'all'));
  fullHV=mean(hv,1);sdHV=std(hv,0,1);
 end
 R=table(string(keys.Version(i)),string(keys.Problem(i)),keys.D(i),n,sum(finite),...
  fm,fs,cm,cs,sum(Q.FeasibleND>0),sum(Q.HVr1p1==0),fullHV(1),sdHV(1),fullHV(2),sdHV(2),fullHV(3),sdHV(3),...
  'VariableNames',{'Version','Problem','D','Runs','FiniteIGDRuns','IGDMean30','IGDStd30',...
  'IGDConditionalMean','IGDConditionalStd','FeasibleRuns','ZeroHVRuns',...
  'HVr1p1Mean30','HVr1p1Std30','HVr3Mean30','HVr3Std30','HVr20Mean30','HVr20Std30'});
 if n<30,R.IGDDisplay=string(sprintf('PENDING [%d/30]',n));
 elseif isfinite(fm),R.IGDDisplay=string(sprintf('%.6g (%.4g)',fm,fs));
 else,R.IGDDisplay=string(sprintf('N/A [%d/30]',sum(finite)));end
 G=[G;R]; %#ok<AGROW>
end
end
