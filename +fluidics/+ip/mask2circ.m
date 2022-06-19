function [mask,centers] = mask2circ(mask)

% Of all solid regions, remove 25% with the highest eccentricity
SCC = regionprops(mask,'Centroid',...
    'MajorAxisLength','MinorAxisLength');
centers = vertcat(SCC.Centroid);
