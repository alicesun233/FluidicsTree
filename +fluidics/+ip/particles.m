function P = particles(I,mask)

BW = fluidics.ip.binarize(I,mask);
CC = regionprops(BW,I,'WeightedCentroid');
P = struct('Coordinates',vertcat(CC.WeightedCentroid));
