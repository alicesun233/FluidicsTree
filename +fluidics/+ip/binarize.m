function BW = binarize(I,mask,threshold)

%error('Function disabled')

% BW = imbinarize(I,threshold);
% BW(~mask) = false;
I2 = imbinarize(I);
K = medfilt2(I2);
F = imfill(K,'holes');
BW = bwareaopen(F,8);
