classdef Tracker < handle
    properties
        Branches = fluidics.Branch.empty
        FuncEvolve = @(value1,value2)value1==value2
        StartFrame = 1
        FinalFrame = 0
    end
    methods
        function obj = Tracker()
        end
        
        function linkBack(obj,matrix)
            matrix = fluidics.core.mat2col(matrix);
            % Endpoints of active branches
            currentBranches = obj.Branches(~[obj.Branches.Terminated]');
            tails = arrayfun(@(b)b.back(),currentBranches);
            % Pushed items
            items = arrayfun(@fluidics.Item,...
                matrix,repmat(obj.FinalFrame+1,size(matrix)));
            % Evolution matrix
            [II,JJ] = ndgrid(1:length(tails),1:length(items));
            func = @(i,j)obj.FuncEvolve(tails(i).Value,items(j).Value);
            evolution = arrayfun(func,II,JJ);
            % Compute events
            if ~isempty(tails)
                tailEvents = sum(evolution,2);
                isTailSplit = tailEvents>1;
                isTailHover = tailEvents==0;
            else
                isTailSplit = false(length(tails),1);
                isTailHover = false(length(tails),1);
            end
            if ~isempty(items)
                itemEvents = sum(evolution,1);
                isItemMerge = itemEvents>1;
                isItemHover = itemEvents==0;
            else
                isItemMerge = false(1,length(tails));
                isItemHover = false(1,length(tails));
            end
            if ~isempty(tails)
                isTailMerge = any(evolution(:,isItemMerge),2);
            else
                isTailMerge = false(length(tails));
            end
            if ~isempty(items)
                isItemSplit = any(evolution(isTailSplit,:),1);
            else
                isItemSplit = false(1,length(tails));
            end
            isOldTail = isTailSplit|isTailMerge|isTailHover;
            isNewItem = isItemMerge|isItemSplit|isItemHover;
            % Create new branches, link parent/child, remove old branches
            if ~isempty(isNewItem)&&any(isNewItem)
                newBranches = arrayfun(@fluidics.Branch,items(isNewItem));
                newIndices = find(isNewItem);
                for j = 1:length(newBranches)
                    idxItem = newIndices(j);
                    isParentBranch = evolution(:,idxItem);
                    newBranches(j).Parents = currentBranches(isParentBranch);
                end
            end
            if ~isempty(isOldTail)&&any(isOldTail)
                oldBranches = currentBranches(isOldTail);
                oldIndices = find(isOldTail);
                for i = 1:length(oldBranches)
                    idxTail = oldIndices(i);
                    idxItems = cumsum(isNewItem);
                    idxItems(~evolution(idxTail,:)) = [];
                    if ~isempty(isNewItem)&&any(isNewItem)
                        oldBranches(i).Children = newBranches(idxItems);
                    end
                    oldBranches(i).Terminated = true;
                end
            end
            if ~isempty(isOldTail)&&any(~isOldTail)
                % Update inert branches
                inertBranches = currentBranches(~isOldTail);
                inertIndices = find(~isOldTail);
                for i = 1:length(inertBranches)
                    idxTail = inertIndices(i);
                    inertItem = items(evolution(idxTail,:));
                    inertBranches(i).pushBack(inertItem);
                end
            end
            
            % Advance Frame
            if ~isempty(isNewItem)&&any(isNewItem)
                idxOffset = (1:nnz(isNewItem));
                obj.Branches(end+idxOffset,:) = newBranches;
            end
            obj.FinalFrame = obj.FinalFrame+1;
        end
        
        function done(obj)
            % Terminate all branches
            [obj.Branches.Terminated] = deal(true);
            % Remove all branches that do not have a parent
            isParentFree = cellfun(@isempty,{obj.Branches.Parents});
            obj.Branches(~isParentFree) = [];
            % Replace branches by a root node
            root = fluidics.Branch();
            root.Children = obj.Branches;
            obj.Branches = root;
            [root.Children.Parents] = deal(root);
            % Number all branches
            obj.number();
        end
        
        function number(obj)
            % Initialize a timestamp and the index
            label = datetime;
            % Queue the root and mark as explored
            Q = obj.Branches;
            Q.ID = 0;
            Q.Label = label;
            idx = 1;
            next = 1;
            while idx<=length(Q)
                % Select current vertex
                v = Q(idx);
                func = @(l)isempty(l)||l~=datetime;
                % Explore then enqueue all unexplored children
                unexplored = cellfun(func,{v.Children.Label});
                if any(unexplored)
                    W = v.Children(unexplored);
                    IDs = num2cell(next+(0:nnz(unexplored)-1));
                    [W.ID] = deal(IDs{:});
                    [W.Label] = deal(label);
                    next = next+nnz(unexplored);
                    Q = unique([Q;W],'stable');
                end
                idx = idx+1;
            end
        end
        
        function filterByLength(obj,len)
            
        end
    end
end