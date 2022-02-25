function bc = block2cell(mat,dim1sz,dim2sz)

reps = size(mat)./[dim1sz dim2sz];
bc = mat2cell(mat,repmat(dim1sz,reps(1),1),repmat(dim2sz,reps(2),1));