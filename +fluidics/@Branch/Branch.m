classdef Branch < handle
    properties
        ID = NaN
        Items = fluidics.Item.empty
        Terminated = false
        Parents = fluidics.Branch.empty
        Children = fluidics.Branch.empty
        Label = datetime.empty
    end
    properties (Dependent)
        NumItems
        FirstItem
        FinalItem
        FirstFrame
        FinalFrame
        Frames
    end
    methods
        function num = get.NumItems(obj)
            num = length(obj.Items);
        end
        function item = get.FirstItem(obj)
            item = obj.Items(1);
        end
        function item = get.FinalItem(obj)
            item = obj.Items(end);
        end
        function k = get.FirstFrame(obj)
            k = obj.FirstItem.Frame;
        end
        function k = get.FinalFrame(obj)
            k = obj.FinalItem.Frame;
        end
        function frames = get.Frames(obj)
            frames = [obj.Items.Frame]';
        end
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