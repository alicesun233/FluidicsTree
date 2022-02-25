function [mask,centers] = mask2circ(mask)

% Obtain solid regions and identify median radii
SCC = regionprops(mask,'Centroid',...
    'MajorAxisLength','MinorAxisLength');
SD = mean([[SCC.MajorAxisLength]' [SCC.MinorAxisLength]'],2);
SR = SD/2;
R = median(SR);

% Filter circles with radius within 3px of the median
keepCircle = abs(SR-R)<3;
if nnz(keepCircle) < 3
    error('Not Implemented')
end
SCC(~keepCircle) = [];
SC = vertcat(SCC.Centroid);

% Obtain displacement row vectors
dU = SC(2:end,:)-SC(1,:);

% Linear transformation matrix
T = dU(1:2,:);
if any(abs(eig(T))<1e-6)
    error('Not Implemented: eigenvalues of T too small')
end

% Generate centroid locations
[Ugrid,Vgrid] = ndgrid(-10:10,-10:10);
funcT = @(u,v)SC(1,:)+[u v]*T;
centers = arrayfun(funcT,Ugrid,Vgrid,'UniformOutput',false);

% Remove circles outside the image and prepare to paint
H = size(mask,1);
W = size(mask,2);
Umat = vertcat(centers{:});
Rvec = repmat(R,numel(centers),1);
keepCircle = all((Umat>[-R -R])&(Umat<[W+R H+R]),2);
Umat = Umat(keepCircle,:);
Rvec = Rvec(keepCircle);

% Paint a new canvas with circles
canvas = zeros([H W 3],'uint8');
canvas = insertShape(canvas,'FilledCircle',[Umat Rvec],...
    'Color','white','Opacity',1,'SmoothEdges',false);

% Convert to mask
mask = logical(canvas(:,:,1));

% Save centroids
centers = Umat;
