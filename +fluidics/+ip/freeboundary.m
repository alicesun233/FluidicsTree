function FB = freeboundary(P,PS,threshold)

% Mark points as auxiliary
isAuxV = [false(size(P,1),1);true(size(PS,1),1)];

% Construct Delaunay mesh and obtain points, edges, faces
DT = delaunayTriangulation(vertcat(P,PS));
P = DT.Points;
E = DT.edges();
F = DT.ConnectivityList;

% Calculate the length of each edge
lenE = fluidics.core.mat2col(E');
lenE = fluidics.core.block2cell(P(lenE,:),2,2)';
lenE = fluidics.core.block2cell(diff(cell2mat(lenE),1),1,2);
lenE = fluidics.core.mat2col(cellfun(@rssq,lenE));

% Mark edges as auxiliary
% 1. edges with auxiliary vertices
% 2. those longer than the shortest above
isAuxE = any(ismember(E,find(isAuxV)),2);
isAuxE = isAuxE|(lenE>min(lenE(isAuxE)));
% 3. those longer than the length threshold of the remaining edges
%numberOfBins = 256;
%[histN,histE] = histcounts(lenE(~isAuxE),numberOfBins);
%histT = otsuthresh(histN);
%lenThreshE = histE([1 end])*[1-histT;histT];
isAuxE = isAuxE|(lenE>threshold);

% Create an adjacency matrix
% Identify triangles to keep: all three edges are not marked
IJ = fluidics.core.col2cell(E(~isAuxE,:));
S = true(nnz(~isAuxE),1);
M = size(P,1);
A = full(sparse(IJ{:},S,M,M));
EinF = sort(F,2);
EinF = EinF(:,[1 2 2 3 1 3]);
EinF = fluidics.core.block2cell(EinF,1,2);
func = @(sub)A(sub(1),sub(2));
isKeptF = all(cellfun(func,EinF),2);

% Create a map that maps old vertex index to new vertex index,
% update index vertices (for only P and F, E not used here on)
% then construct a mesh with only the kept triangles
keptV = unique(F(isKeptF,:));
map = zeros(length(keptV),1);
map(keptV) = 1:length(keptV);
P = P(keptV,:);
if size(P,1)<3
    FB = [];
    return
end
F = F(isKeptF,:);
F = reshape(map(F),size(F));
XY = fluidics.core.col2cell(P);
T = triangulation(F,XY{:});

% Extract a disconnected free boundary as a list of directed edges
% This information is fragmented and needs assembly
% Also extract other required information
P = T.Points;
E = T.freeBoundary();

% Identify fragment endpoints and concatenate to form cycles
% If the end of a row does not match the beginning of the next row, this
% row is a terminating row. Its next row must then be a starting row.
% Concatenate until all cycles are closed
isFinal = [E(1:end-1,2)~=E(2:end,1);true];
isStart = [true;isFinal(1:end-1)];
lengths = diff([0;find(isFinal)]);
S = struct(...
    'Indices',mat2cell(E(:,1),lengths,1),...
    'Points', mat2cell(P(E(:,1),:),lengths,2),...
    'Length', num2cell(lengths),...
    'Begin',  num2cell(E(isStart,1)),...
    'Final',  num2cell(E(isFinal,2)),...
    'Closed', num2cell(E(isStart,1)==E(isFinal,2)));
while ~all([S.Closed])
    % Find the first open cycle
    i = find(~[S.Closed],1,'first');
    segment = S(i);
    % Find all non-closed cycle that connects after it
    j = find([S.Begin]==segment.Final&~[S.Closed]);
    if length(j)~=1||i==j
        error('Cannot resolve segments')
    end
    segment.Indices = vertcat(segment.Indices,S(j).Indices);
    segment.Points = vertcat(segment.Points,S(j).Points);
    segment.Length = segment.Length+S(j).Length;
    segment.Final = S(j).Final;
    segment.Closed = segment.Begin==segment.Final;
    % Update the free boundary
    S(i) = segment;
    S(j) = [];
end
FB = rmfield(S,{'Begin','Final','Closed'});

% Remove intersections within each loop
for i = 1:length(FB)
    cycle = FB(i);
    F = Inf;
    while any(F>1)
        [M,F] = mode(cycle.Indices);
        if all(F==1)
            break
        end
        m = M(1);
        inds = find(cycle.Indices==m);
        lens = zeros(F,1);
        for j = 1:F
            if j<F
                points = cycle.Points(inds(j):inds(j+1)-1,:);
            else
                points = cycle.Points([inds(F):end 1:(inds(1)-1)],:);
            end
            lens(j) = fluidics.core.perimeter(points);
        end
        % Select the longest sub-cycle
        [~,k] = max(lens);
        if k<F
            cycle.Indices = cycle.Indices(inds(k):inds(k+1)-1);
            cycle.Points = cycle.Points(inds(k):inds(k+1)-1,:);
        else
            cycle.Indices = cycle.Indices([inds(k):end 1:(inds(1)-1)]);
            cycle.Points = cycle.Points([inds(k):end 1:(inds(1)-1)],:);
        end
        cycle.Length = length(cycle.Indices);
    end
    FB(i) = cycle;
end
FB = rmfield(FB,{'Indices'});

% Compute cycle properties
perimeters = num2cell(cellfun(@fluidics.core.perimeter,{FB.Points}));
[FB.Perimeter] = deal(perimeters{:});
circumcenters = cell(length(FB),1);
circumradii = cell(length(FB),1);
for i = 1:length(FB)
    [circumcenters{i},circumradii{i}] = fluidics.core.mincirc(FB(i).Points);
end
[FB.Circumcenter] = circumcenters{:};
[FB.Circumradius] = circumradii{:};

% Sort by descending perimeter
[~,I] = sort([FB.Length],'descend');
FB = FB(I);



