function col = row2cell(mat)
col = mat2cell(mat,ones(1,size(mat,1)),size(mat,2));