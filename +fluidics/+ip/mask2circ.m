function [mask,centers] = mask2circ(mask,DEBUG_FLAG)

% Set a debug flag to visualize the mask2circ procedure
if nargin<2
    DEBUG_FLAG = false;
else
    DEBUG_FLAG = true;
end

% Of all solid regions, remove 25% with the highest eccentricity
SCC = regionprops(mask,'Centroid',...
    'MajorAxisLength','MinorAxisLength');
A = vertcat(SCC.MajorAxisLength);
B = vertcat(SCC.MinorAxisLength);
R = round((vertcat(SCC.MajorAxisLength)+vertcat(SCC.MinorAxisLength))./4);
E = sqrt(A.^2-B.^2)./A;
Ethreshold = quantile(E,.75);
Ekept = E<=Ethreshold;
if DEBUG_FLAG
    subplot(2,2,1)
    imshow(uint8(mask)*128);
    for k = 1:length(SCC)
        if ~Ekept(k)
            continue
        end
        cc = SCC(k);
        msgs = {
            sprintf('\\epsilon=%.2g',E(k))
            sprintf('r=%d',R(k))
        };
        text(cc.Centroid(1),cc.Centroid(2),msgs,...
            'FontSize',8,'Color','g','HorizontalAlignment','center')
    end
end
SCC(~Ekept) = [];
R(~Ekept) = [];
clear A B E Ethreshold Ekept

% Of remaining solid regions, obtain a main radius
Rmode = mode(R);
Rkept = abs(R-Rmode)<=10;
if DEBUG_FLAG
    subplot(2,2,2)
    imshow(uint8(mask)*128);
    for k = 1:length(SCC)
        if ~Rkept(k)
            continue
        end
        cc = SCC(k);
        msgs = sprintf('r=%d',R(k));
        text(cc.Centroid(1),cc.Centroid(2),msgs,...
            'FontSize',8,'Color','g','HorizontalAlignment','center')
    end
end
if nnz(Rkept) < 3
    error('Not Implemented for 3 or fewer circles to keep')
end
SCC(~Rkept) = [];
R(~Rkept) = [];
clear Rkept

% Blank truecolor canvas to paint on; will be later thresholded to become
% the refined mask.
H = size(mask,1);
W = size(mask,2);
canvas = zeros([H W 3],'uint8');

% Paint existing centroids!
% +---> X
% |
% v
% Y
XY = vertcat(SCC.Centroid);
canvas = insertShape(canvas,...
    'FilledCircle',[XY R],...
    'Color',       'white',...
    'Opacity',     1,...
    'SmoothEdges', false);

% Find the rest of the places where we place circles
% Voronoi diagram
[VX,VY] = voronoi(XY(:,1),XY(:,2));
VXY = [fluidics.core.mat2col(VX) fluidics.core.mat2col(VY)];
VXY = unique(VXY,'row');
VXY(any(VXY<0|VXY>[W H],2),:) = [];

minsep = min(pdist(XY))/2;
T = cluster(linkage(VXY),...
    'Cutoff',   minsep,...
    'Criterion','distance');
counts = groupcounts(T);

if DEBUG_FLAG
    subplot(2,2,3)
    voronoi(XY(:,1),XY(:,2))
    axis equal tight ij
    % hold on
    % scatter(VXY(:,1),VXY(:,2))
    % hold off
end

for g = fluidics.core.mat2row(find(counts>1)) %#ok<FNDSB>
    % Find groups of voronoi edge vertices that are close
    GXY = VXY(T==g,:);
    % Compute their centroid
    GC = mean(GXY);
    XY = [XY;GC];
    if DEBUG_FLAG
        hold on
        scatter(GC(1),GC(2),'r*')
        hold off
        % Insert shape!
        canvas = insertShape(canvas,...
            'FilledCircle',[GC Rmode],...
            'Color',       'white',...
            'Opacity',     1,...
            'SmoothEdges', false);
    end
end

% Convert to mask
mask = logical(canvas(:,:,1));

if DEBUG_FLAG
    subplot(2,2,4)
    imshow(mask)
end

centers = XY;
