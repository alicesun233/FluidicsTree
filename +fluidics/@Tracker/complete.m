function branches = complete(obj)

% Obtain handle to the root branch
root = obj.Root;

% Remove all branches that are not direct children from root
func = @(parents)all(parents==root);
isChildOfRoot = cellfun(func,{root.Children.Parents});
root.Children(~isChildOfRoot) = [];

% Mark as complete to avoid recursive calls
obj.IsComplete = true;

% Linearize and number all branches.
branches = obj.Branches;
branchIDs = num2cell(1:length(branches));
[branches.ID] = deal(branchIDs{:});
