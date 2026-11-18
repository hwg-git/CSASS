classdef PROBLEM < handle
    % Minimal independent adapter for unmodified PlatEMO benchmark classes.
    % This is NOT the PlatEMO execution engine and is not used for CSASS logic.
    properties
        M = []
        D = []
        lower = []
        upper = []
        encoding = []
        FE = 0
    end
    methods
        function Population = Evaluation(obj,varargin)
            X = varargin{1};
            X = max(min(X,obj.upper),obj.lower);
            F = obj.CalObj(X);
            G = obj.CalCon(X);
            Population = SOLUTION(X,F,G);
            obj.FE = obj.FE + numel(Population);
        end
        function G = CalCon(~,X)
            G = zeros(size(X,1),0);
        end
    end
end
