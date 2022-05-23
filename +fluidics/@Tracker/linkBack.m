function linkBack(obj,items)

% Ensure that vec is a vector of Items
validateattributes(items,{'fluidics.Item'},{'vector'});
items = fluidics.core.mat2col(items);

% Mark tracker as tampered
obj.IsComplete = false;

% Obtain a copy of root
root = obj.Root;

% Obtain non-terminated branches and their final items
currentBranches = root.Children;
currentBranches([currentBranches.Terminated]) = [];
tails = [currentBranches.FinalItem]';

% Construct an evolution matrix between all tails and all items
[II,JJ] = ndgrid(1:length(tails),1:length(items));
func = @(i,j)obj.FuncEvolve(tails(i).Value,items(j).Value);
evolution = arrayfun(func,II,JJ);

% Untangle the evolution matrix
if ~isempty(evolution)
    rowgroup = zeros(size(evolution,1),1);
    rowgroup(~any(evolution,2)) = nan;
    colgroup = zeros(1,size(evolution,2));
    colgroup(~any(evolution,1)) = nan;
    % Compute the next tangled group
    while any(rowgroup==0)
        group = max(rowgroup)+1;
        rows = false(size(rowgroup));
        rows(find(rowgroup==0,1,'first')) = true;
        cols = false(size(colgroup));
        nrows = 0;
        ncols = 0;
        while nrows~=nnz(rows)||ncols~=nnz(cols)
            nrows = nnz(rows);
            ncols = nnz(cols);
            cols = any(evolution(rows,:),1);
            rows = any(evolution(:,cols),2);
        end
        rowgroup(rows) = group;
        colgroup(cols) = group;
    end
    % For each tangled group with >=2 rows and >=2 columns
    if any(isfinite(rowgroup))
        for g = 1:max(rowgroup)
            nrows = nnz(rowgroup==g);
            ncols = nnz(colgroup==g);
            if nrows==1||ncols==1
                continue
            end
            % Use binary programming to determine the best untanglement
            func = @(i,j)fluidics.core.dist(tails(i).Value.Circumcenter,...
                items(j).Value.Circumcenter);
            f = arrayfun(func,II(rowgroup==g,colgroup==g),...
                JJ(rowgroup==g,colgroup==g));
            f = fluidics.core.mat2col(f);
            intcon = 1:nrows*ncols;
            A = [repelem(eye(ncols),1,nrows);
                 repmat(eye(nrows),1,ncols)];
            A = vertcat(A,-A);
            b = [repelem(ceil(nrows/ncols),ncols,1);
                 repelem(ceil(ncols/nrows),nrows,1);
                -ones(nrows+ncols,1)];
            lb = zeros(nrows*ncols,1);
            ub = ones(nrows*ncols,1);
            opts = optimoptions('intlinprog','Display','off');
            x = intlinprog(f,intcon,A,b,[],[],lb,ub,opts);
            evolution(rowgroup==g,colgroup==g) = reshape(x,nrows,ncols);
        end
    end
end

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
    root.Children(end+idxOffset,:) = newBranches;
end
