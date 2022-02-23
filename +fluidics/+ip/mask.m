function [S,F] = mask(R)

% Adaptive binarization with dark foreground
BW = imbinarize(R,'adaptive','ForegroundPolarity','dark');

% Keep the largest connected component which is assumed to be fluid phase
CC = bwconncomp(BW);
numPixels = cellfun(@numel,CC.PixelIdxList);
[~,idx] = max(numPixels);

% Invert largest connected component to become the solid phase
S = true(size(R));
S(CC.PixelIdxList{idx}) = false;

S = imfill(S,'holes');
S = bwareaopen(S,4000);
S = imdilate(S,strel('square',3));

F = ~S;
F = bwareaopen(F,4000);
F = imdilate(F,strel('square',3));

S = ~F;
