function CC = bwconncomptoroidal(BW)
CC = bwconncomp(BW);

if BW(1) && BW(end)
    CC.PixelIdxList{1} = [CC.PixelIdxList{end}; CC.PixelIdxList{1}];
    CC.PixelIdxList(end) = [];
    CC.NumObjects = CC.NumObjects-1;
end
