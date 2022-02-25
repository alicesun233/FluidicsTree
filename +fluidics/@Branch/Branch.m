classdef Branch < handle
    properties
        ID = NaN
        Items = fluidics.Item.empty
        Terminated = false
        Parents = fluidics.Branch.empty
        Children = fluidics.Branch.empty
        Label = datetime.empty
    end
    methods
        function obj = Branch(varargin)
            if nargin>=1
                obj.Items = fluidics.core.mat2col([varargin{:}]);
            end
        end
        
        function item = back(obj)
            item = obj.Items(end);
        end
        
        function pushBack(obj,item)
            obj.Items(end+1,1) = item;
        end
    end
end