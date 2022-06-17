function DF = partition(cycle,centroids,bwDists)

% Compute a strip of proximity labels
YX = fliplr(fluidics.core.col2cell(ceil(cycle.Points)));
labels = zeros(cycle.Length,1);
labelD = inf(cycle.Length,1);
threshD = 10;
for j = 1:length(bwDists)
    bwDist = bwDists{j};
    D = bwDist(sub2ind(size(bwDist),YX{:}));
    labels(D<min(labelD,threshD)) = j;
end

% Reserve space ahead of time
% Type 1: non-solid connected components that span from one solid region to
% a different solid region
CCT = fluidics.core.bwconncomptoroidal(~labels);
% Dilate by 1
for k = 1:CCT.NumObjects
    list = zeros(length(CCT.PixelIdxList{k})+2,1);
    list(2:end-1) = CCT.PixelIdxList{k};
    list(1) = mod(list(2)-1-1,cycle.Length)+1;
    list(end) = mod(list(end-1),cycle.Length)+1;
    CCT.PixelIdxList{k} = list;
end
% Filter
func = @(L)diff(labels(L([1 end])))~=0;
isKept = cellfun(func,CCT.PixelIdxList);
CCT.NumObjects = nnz(isKept);
CCT.PixelIdxList = CCT.PixelIdxList(isKept);

% Type 2: adjacent points on different solid regions
tape = [labels circshift(labels,-1)];
isSwitch = all(tape,2)&(tape(:,1)~=tape(:,2));
switches = find(isSwitch);
DFCount = CCT.NumObjects+length(switches);
DF = repmat(struct('Points',[],'Endpoints',[]),DFCount,1);

% Extract type 1
for k = 1:CCT.NumObjects
    list = CCT.PixelIdxList{k};
    DF(k).Points = cycle.Points(list,:);
    DF(k).Endpoints = centroids(labels(CCT.PixelIdxList{k}([1 end])),:);
end

% Extract type 2
DFOffset = CCT.NumObjects;
for i = 1:length(switches)
    idx = switches(i);
    list = labels([idx;mod(idx,length(labels))+1]);
    DF(DFOffset+i).Points = cycle.Points(list,:);
    DF(DFOffset+i).Endpoints = centroids(tape(idx,:),:);
end

% Compute parameters:
% - Number of edges
% - Is the displacement front closed? (Probably not)
% - Circumcenter and circumradii
% -
func = @(P)size(P,1)-1;
edgeCounts = num2cell(cellfun(func,{DF.Points}));
[DF.EdgeCount] = deal(edgeCounts{:});

func = @(P)size(P,1)==cycle.Length;
isClosed = num2cell(cellfun(func,{DF.Points}));
[DF.Closed] = deal(isClosed{:});

if any([DF.Closed])
    idx = find([DF.Closed]);
    DF(idx).EdgeCount = DF(idx).EdgeCount+1;
end

circumcenters = cell(length(DF),1);
circumradii = cell(length(DF),1);
for i = 1:length(DF)
    [circumcenters{i},circumradii{i}] = fluidics.core.mincirc(DF(i).Points);
end
[DF.Circumcenter] = circumcenters{:};
[DF.Circumradius] = circumradii{:};
