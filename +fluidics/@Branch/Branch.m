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

        function delete(obj)
            delete(obj.Items)
        end

        function item = back(obj)
            item = obj.Items(end);
        end

        function pushBack(obj,item)
            obj.Items(end+1,1) = item;
        end

        function pushChild(obj,branch)
            obj.Children = [obj.Children;branch];
            branch.Parents = [branch.Parents;obj];
        end

        function absorb(obj,branch)
            % Take ownership of all items
            obj.Items = [obj.Items;branch.Items];
            branch.Items = [];
            % Take custody of all children of the "branch"
            for b = fluidics.core.mat2row(branch.Children)
                b.Parents(b.Parents==branch) = obj;
                obj.Children = [obj.Children;b];
            end
            branch.Children(:) = [];
            % Remove "branch" as children from all its parents
            for b = fluidics.core.mat2row(branch.Parents)
                b.Children(b.Children==branch) = [];
            end
            branch.Parents(:) = [];
        end
    end
end
