function BW = binarize(I,mask)

BW = false(size(I));
BW(mask) = imbinarize(I(mask));
