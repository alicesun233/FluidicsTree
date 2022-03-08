classdef Tracker < handle
    properties (SetAccess=public)
        FuncEvolve = @(value1,value2)value1==value2
    end
    
    properties (Dependent)
        FrameLimit
        Summary
        Branches
    end
    
    properties (SetAccess=private)
        IsComplete = false
    end
    
    properties (SetAccess=private,Transient)
        Root(1,1) fluidics.Branch
    end
    
    methods
        function obj = Tracker()
            obj.Root = fluidics.Branch();
        end
    end
    
    methods
        function k = get.FrameLimit(obj)
            branches = obj.Branches;
            firstItems = [branches.FirstItem];
            finalItems = [branches.FinalItem];
            k = [min([firstItems.Frame]) max([finalItems.Frame])];
        end
        
        function info = get.Summary(obj)
            % Order branches in the order they appear in
            branches = obj.Branches;
            [~,I] = sort([branches.FirstFrame]);
            branches = branches(I);
            rows = num2cell(nan(length(branches),1));
            % Compile summary
            info = struct('Frames',{branches.Frames}');
            % Schedule row number availability
            frameLimit = obj.FrameLimit;
            firstFrame = frameLimit(1);
            finalFrame = frameLimit(2);
            totalFrames = finalFrame-firstFrame+1;
            taken = false(1,totalFrames);
            for k = 1:length(branches)
                lifespan = (info(k).Frames(1):info(k).Frames(end))-firstFrame+1;
                availability = ~taken(:,lifespan);
                firstAvailability = find(all(availability,2),1);
                if isempty(firstAvailability)
                    firstAvailability = size(taken,1)+1;
                end
                taken(firstAvailability,lifespan) = true;
                rows{k} = firstAvailability;
            end
            % Update number summary
            [info.Number] = deal(rows{:});
            % Update IDS
            IDs = num2cell([branches.ID]);
            [info.ID] = deal(IDs{:});
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
            % Update number
            IDs = num2cell(1:(length(queue)-1));
            [queue(2:end).ID] = deal(IDs{:});
            branches = queue(2:end);
        end
    end
    
    methods
        linkBack(obj,vec)
        optimize(obj)
        plot(obj)
    end
    
    methods (Access=private)
        branches = complete(obj)
    end
end
