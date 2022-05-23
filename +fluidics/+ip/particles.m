function P = particles(I,mask,threshold)

BW = fluidics.ip.binarize(I,mask,threshold);
CC = regionprops(BW,I,'WeightedCentroid');
P = struct('Coordinates',vertcat(CC.WeightedCentroid));
