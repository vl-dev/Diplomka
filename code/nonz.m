load matrix;
S = spconvert(matrix);
S = S + 100*eye(size(S));
L = chol(S,'lower');
nnz(L) - size(S,1)