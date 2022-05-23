function counts = triedgehist(P,bins)

% Construct Delaunay mesh and obtain points and edges
DT = delaunayTriangulation(P);
P = DT.Points;
E = DT.edges();

% Calculate the length of each edge
lenE = fluidics.core.mat2col(E');
lenE = fluidics.core.block2cell(P(lenE,:),2,2)';
lenE = fluidics.core.block2cell(diff(cell2mat(lenE),1),1,2);
lenE = fluidics.core.mat2col(cellfun(@rssq,lenE));

% Return a histogram
counts = histcounts(lenE,bins);