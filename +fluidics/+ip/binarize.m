function BW = binarize(I,mask,threshold)

%error('Function disabled')

BW = imbinarize(I,threshold);
BW(~mask) = false;
