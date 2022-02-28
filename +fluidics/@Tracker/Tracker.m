classdef Tracker < handle
    properties (SetAccess = public)
        FuncEvolve = @(value1,value2)value1==value2
    end
    properties (Dependent)
        Branches
        FirstFrame
        FinalFrame
    end
    properties (SetAccess = private)
        IsComplete = false
        Root(1,1) fluidics.Branch
    end
    methods
        function obj = Tracker()
            obj.Root = fluidics.Branch();
        end
    end
    methods
        function k = get.FirstFrame(obj)
            items = [obj.Branches.FirstItem];
            k = min([items.Frame]);
        end
        function k = get.FinalFrame(obj)
            items = [obj.Branches.FinalItem];
            k = max([items.Frame]);
        end
        function branches = get.Branches(obj)
            % Initialize a timestamp and the index
            label = datetime;
            % Queue the root and mark as explored
            queue = obj.Root;
            queue.Label = label;
            idx = 1;
            while idx<=length(queue)
                % Select current vertex
                node = queue(idx);
                % Identify all unexplored children
                func = @(l)isempty(l)||l~=datetime;
                unexplored = cellfun(func,{node.Children.Label});
                % Explore then queue all unexplored children
                if any(unexplored)
                    toExplore = node.Children(unexplored);
                    [toExplore.Label] = deal(label);
                    queue = unique([queue;toExplore],'stable');
                end
                idx = idx+1;
            end
            branches = queue(2:end);
        end
    end
    methods
        linkBack(obj,vec)
        optimize(obj)
        plot(obj)
    end
    methods (Access = private)
        branches = complete(obj)
    end
end
