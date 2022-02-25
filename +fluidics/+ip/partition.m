function DF = partition(cycle,bwDists)

XY = fluidics.core.col2cell(ceil(cycle.Points));
labels = zeros(1,cycle.Length);
threshD = 20;
for j = 1:length(bwDists)
    D = bwDist(sub2ind(size(bwDist),XY{:}));
    labels(D<threshD) = j;
end

CCT = fluidics.core.bwconncomptoroidal(~labels);
for k = 1:length(CCT)
    list = zeros(length(CCT.PixelIdxList{k})+2,1);
    list(2:end-1) = CCT.PixelIdxList{k};
    list(1) = mod(list(1)-1-1,cycle.Length)+1;
    list(end) = mod(list(end),cycle.Length)+1;
    
end


isSolidV = D<threshD;

if ~any(isSolidV)
    DF = struct('Points',{});
else
    % V        1     2     3
    %    ...---@-----@-----@---...
    % E     0     1     2     3
    isFluidE = ~isSolidV;
    CCT = fluidics.core.bwconncomptoroidal(isSolidV);
    for k = 1:CCT.NumObjects
        switch length(CCT.PixelIdxList{k})
        if ~=cycle.Length
        isFluidE(CCT.PixelIdxList{k}(end)) = false;
    end
end

% Compute parameters
lengths = num2cell(cellfun(@(P)size(P,1),{DF.Points}));
[DF.Length] = deal(lengths{:});