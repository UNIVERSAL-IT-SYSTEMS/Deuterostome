#ifndef MATRIX_H
#define MATRIX_H

#include "dm.h" 

#if HAVE_ATLAS && ATLAS_LIB

#define BUILD_ATLAS 1

P op_matmul_blas(void);
P op_decompLU_lp(void);
P op_backsubLU_lp(void);
P op_invertLU_lp(void);
P op_norm2(void);
P op_matvecmul_blas(void);
P op_triangular_solve(void);
P op_givens_blas(void);
P op_rotate_blas(void);
P op_xerbla_test(void);

#endif //BUILD_ATLAS

#endif //MATRIX_H
