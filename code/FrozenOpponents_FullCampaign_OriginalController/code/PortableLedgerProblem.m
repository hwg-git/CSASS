classdef PortableLedgerProblem < PROBLEM
% Exact public benchmark definitions; streamed truth ledger and strict FE500.
properties
 Base;H=struct('X',[],'F',[],'G',[],'CV',[],'EvaluationID',[],'Stage',[]);
 Batch=0;TruncatedRows=0;InitialN=0;LedgerCSV='';
end
methods
 function obj=PortableLedgerProblem(name,D,N,maxFE)
  obj@PROBLEM('D',D,'N',N,'maxFE',maxFE,'parameter',{name});
 end
 function Setting(obj)
  obj.Base=feval(obj.parameter{1},'D',obj.D,'N',obj.N,'maxFE',obj.maxFE);
  obj.M=obj.Base.M;obj.D=obj.Base.D;obj.lower=obj.Base.lower;obj.upper=obj.Base.upper;obj.encoding=obj.Base.encoding;
 end
 function R=GetOptimum(obj,N),R=obj.Base.GetOptimum(N);end
 function R=GetPF(~),R=[];end
 function P=Initialization(obj,N)
  if nargin<2,N=obj.N;end
  assert(obj.FE==0&&ismember(N,[91,100]),'Unexpected initialization request.');
  X=obj.lower+csass.lhs(N,obj.D).*(obj.upper-obj.lower);P=obj.Evaluation(X);
 end
 function P=Evaluation(obj,varargin)
  remain=obj.maxFE-obj.FE;assert(remain>0,'PlatEMO:Termination','Strict true-evaluation budget reached.');
  count=size(varargin{1},1);keep=min(count,remain);obj.TruncatedRows=obj.TruncatedRows+count-keep;
  if keep<count
   for j=1:numel(varargin),if size(varargin{j},1)==count,varargin{j}=varargin{j}(1:keep,:);end;end
  end
  obj.Base.FE=obj.FE;P=obj.Base.Evaluation(varargin{:});X=P.decs;F=P.objs;G=P.cons;CV=sum(max(0,G),2);
  valid=size(X,1)==keep&&isreal(X)&&isreal(F)&&isreal(G)&&all(isfinite(F),'all')&&all(isfinite(G),'all');
  if ~valid&&~isempty(obj.LedgerCSV)
   invalid=struct('X',X,'F',F,'G',G,'FEbefore',obj.FE);save(fullfile(fileparts(obj.LedgerCSV),'invalid_evaluation.mat'),'invalid','-v7');
  end
  assert(valid,'Nonfinite/complex benchmark evaluation; raw offending batch retained, no replacement or filtering.');
  if obj.FE==0,obj.InitialN=keep;end
  eid=(obj.FE+(1:keep))';stage=repmat(obj.Batch,keep,1);
  obj.H.X=[obj.H.X;X];obj.H.F=[obj.H.F;F];obj.H.G=[obj.H.G;G];obj.H.CV=[obj.H.CV;CV];obj.H.EvaluationID=[obj.H.EvaluationID;eid];obj.H.Stage=[obj.H.Stage;stage];
  if ~isempty(obj.LedgerCSV)
   headers=[{'EvaluationID','Stage'},cellstr(compose('x%d',1:obj.D)),cellstr(compose('f%d',1:obj.M)),cellstr(compose('g%d',1:size(G,2))),{'CV'}];
   portable_write_csv(obj.LedgerCSV,headers,[eid,stage,X,F,G,CV],obj.FE>0);
  end
  obj.Batch=obj.Batch+1;obj.FE=obj.FE+keep;assert(obj.FE<=obj.maxFE&&obj.Base.FE==obj.FE);
 end
end
end
