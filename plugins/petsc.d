| -*- mode: d; -*-

/PETSC 200 {

  |============== Global definitions ==========================

  |----------------- ksptypes -------------------
  | Enumeration for kspsettings for ksp_create.
  | Defines the Krylov-type solver used in petsc.
  | Each one may be associated with a data structure
  |  (kspparam) defined by petsc_ksp_create in dmpetsc.c.in
  |
  /ksptypes {
    /RICHARDSON
    /CHEBYCHEV
    /CG
    /CGNE
    /STCG
    /GLTR
    /GMRES
    /FGMRES
    /LGMRES
    /TCQMR
    /BCGS
    /BCGSL
    /CGS
    /TFQMR
    /CR
    /LSQR
    /PREONLY
    /QCG
    /BICG
    /MINRES
    /SYMMLQ
    /LCD
    * /DEFAULT
  } makeenum def

  |------------------ pctypes -----------------------
  | Enumeration for kspsettings for ksp_create
  | Defines the preconditioner for the solver defined by
  |  ksptypes.
  | Each one may be associated with a data structure
  |  (pcparam) defined by petsc_ksp_create in dmpetsc.c.in
  |
  /pctypes {
    /NONE
    /JACOBI
    /SOR
    /LU
    /SHELL
    /BJACOBI
    /MG
    /EISENSTAT
    /ILU
    /ICC
    /ASM
    /KSP
    /COMPOSITE
    /REDUNDANT
    /SPAI
    /NN
    /CHOLESKY
    /SAMG
    /PBJACOBI
    /MAT
    /HYPRE
    /FIELDSPLIT
    /TFS
    /ML
    /PROMETHEUS
    /GALERKIN
    /OPENMP
    /BJACOBI_ILU
    /BJACOBI_LU
    * /DEFAULT
  } makeenum def

  /monitortypes {
    /Off
    /TrueResidualNorm
    /SingularValue
    * /Default
  } makeenum def

  |------------------------- in_petsc -----------------
  | ~act in_petsc | ...
  |
  | executes ~act in PETSC dictionary.
  |
  /in_petsc {PETSC indict} bind def

  |----------------------- notin_petsc -----------------
  | ~act notin_petsc | ...
  |
  | Removes the top PETSC dict(s) from the dictionary stack
  |   executes act, and then replaces them.
  |
  /notin_petsc {PETSC notindict} bind def

  | object | object
  /_cap {
    dup /sv get capsave
  } bind def

  | object1 | object2
  /_transcribe {
    save exch transcribe | sv o2
    exch 1 index /sv put | o2
  } bind def

  | object | --
  /_destroy {
    /sv get restore
  } bind def

  /destroyers {
    /matrix mat_destroy
    /vector vec_destroy
    /ksp    ksp_destroy
  } makestruct def

  | object | /ptype
  /getptype {/ptype get} bind def

  | funcmap object | ...
  /execptype {getptype get exec} bind def

  | object | --
  /destroy {
    destroyers 1 index execptype
  } bind def

  |================= dpawn definitions ===========================
  | Mapping from dnode functions to dpawn jobs associated with that
  | function. In general, the mapping has the same name on both
  | sides.
  | All these dpawn procedures are collective -- they must be called
  |  on all dpawns in the same order.
  |
  /dpawn {
    | load the operator dictionary on module load.
    getplugindir (dmpetsc.la) loadlib /petsc_oplib name
    
    |---------------------------------- vec_create
    | /x n | --
    |
    | Creates local vector with n local elements,
    | and names it /x.
    |
    /vec_create {
      save exch petsc_vec_create 
      /vector openlist /sv /vector /ptype
      makestruct_stack _cap def
    } bind def
    
    /_getvector {/vector get} bind def

    |------------------------------------ vec_fill
    | x <d > | --
    |
    | Copies the elements from the d array into the vectors
    | local elements. Ie, <d > should have the same number
    | of elements as the vector has locally.
    |
    /vec_fill {
      0 3 -1 roll _getvector petsc_vec_copyto pop
    } bind def

    | <d > X i | -- 
    /vec_copyto {
      exch _getvector petsc_vec_copyto pop
    } bind def

    | X | --
    /vec_syncto {
      _getvector petsc_vec_syncto pop
    } bind def

    | X <d > | --
    /vec_interval {
      exch _getvector exch
      1 index dup /gn get exch /n get getinterval vec_fill
    } bind def

    |------------------------------------- mat_creator

    |--------- mat_creators --------------
    | ... | A
    |
    | Calls the mat_creator for a specific matrix type,
    | eating the associated parameters.
    /mat_creators {
      | mmax N <l irows> <l icols> n save | A
      | Yale compressed format sparse matrix. 
      | n is the local number of columns (the diagonal matrix)
      | irow is the offsets in to icol to start each row (local offset)
      | and is one longer than the number of rows \(last is one past the
      |   the last row\).
      /sparse {
        6 1 roll
        3 1 roll 2 copy 5 -1 roll         | sv mmax N irows icols irows icol n
        petsc_mat_sparse_create           | sv mmax N irows icols A_
        5 1 roll dup length /l array copy | sv A_ mmax N irows icols_
        exch     dup length /l array copy | sv A_ mmax icols_ irows_
        /sparse /matrix
        openlist /sv /matrix /mmax /N /icols /irows /mtype /ptype
        makestruct_stack
      }

      | mmax N m n save | A
      | Dense column oriented matrix. m is the number of rows,
      | n is the number of columns.
      /dense {
        5 1 roll
        petsc_mat_dense_create | sv mmax N A_
        /dense /matrix
        openlist /sv /mmax /N /matrix /mtype /ptype 
        makestruct_stack
      }

      | mmax N m n M save | A
      /blockdense {
        6 1 roll
        4 -1 roll 2 copy 6 2 roll   | sv mmax M N m n M N
        petsc_mat_blockdense_create | sv mmax M N A_
        /blockdense /matrix
        openlist /sv /mmax /M /N /matrix /mtype /ptype 
        makestruct_stack
      }
    } bind makestruct def

    |----------------------- _getmatrix -----------------------
    | Adict | A
    /_getmatrix {/matrix get} bind def

    |---------------------- _gettype --------------------------
    | Adict | /mtype
    /_gettype {/mtype get} bind def

    |--------------------- _exectype --------------------------
    | execdict Adict | ...
    /_exectype {_gettype get exec} bind def

    |-------------- mat_create -------------------
    | /A mmax .... /type | --
    |
    | The generic creator. Creates a matrix of /type (dense, sparse, etc)
    | that will be named /A, with the parameters for it's matching
    | mat_creator in between.
    |
    /mat_create {
      save mat_creators 3 -1 roll get exec
      _cap def
    } bind def

    |------------------------------------ mat_transpose
    |
    | A | -- (A=At)
    |    
    /mat_transpose {
      _getmatrix petsc_mat_transpose
    } bind def

    | A mmax N | --
    /mat_transpose_update {
      2 index /N    put
      1 index /mmax put
      mat_transposers 1 index _exectype
    } bind def

    | A | --
    /mat_transposers {
      | Atdict | --
      /dense pop
      /blockdense pop
      | Atdict | --
      /sparse {
        dup _getmatrix                     | Atdict At
        dup /MATRIX_M get 1 add /l array   | Atdict At <l irows>
        1 index petsc_mat_getnzs /l array  | Atdict At <l irows> <l icols>
        3 -1 roll petsc_mat_getcsr         | Atdict <l irows> <l icols>
        2 index /icols put                 | Atdict <l irows>
        exch    /irows put                 | --
      }
    } bind makestruct def
    

    |------------------------------------ mat_fill


    |---------------- mat_fill ---------------
    | A ~row-maker | --
    | row-maker: A row | <d data> <l icols>
    |
    | Fills a matrix of any type row by row.
    | A is the matrix, mmax is the largest number of rows
    |  on any pawn, and ~row-maker creates/returns the data
    |  for each row.
    | ~row-maker gets the matrix and current local row index,
    |   and returns the data for that rows, and the column numbers
    |   matching each element of data. For dense matrices, that would
    |   be an l array of 0...N-1.
    |
    /mat_fill {
      {
        /filler name                      | A
        dup /mmax get exch                | mmax A
        _getmatrix                        | mmax A_

        0 1 2 index /MATRIX_M get 1 sub { | mmax A_ row
          2 copy /filler find notin_petsc | mmax A_ row <d> <l>
          4 -2 roll exch petsc_mat_fill   | mmax A_
        } for
        
        exch 1 index /MATRIX_M get sub ~petsc_mat_syncfill repeat | A_
        petsc_mat_endfill                                         | A_
        pop
      } in_petsc
    } bind def

    |-------------- mat_fillers_map ----------------------
    | A | ~row-maker
    | row-maker: <d data> | <d row> <l icols>
    |
    | the base of the ~row-maker procedure for each matrix type.
    | Takes the data (compressed) for the entire matrix, and chops
    | off the current row, and the current associated column numbers
    | Expects /row to be defined.
    |
    /mat_fillers_map {
      /sparse {
        dup /icols get /icols name
            /irows get /irows name
        {
          irows row get irows row 1 add get 1 index sub getinterval
          icols irows row get irows row 1 add get 1 index sub getinterval
        }
      }

      /dense {
        /N get /N name
        /mat_fillers_layer {
          /icols N /l array 0 1 index length 0 1 ramp pop def
        } exch inlayer
        {
          row N mul N getinterval 
          icols
        }
      }

      /blockdense {
        /N get /N name
        /mat_fillers_layer {
          /icols N /l array 0 1 index length 0 1 ramp pop def
        } exch inlayer
        {
          row N mul N getinterval 
          icols
        }
      }
    } bind makestruct def

    |-------------------- mat_fill_data ----------------------
    | A data | --
    |
    | Fills matrix A with the data (compressed). 
    | A is the matrix.
    | data is a <d > array, with the compressed data.
    | ... are the type specific parameters.
    |
    /mat_fill_data {
      {
        /data name
        dup mat_fillers_map 1 index _exectype /data_filler name
        {/row name pop data data_filler} mat_fill
        /mat_fillers_layer {} exch inlayer
      } in_petsc
    } bind def

    |----------------------------------------------mat vec mul
    |
    |---------------------- matvecmul_petsc ----------------------
    | y beta A trans x alpha | --
    | 
    | y = beta*y + alpha*A*x
    |
    /matvecmul_petsc {
      6 -1 roll _getvector 5 1 roll
      4 -1 roll _getmatrix 4 -1 roll
      exch _getvector exch
      petsc_mat_vecmul pop
    } bind def
    
    |----------------------- get_matvecmul ----------------------
    | y beta A trans x alpha | --
    | 
    | y = beta*y + alpha*A*x
    | return y to node
    |
    /get_matvecmul {
      5 index _getvector 5 1 roll
      4 -1 roll _getmatrix 4 1 roll
      exch _getvector exch
      petsc_mat_vecmul pop get_vector
    } bind def

    | mmax N save A_ | A
    /mat_matmulsu_create {
      /dense {
        /dense /matrix 
        openlist /mmax /N /sv /matrix /mtype /ptype 
        makestruct_stack
      }

      /sparse {
        dup /MATRIX_M get 1 add /l array
        1 index petsc_mat_getnzs /l array
        2 index petsc_mat_getcsr
        /sparse /matrix 
        openlist /mmax /N /sv /matrix /irows /icols /mtype /ptype
        makestruct_stack
      }
    } bind makestruct def

    |-------------------------- mat_matmulsu -------------------------
    | /C mmax N /type A transA B transB fill/* | --
    | fill = nz(C)/(nz(A)+nz(B))
    /mat_matmulsu {
      save 6 1 roll                 | /C mmax N sv /type A transA B transB f
      3 -1 roll _getmatrix 3 1 roll | /C mmax N sv /type A transA B_ transB f
      5 -1 roll _getmatrix 5 1 roll | /C mmax N sv /type A_ transA B_ transB f
      petsc_mat_matmulsu            | /C mmax N sv /type C_
      mat_matmulsu_create 3 -1 roll get exec | /C C
      _cap def                      | --
    } bind def

    |------------------------- mat_matmul ----------------------------
    | C A transA B transB | --
    |
    | C = At?*Bt
    |
    /mat_matmul {
      exch _getmatrix exch
      4 -1 roll _getmatrix 4 1 roll
      5 -1 roll _getmatrix 5 -1 roll
      petsc_mat_matmul pop
    } bind def

    |-------------------------- matzero -------------------------------
    | A | --
    | 
    | A = 0
    /mat_zero {
      _getmatrix petsc_mat_zero pop
    } bind def

    |-------------------------- matmul_petsc --------------------------
    | A a | -- 
    | A *= a
    |
    /mat_mul {
      exch _getmatrix exch petsc_mat_mul pop
    } bind def

    |-------------------------- matadd --------------------------------
    | A B | --
    | A += B
    | A & B must have the same shape.
    /mat_matadd {
      _getmatrix exch _getmatrix exch petsc_mat_matadd pop
    } bind def
    
    |--------------------------------------------------- get_vector 
    | x | --
    |
    | Return the local elements of x to node.
    |
    /get_vector {
      {
        _getvector
        dup 0 1 index /VECTOR_N get /d array petsc_vec_copyfrom
        ~[3 1 roll exch /VECTOR_GN get ~recv_vector_result] rsend
      } in_petsc
    } bind def

    |----------------------------------------------------- get_matrix
    |

    |---------------------- matrixers_get ---------------------------
    | A | local_interval_start
    |
    | return the type specific start of the local interval for the
    |  current row.
    | /row is defined before calling.
    /matrixers_get {
      /sparse {
        /irows get row get
      }
      /dense {
        row exch /N get mul
      }
      /blockdense {
        row exch /N get mul
      }
    } bind makestruct def

    | A | --
    /matrix_result {
      {
        {/N get /d array /t name} /matrix_result_layer inlayer
      } in_petsc
    } bind def
    
    |------------------------ get_matrix ------------------------------
    | A | --
    |
    | Returns the local data, row by row, to the node.
    | A is the matrix
    | type is the the type of A: /dense, /sparse, ...
    /get_matrix {
      {
        dup _getmatrix                        | A A_

        0 1 2 index /MATRIX_M get {/row name  | A A_ 
          dup row 0 t petsc_mat_copyfrom      | A A_ t
          ~[
            exch 
            mpirank
            4 index matrixers_get 1 index _exectype
            ~recv_matrix_result
          ] rsend                             | A A_
        } for
        exch /mmax get 1 index /MATRIX_M get sub ~petsc_mat_syncfrom repeat 
        pop
      } in_petsc
    } bind def

    /matrix_result_end {
      {
        /matrix_result_layer known {matrix_result_layer restore} if
      } in_petsc
    } bind def

    |----------------------------------------------------- get_matrix
    |
    |---------------------- densematrixers_get ---------------------------
    | A | column-info...
    |
    | return the type specific start of the local interval for the
    |  current row.
    | /row is defined before calling.
    /densematrixers_get {
      | A | icols
      /sparse {
        dup /icols get 1 index /irows get row get dup | A icols rowi rowi
        4 -1 roll /irows get row 1 add get exch sub   | icols rowi rowlen
        getinterval                                   | icols-interval
      }
      | A | --
      /dense pop
      | A | --
      /blockdense pop
    } bind makestruct def


    |------------------------ get_densematrix ------------------------------
    | A | --
    |
    | Returns the local data, row by row, to the node.
    | A is the matrix
    /get_densematrix {
      {
        dup _getmatrix                        | A A_
        0 1 2 index /MATRIX_M get {/row name  | A A_
          dup row 0 t petsc_mat_copyfrom      | A A_ t
          ~[
            exch 
            2 index /MATRIX_GM get row add
            4 index densematrixers_get 1 index _exectype
            ~recv_densematrix_result
          ] rsend
        } for                                 | A A_
        exch /mmax get 1 index /MATRIX_M get sub ~petsc_mat_syncfrom repeat 
        pop
      } in_petsc
    } bind def

    |----------------------------------------------- ksp_create
    | /ksp kspsettings | --
    |
    | Creates ksp solver named /ksp, with the data in kspsettings.
    | See kspsettings on node for their definitions.
    |
    /ksp_create {
      {
        save
        {
          ksptype kspparam pctype pcparam monitortype petsc_ksp_create
          dup rtol atol dtol maxits petsc_ksp_tol
        } 3 -1 roll indict
        /ksp
        openlist /sv /ksp /ptype 
        makestruct_stack
      } in_petsc 
      _cap def
    } bind def

    /_getksp {/ksp get} bind def

    |--------------------------------------------- vec_destroy
    | x | --
    |
    | Deallocate local portion of vector x, both in D and Petsc.
    |
    /vec_destroy {
      dup _getvector petsc_vec_destroy
      _destroy
    } bind def
    
    |--------------------------------------------- mat_destroy
    | A | -- 
    |
    | Deallocate local portion of matrix m, both in D and Petsc.
    |
    /mat_destroy {
      dup _getmatrix petsc_mat_destroy
      _destroy
    } bind def

    |--------------------------------------------- mat_dup
    | /B A | --
    |
    /mat_dup {
      dup _transcribe     | /B A B
      exch _getmatrix     | /B B A_
      dup petsc_mat_dup   | /B B A_ B_
      petsc_mat_copy      | /B B B_
      1 index /matrix put | /B B
      _cap def            | --
    } bind def

    |-------------------------------------------- mat_copy
    | B A | --
    | A=B
    /mat_copy {
      _getmatrix exch _getmatrix exch petsc_mat_copy pop
    } bind def

    |---------------------------------------------mat_dup_shape
    | /B A | --
    /mat_dup_shape {
      dup _transcribe                | /B A B
      exch _getmatrix petsc_mat_dup  | /B B B_
      1 index /matrix put            | /B B
      _cap def                       | --
    } bind def

    |--------------------------------------------- vec_dup
    | /y x | --
    |
    /vec_dup {
      dup _transcribe      | /y x y
      exch _getvector      | /y y x_
      dup petsc_vec_dup    | /y y x_ y_
      petsc_vec_copy       | /y y y_
      1 index /vector put  | /y y
      _cap def             | --
    } bind def

    | x y | y_i = x_i
    /vec_copy {
      _getvector exch _getvector exch petsc_vec_copy pop
    } bind def

    | x a | -- x_i += a
    /vec_add {
      exch _getvector exch petsc_vec_add pop
    } bind def

    | x a | -- x_i*=a
    /vec_mul {
      exch _getvector exch petsc_vec_mul pop
    } bind def

    | x a | -- x_i^=a
    /vec_pwr {
      exch _getvector exch petsc_vec_pwr pop
    } bind def

    | x | -- x_i=sqrt(x_i)
    /vec_sqrt {
      _getvector petsc_vec_sqrt pop
    } bind def

    | x | -- x_i=1/x_i
    /vec_reciprocal {
      _getvector petsc_vec_reciprocal pop
    } bind def

    | x d | -- x_i = d iff x_i == *
    /vec_denan {
      exch _getvector exch petsc_vec_denan pop
    } bind def

    | x y | -- x_i*=y_i
    /vecvec_mul {
       _getvector exch _getvector exch petsc_vecvec_mul pop
    } bind def

    | x a y b | -- x_i=a*x_i+b*y_i
    /vecvec_add {
      exch _getvector exch
      4 -1 roll _getvector 4 1 roll
      petsc_vecvec_add pop
    } bind def

    |================ Need to gather from all processors
    | x offsetX len/* A m offsetA | -- A_mc=x_c
    /vecmat_copyrow {
      6 -1 roll _getvector 6 1 roll
      3 -1 roll _getmatrix 3 1 roll
      petsc_vecmat_copyrow pop
    } bind def

    | ... A | <L col...> A
    /vecmat_copycolers ~[
      | <L col...> A | <L col...> A
      /dense null mkact
      | <L col...> A | <L col...> A
      /blockdense null mkact

      | col first-row n A | <L col...> A
      /sparse {
        {
          4 1 roll
          /l array /cols name /frow name /col name
          dup /icols get /icols name
          dup /irows get /irows name
          irows frow cols length getinterval | subirows
          0 exch {
            col add icols exch get cols 2 index put
            1 add
          } forall pop
          cols exch
        } in_petsc
      }
    ] bind makestruct def

    | x local-offsetX local-offsetA ... A | -- A_mc = x_m
    /vecmat_copycol {
      vecmat_copycolers 1 index _exectype
      _getmatrix
      5 -1 roll _getvector 5 1 roll
      petsc_vecmat_copycol pop
    } bind def

    | A | --
    /vecmat_copy_end {
      _getmatrix petsc_mat_endfill pop
    } bind def

    | x A | -- 
    /vecmat_sync {
      _getmatrix 
      exch _getvector exch
      petsc_vecmat_sync pop
    } bind def

    |---------------------------------------------- ksp_destroy
    | ksp | --
    |
    | Deallocate local portion of solver ksp, both in D and Petsc.
    /ksp_destroy {
      dup _getksp petsc_ksp_destroy
      _destroy
    } bind def

    |------------------------------------------------- ksp_solve
    |
    |---------------- report --------------------------
    | If true, dump number of iterations to convergence
    /report true def
    |---------------- reportbuf -----------------------
    | Buffer for convergence reporting
    /repbuf 255 /b array def
    
    |----------------------- ksp_solve -------------------------
    | ksp A/null x b | --
    |
    | Use ksp to solve for x in Ax = b.
    | Reports iterations to convergence if /report=true
    | If A is null, re-uses the last last matrix A used with 
    | solver ksp. Should be more efficient in that case.
    |
    /ksp_solve {
      {
        _getvector
        exch _getvector exch
        3 -1 roll dup null ne ~_getmatrix if 3 1 roll
        4 -1 roll _getksp dup /ksp_ name 4 1 roll
        petsc_ksp_solve pop

        mpirank 0 eq {
          report {
            repbuf 0 (Convergence iterations: ) fax 
            * ksp_ petsc_ksp_iterations * number
            (\n) fax
            0 exch getinterval toconsole
          } if
        } if
      } in_petsc
    } bind def

    |--------------- get_ksp_solve --------------------
    | ksp A/null x b | --
    |
    | Calls ksp_solve, and then returns the local portion
    | of x to the node.
    |
    /get_ksp_solve {
      1 index 5 1 roll ksp_solve get_vector
    } bind def

    | row column A | d
    /mat_get {
      _getmatrix petsc_mat_get
    } bind def
  } def

  |=================== dnode definitions ======================
  |
  | These functions are either internal functions, or the top
  | layer that allocates the jobs to the pawns for the petsc
  | functions.
  /dnode {
    |------------------------------------------------- internal
    |
    |----------------- range --------------------------
    | pawnnum elements | offset length
    |
    | chops elements into ranges for a pawn.
    | pawnnum: rank of the pawn for which we want a range.
    | elements: the number of rows or such that we want to
    |  get the local range for pawnnum
    | offset: the global offset of the first element locally
    |  on pawnnum
    | length: the number of elements locally on pawnnum
    |
    /range {
      mpidata /pawns get      | p# es ps
      3 copy div mul 4 1 roll | off p# es ps
      
      3 copy div exch         | off p# es ps len p#
      2 index 1 sub eq {      | off p# es ps len
        3 copy pop mod add    | off p# es ps len
      } if
      4 1 roll pop pop pop    | off len
    } bind def

    |----------------- rangesize -----------------
    | pawnnum elements | length
    |
    | returns 'length' from 'range'
    |
    /rangesize {range exch pop} bind def

    |------------------ rangestart ----------------
    | pawnnum elements | offset
    |
    | returns 'offset' from 'range'
    |
    /rangestart {range pop} bind def

    |---------------- getid -----------------------
    | obj-dict | ~id
    |
    | For the object dict, return the name on the pawns
    |  as an active name to be executed on the pawn.
    |
    /getid {/id get mkact} bind def

    |------------------ exectype -----------------
    | funcdict matrix-dict | ...
    |
    | For a dictionary of procedures named by matrix type,
    |  execute the procedure associated with the type
    |  of the matrix.
    |
    /exectype {/mtype get get exec} bind def

    |------------------- gettype -----------------
    | matrix-dict | mtype
    |
    | return the type as a passive name associated with
    |  the matrix.
    |
    /gettype {/mtype get} bind def
    
    |---------------------------------------------- vec_create
    | /x N | xdict
    |
    | Call vec_create on the pawns.
    | Takes the name for the vector on the pawns, and the global
    |  length of the vector,
    |  and returns a dictionary describing that vector.
    |
    /vec_create {
      {
        save /vector 
        openlist /id /N /sv /ptype
        makestruct_stack
        dup /xval name 
        {~[
          xval /id get
          3 -1 roll xval /N get rangesize 
          ~vec_create
        ]} execpawns
        _cap
      } in_petsc
    } bind def

    | /x <d > | xdict
    /vec_createfrom {
      dup length exch 3 1 roll vec_create
      dup 3 1 roll vec_copyto
    } bind def

    | <d >/~active x | --
    /vec_copyto {
      {/xval name /darr name
        {
          ~[
            exch 
            /darr find dup active ~construct_exec {
              xval /N get range getinterval
            } ifelse
            xval getid
            0 ~vec_copyto
          ]
        } execpawns
      } in_petsc
    } bind def

    |------------------------------------- vec_dup
    | /y x | y
    |
    | Call vec_dup on pawns.
    | Takes the name for the destination vector on the pawns,
    |  and the source diction of the vector,
    |  and creates a duplicate (including data) with the name
    |  on the pawns.
    | Returns a new dictionary referring to the duplicate vector.
    |
    /vec_dup {
      _transcribe          | /y y
      2 copy ~[3 1 roll getid ~vec_dup] sexecpawns  | /y y
      exch 1 index /id put | y
      _cap                 | y
    } bind def

    | x y | y (y_i=x_i)
    /vec_copy {
      dup 3 1 roll
      {
        ~[
          3 -1 roll getid
          3 -1 roll getid
          ~vec_copy
        ] sexecpawns
      } in_petsc
    } bind def

    | x a | x (x_i += a)
    /vec_add {
      {
        1 index 3 1 roll
        ~[
          3 -1 roll getid
          3 -1 roll
          ~vec_add
        ] sexecpawns
      } in_petsc
    } bind def

    | x a | x (x_i -= a)
    /vec_sub {
      neg vec_add
    } bind def
    
    | x a | x (x_i *= a)
    /vec_mul {
      1 index 3 1 roll
      ~[
        3 -1 roll getid
        3 -1 roll
        ~vec_mul
      ] sexecpawns
    } bind def

    | x a | x (x_i /= a)
    /vec_div {
      1d exch div vec_mul
    } bind def

    | x | x (x_i *= -1)
    /vec_neg {
      -1 vec_mul
    } bind def

    | x a | x (x_i ^= a)
    /vec_pwr {
      {
        1 index 3 1 roll
        ~[
          3 -1 roll getid
          3 -1 roll
          ~vec_pwr
        ] sexecpawns
      } in_petsc
    } bind def

    | x | x (x_i = sqrt(x_i))
    /vec_sqrt {
      ~[
        1 index getid ~vec_sqrt
      ] sexecpawns
    } bind def
    
    | x | x (x_i = 1/x_i)
    /vec_reciprocal {
      ~[
        1 index getid ~vec_reciprocal
      ] sexecpawns
    } bind def

    | x d | x (x_i = d iff x_i == *)
    /vec_denan {
      1 index 3 1 roll
      ~[
        3 -1 roll getid
        3 -1 roll
        ~vec_denan
      ] sexecpawns
    } bind def

    | x y | x(x_i *= y_i)
    /vecvec_mul {
      {
        1 index 3 1 roll
        ~[
          3 -1 roll getid
          3 -1 roll getid
          ~vecvec_mul
        ] sexecpawns
      } in_petsc
    } bind def
    
    | x a y b | x (x_i = a*x_i + b*y_i)
    /vecvec_add {
      {
        3 index 5 1 roll
        ~[
          5 -1 roll getid
          5 -1 roll
          5 -1 roll getid
          5 -1 roll
          ~vecvec_add
        ] sexecpawns
      } in_petsc
    } bind def

    | x y | x (x_i += y_i)
    /vecvec_adds {
      1 exch 1 vecvec_add
    } bind def
    
    | x offsetX length/* A m offsetA | A (A_mc = x_c)
    /vecmat_copyrow {
      {
        /offA name /row name /Aval name /len name /offX name /xval name
        /syncer ~[xval getid Aval getid ~vecmat_sync] def
        {
          Aval /m get range
          1 index add row le {pop /syncer find} {
            dup row gt {pop /syncer find} {
              ~[
                xval getid offX len
                Aval getid
                row 9 -1 roll sub offA
                ~vecmat_copy
              ]
            } ifelse
          } ifelse
        } execpawns
        Aval
      } in_petsc
    } bind def

    | col first-row n-rows | ...
    /vecmat_copycolers ~[
      | col first-row n-rows | <L col...>
      /dense {
        exch pop 0 exch getinterval
      }
      | col first-row n-rows | <L col...>
      /blockdense {
        exch pop 0 exch getinterval
      } 

      | col first-row n-rows |  col first-row n-rows
      /sparse null mkact
    ] bind makestruct def

    | x offsetX length/* A c offsetA | A (A_mc =  x_m)
    /vecmat_copycol {
      {
        /offA name /col name /Aval name /len name /offX name /xval name
        len * eq {/len xval /n get offX sub def} if

        /syncer ~[xval getid Aval getid ~vecmat_sync] def
        {
          Aval /m get range /lrows name /lstart name
          offA len add lstart le {/syncer find} {
            offA lstart lrows add ge {/syncer find} {
              /loffA offA lstart sub dup 0 lt {pop 0} if def
              /loffX offX lstart loffA add offA sub add def
              /llen  len loffX offX sub sub 
                     lrows loffA sub 
                     2 copy gt ~exch if pop
              def
              ~[
                xval getid loffX loffA
                col loffA llen vecmat_copycolers Aval exectype
                Aval getid
                ~vecmat_copycol
              ]
            } ifelse
          } ifelse
        } execpawns
        Aval
      } in_petsc
    } bind def

    | A | A
    /vecmat_copy_end {
      {
        ~[1 index getid ~vecmat_copy_end] sexecpawns
      } in_petsc
    } bind def

    | d X i | --
    /vec_put {
      {/i name /xval name /d name
        /syncer ~[xval getid ~vec_syncto] def
        {
          xval /N get range 
          1 index add i le {pop /syncer find} {
            dup i gt {pop /syncer find} {
              ~[
                <d 0> d 1 index 0 put
                xval getid 
                i 5 -1 roll sub
                ~vec_copyto
              ]
            } ifelse
          } ifelse
        } execpawns
      } in_petsc
    } bind def

    |-------------------------------------------------- vec_fill
    | xval ~data | --
    |
    | Call vec_fill on the pawns.
    | xval: the node dictionary describing the vector.
    | ~data: an executable object on the pawns that will return
    |    a d-array with the local elements to fill the vector.
    |
    /vec_fill {
      {
        ~[3 -1 roll getid 3 -1 roll construct_exec ~vec_fill] sexecpawns
      } in_petsc
    } bind def

    | xval <d > | xval
    /vec_interval {
      {
        /arr name /xval name
        {
          ~[
            xval getid
            arr 4 -1 roll arr length range getinterval
            ~vec_fill
          ]
        } execpawns
        xval
      } in_petsc
    } bind def

    | xval <d > off | xval
    /vec_subinterval {
      {
        /off name /arr name /xval name
        /arrm off arr length add def
        /syncer ~[xval getid ~vec_syncto] def
        {
          arrm range /lenp name /offp name
          offp lenp add offp lt {/syncer find} {
            offp arrm gt {/syncer find} {
              /st offp off sub dup 0 lt {pop 0} if def
              /len lenp st offp sub dup 0 gt ~sub ~pop ifelse def
              st lenp add arrm gt {/lenp arrm st sub def} if
              ~[
                xval getid
                arr st lenp getinterval
                st offp sub
                ~vec_copyto
              ]
            } ifelse
          } ifelse
        } execpawns
      } in_petsc
    } bind def

    | xval <d > off | xval
    /vec_subinterval {
      {
        /off name /arr name /xval name
        /arrm off arr length add def
        /syncer ~[xval getid ~vec_syncto] def
        {
          arrm range /lenp name /offp name
          offp lenp add offp lt {/syncer find} {
            offp arrm gt {/syncer find} {
              /st offp off sub dup 0 lt {pop 0} if def
              /len lenp st offp sub dup 0 gt ~sub ~pop ifelse def
              st lenp add arrm gt {/lenp arrm st sub def} if
              ~[
                xval getid
                arr st lenp getinterval
                st offp sub
                ~vec_copyto
              ]
            } ifelse
          } ifelse
        } execpawns
      } in_petsc
    } bind def

    | xval <d > off | xval
    /vec_subinterval {
      {
        /off name /arr name /xval name
        /arrm off arr length add def
        /syncer ~[xval getid ~vec_syncto] def
        {
          arrm range /lenp name /offp name
          offp lenp add offp lt {/syncer find} {
            offp arrm gt {/syncer find} {
              /st offp off sub dup 0 lt {pop 0} if def
              /len lenp st offp sub dup 0 gt ~sub ~pop ifelse def
              st lenp add arrm gt {/lenp arrm st sub def} if
              ~[
                xval getid
                arr st lenp getinterval
                st offp sub
                ~vec_copyto
              ]
            } ifelse
          } ifelse
        } execpawns
      } in_petsc
    } bind def

    | xval <d > off | xval
    /vec_subinterval {
      {
        /off name /arr name /xval name
        /arrm off arr length add def
        /syncer ~[xval getid ~vec_syncto] def
        {
          arrm range /lenp name /offp name
          offp lenp add offp lt {/syncer find} {
            offp arrm gt {/syncer find} {
              /st offp off sub dup 0 lt {pop 0} if def
              /len lenp st offp sub dup 0 gt ~sub ~pop ifelse def
              st lenp add arrm gt {/lenp arrm st sub def} if
              ~[
                xval getid
                arr st lenp getinterval
                st offp sub
                ~vec_copyto
              ]
            } ifelse
          } ifelse
        } execpawns
      } in_petsc
    } bind def

    | xval <d > off | xval
    /vec_subinterval {
      {
        /off name /arr name /xval name
        /arrm off arr length add def
        /syncer ~[xval getid ~vec_syncto] def
        {
          arrm range /lenp name /offp name
          offp lenp add offp lt {/syncer find} {
            offp arrm gt {/syncer find} {
              /st offp off sub dup 0 lt {pop 0} if def
              /len lenp st offp sub dup 0 gt ~sub ~pop ifelse def
              st lenp add arrm gt {/lenp arrm st sub def} if
              ~[
                xval getid
                arr st lenp getinterval
                st offp sub
                ~vec_copyto
              ]
            } ifelse
          } ifelse
        } execpawns
      } in_petsc
    } bind def

    | xval <d > off | xval
    /vec_subinterval {
      {
        /off name /arr name /xval name
        /arrm off arr length add def
        /syncer ~[xval getid ~vec_syncto] def
        {
          arrm range /lenp name /offp name
          offp lenp add offp lt {/syncer find} {
            offp arrm gt {/syncer find} {
              /st offp off sub dup 0 lt {pop 0} if def
              /len lenp st offp sub dup 0 gt ~sub ~pop ifelse def
              st lenp add arrm gt {/lenp arrm st sub def} if
              ~[
                xval getid
                arr st lenp getinterval
                st offp sub
                ~vec_copyto
              ]
            } ifelse
          } ifelse
        } execpawns
      } in_petsc
    } bind def

    |------------------------------------------------- mat_create
    |
    |----------------- condense_sparse ---------------------
    | A | icols_off
    |
    | Calculates the global offsets of the first row for each
    |  pawn for a sparse matrix.
    |
    | icols_off: a list of the global offsets for the first row on
    |  each pawn. The last element is the offset of the row past the 
    |  last row of the matrix.
    |  In other words, icols_off[0]=0, icols_off[# of pawns]=global size
    |    of matrix -- just the non-zero elements.
    |
    | Called by /sparse of mat_creators_set.
    |
    /condense_sparse {
      {
        /icols_len 1 index dup /params known not {pop true} {
          /params get dup /icols_off known not {pop true} {
            /icols_off get dup null ne ~false {pop true} ifelse
          } ifelse
        } ifelse {mpidata /pawns get 1 add list} if def

        ~[
          exch getid 
          {~[exch /icols get length mpirank ~condense_recv] rsend} ~in_petsc
        ] sexecpawns

        1 1 icols_len last 1 sub {
          icols_len 1 index 1 sub get icols_len 2 index get add
          icols_len 3 -1 roll put
        } for

        icols_len last -1 1 {
          icols_len 1 index 1 sub get
          icols_len 3 -1 roll put
        } for
        0 icols_len 0 put
        icols_len 
      } in_petsc
    } bind def

    |--------------------- condense_recv ---------------------
    | save icols_length pawn-num | --
    |
    | Called by pawns to return the number of non-zero elements
    |   for the current matrix that are locally stored by that pawn.
    | save: save box from the send.
    | icols_length: the total number of columns stored locally on that pawn
    | pawn_num: the rank of the pawn reporting.
    |
    | Called by pawns while the node calls condense_sparse.
    |
    /condense_recv {
      {
        icols_len exch put
        restore
      } lock
    } bind def

    |------------------------- mat_creators_get -------------------
    | pawn | ...
    |
    | Returns the matrix type-specific parameters for mat_create.
    |
    | pawn: rank number of the pawn for which we want the parameters.
    | ...: type specific parameters for the current matrix.
    |
    /mat_creators_get {
      | pawn | ~sub-irows ~sub-icols n
      | ~sub-irows: executable for the pawn that returns
      |   the local offsets for each row in the column array.
      |   If it's a procedure, append with ~exec
      | ~sub-icols: executable for the pawn that returns
      |   the column number for each data element of the matrix that
      |   is non-zero. If it's a procedure, append with ~exec.
      | n: the local number of columns. Not the width, but the diagonal
      |   matrix for the pawn. Usually is the same as the number of rows
      |   for the pawn.
      /sparse {
        Aval /n get rangesize openlist
        /irows find construct_exec
        /icols find construct_exec
        counttomark 2 add -2 roll pop
      }

      | pawn | m n
      | m: the number of local rows for the pawn.
      | n: the number of local columns for the pawn. For a square matrix,
      |   the same as m. It's the diagonal matrix columns, 
      |   not the full number of columns.
      /dense {
        dup  Aval /m get rangesize
        exch Aval /n get rangesize
      }

      | pawn | m n M
      /blockdense {
        dup Aval /m get rangesize
        exch Aval /n get rangesize
        Aval /m get
      }
    } bind makestruct def
    
    |------------------- mat_creators_set -------------------------
    | .. | param-dict
    |
    | Swallow up the matrix type-specific parameters for mat_create
    |    on the node.
    | param-dict: a dictionary storing the parameters for this type
    |   matrix.
    |
    /mat_creators_set {
      | A ~irows ~icols | param-dict
      | ~irows: an executable for the pawns that returns the local offsets
      |   of the rows in icols.
      | ~icols_off: an executable for the pawns that returns the column number
      |   for each non-zero data element in the sparse matrix.
      |
      | Calls condense_sparse and requests from each pawn the size of ~icols
      |  in order to calculate the global offsets for each pawn.
      /sparse {
        /icols name /irows name
        openlist /icols_off makestruct_name
      }

      | -- | param-dict
      /dense {openlist makestruct_name}

      | -- | param-dict
      /blockdense {openlist makestruct_name}
    } bind makestruct def

    | A | --
    /mat_creators_update {
      /dense pop
      /blockdense pop
      /sparse {
        dup condense_sparse exch /params get /icols_off put
      }
    } bind makestruct def

    |-------------------------- mat_create --------------------
    | /A .... /type m n | Adict
    | 
    | Calls mat_create on pawns.
    |
    | /A: name of the matrix on the pawns.
    | ...: the type-specific paramters for a matrix of type /type
    |      (see mat_creators_set).
    | /type: type of /A: /sparse, /dense, ...
    | m: the global number of rows.
    | n: the global number of columns.
    | Adict: dictionary describing the matrix.
    |  elements:
    |    /m: global number of rows.
    |    /n: global number of columns.
    |    /mtype: matrix type.
    |    /params: dictionary of type specific parameters for matrix.
    |    /mmax: the maximum local number of rows on any pawn.
    |    /id: the name of the matrix on the pawns.
    |
    /mat_create {
      {
        null null null save /matrix openlist 
        /mtype /m /n /params /mmax /id /sv /ptype
        makestruct_stack /Aval name

        mat_creators_set Aval exectype Aval /params put 
        mpidata /pawns get 1 sub Aval /m get rangesize Aval /mmax put 
        Aval /id put

        {~[
          Aval /id get
          Aval /mmax get
          Aval /n get
          5 -1 roll mat_creators_get Aval exectype
          Aval gettype
          ~mat_create
        ]} execpawns

        Aval dup mat_creators_update 1 index exectype
        _cap
      } in_petsc
    } bind def

    |------------------------------------------------- mat_fill
    |
    |---------------------- mat_fillers ----------------------
    | -- | ...
    |
    | Return the type-specific paramters for mat_fill_data
    |  on the pawns.
    | Called from mat_fill_data.
    |
    /mat_fillers {
      | -- | ~irows ~icols
      | ~irows: executable (appended with ~exec if procedure) on the
      |   pawn that returns the local offsets for each row in icols.
      | ~icols: executable (appended with ~exec if procedure) on the pawn
      |   that returns the column number for the local non-zero data of the
      |   current matrix.
      /sparse {
        Aval /params get /irows get construct_exec
        Aval /params get /icols get construct_exec
      }

      | -- | N
      | N: the global number of columns for the current matrix.
      /dense {Aval /n get}

      | -- | N
      /blockdense {Aval /n get}
    } bind makestruct def

    |--------------------- mat_fill_data ------------------------
    | A ~data | --
    |
    | Fills a matrix on pawns with data from a d-array.
    | 
    | A: the dictionary describing a matrix from mat_create on node.
    | ~data: an executable that returns on each pawn a d-array of data
    |   (non-zero for sparse matrix) local to that pawn, in row and column
    |   sorted order.
    |
    /mat_fill_data {
      {
        ~[3 -1 roll getid 3 -1 roll construct_exec ~mat_fill_data] sexecpawns
      } in_petsc
    } bind def

    |------------------------ mat_fill ----------------------------
    | A ~row-maker | --
    | row-maker for petsc: A row | <d data> <l icols> 
    |
    | Fills a matrix on the pawns rows by row as directed by row-maker.
    | A: the dictionary from mat_create that describes the matrix.
    | ~row-maker: an executable for the pawns with the parameters:
    |    A: the matrix to be filled.
    |    row: the pawn local row number
    |    data: the (non-zero iff sparse) data for 'row'
    |    icols: the column number for each element of row.
    |
    /mat_fill {
      {
        ~[3 -1 roll getid 3 -1 roll destruct_execn ~mat_fill] sexecpawns
      } in_petsc
    } bind def

    |------------------------------------------------------ matvecmul_petsc
    | y beta A trans x alpha | y
    |
    | Call matvecmul_petsc on pawns.
    | A: dictionary describing matrix from mat_create
    | x: dictionary describing vector from vec_create
    | y: dictionary describing vector from vec_create
    | trans: A'= At iff trans, else A' = A
    | beta, alpha: scaling constants
    | y = beta*y + alpha*A'*x
    |
    /matvecmul_petsc {
      {
        5 index 7 1 roll
        exch getid exch
        4 -1 roll getid 4 1 roll
        6 -1 roll getid 6 1 roll
        ~[7 1 roll ~matvecmul_petsc] sexecpawns
      } in_petsc
    } bind def  

    |-------------------------------------------------------- get_vector
    |
    |-------------------- vector_result --------------------
    | x <d data> | --
    | 
    | Called to store info for get_vector. Internal.
    | x: dictionary from vec_create.
    | data: array into which the current elements of a vector will be 
    |   stored.
    | Called by node procedures that return vector data:
    |   get_vector. get_matvecmul, get_ksp_solve, get_ksp_resolve
    |
    /vector_result {
      {/data name /xval name} in_petsc
    } bind def

    |--------------------- recv_vector_result ---------------------
    | save <d sub-vec> interval_start | --
    |
    | Called by pawns to report their local elements of a vector to 
    |   the node.
    | save: save-box from the send.
    | sub-vec: the local elements for the pawn reporting.
    | interval-start: the global offset of the first element for the 
    |   pawn-reporting.
    | Called from: indirectly by pawn calls called from those who call
    |   vector_result above.
    |
    /recv_vector_result {
      {
        data exch 2 index length getinterval copy pop
        restore
      } lock
    } bind def    
    
    |------------------- get_vector -------------------------------
    | x <d data> | <d data>
    |
    | Get the elements from all pawns for a vector.
    | x: dictionary from vec_create for the vector.
    | data: d-array in to which the elements of vector are inserted.
    |
    /get_vector {
      {
        vector_result
        ~[xval getid ~get_vector] sexecpawns
        data
      } in_petsc
    } bind def

    |------------------------------------------------------- get_matvecmul
    |  <d data> y beta A trans x alpha |  <d data>
    |
    | Call get_matvecmul on pawns.
    | A: dictionary describing matrix from mat_create
    | x: dictionary describing vector from vec_create
    | y: dictionary describing vector from vec_create
    | trans: A'= At iff trans, else A' = A
    | beta, alpha: scaling constants
    | y = beta*y + alpha*A'*x
    | data: d-array into which the results of the multiplication will
    |  be stored on node.
    |
    /get_matvecmul {
      {
        5 index 7 index vector_result
        exch getid exch
        4 -1 roll getid 4 1 roll
        6 -1 roll getid 6 1 roll
        ~[7 1 roll ~get_matvecmul] sexecpawns
      } in_petsc
    } bind def

    |---------------------------- mat_matmul ---------------------------
    | /C A transA B transB fill/* | C
    |

    | -- | /type
    /mat_matmulsu_mtype [
      /sparse [
        /sparse /sparse
        /dense  /dense
      ] makestruct
      /dense [
        /dense /dense
        /sparse /dense
      ] makestruct
    ] makestruct def

    | -- | params
    /mat_matmulsu_create {
      /dense {openlist makestruct_name}
      /sparse {
        openlist /icols_off makestruct_name
      } 
    } bind makestruct def

    /mat_matmulsu {
      {
        /fill name /transB name /Bval name /transA name /Aval name
        mat_matmulsu_mtype Aval gettype get Bval gettype get
        Aval transA {/m} {/n} ifelse get
        Bval transB {/n} {/m} ifelse get
        mat_matmulsu_create 3 index get exec
        mpidata /pawns get 1 sub 3 index rangesize
        6 -1 roll
        save
        /matrix
        openlist /mtype /m /n /params /mmax /id /sv /ptype makestruct_name
        /Cval name

        ~[
          Cval getid mkpass
          Cval /mmax get 
          Cval /n get
          Cval gettype
          Aval getid transA
          Bval getid transB
          fill
          ~mat_matmulsu
        ] sexecpawns

        Cval 
        dup mat_creators_update 1 index exectype
        _cap
      } in_petsc
    } bind def

    |---------------------------- mat_matmul ----------------------------
    | C beta A transA B transB alpha | C
    |
    | C must have the correct non-zero pattern for At?*Bt?
    | C = C*beta + At?*Bt?*alpha
    |
    /mat_matmul {
      {
        /alpha name /transB name /Bval name /transA name /Aval name 
        /beta name dup /Cval name
        alpha 0 eq {
          beta dup 0 eq {pop mat_zero} {
            dup 1 eq ~pop ~mat_mul ifelse
          } ifelse
        } {
          beta 0 ne {
            {~kickdnode in_petsc ~stop if} sexecpawns
            /Cval_ dup Cval mat_dup def
            kickpawns
          } if

          ~[
            Cval getid 
            Aval getid transA 
            Bval getid transB 
            ~mat_matmul
          ] sexecpawns

          Cval alpha dup 1 eq ~pop ~mat_mul ifelse
          beta dup 0 eq ~pop {
            {~kickdnode in_petsc ~stop if} sexecpawns
            Cval_ exch dup 1 eq ~pop ~mat_mul ifelse
            mat_matadd
            Cval_ mat_destroy
            kickpawns
          } ifelse
        } ifelse
      } in_petsc
    } bind def

    |---------------------- mat_zero --------------------------------------
    | A | A
    |
    | A = 0
    |
    /mat_zero {
      ~[1 index getid ~mat_zero] sexecpawns
    } bind def

    |---------------------- mat_mul ------------------------------
    | A a | A
    | 
    | A *= a
    /mat_mul {
      {
        /a name
        a 0 eq ~matzero {
          a 1 ne {
            ~[1 index getid a ~mat_mul] sexecpawns
          } ifelse
        } ifelse
      } in_petsc
    } bind def

    |---------------------- mat_matadd ----------------------------------
    | A B | A
    |
    | A += B
    | A & B must have the same shape.
    /mat_matadd {
      1 index 3 1 roll
      ~[exch getid 3 -1 roll getid ~mat_matadd] sexecpawns
    } bind def

    |------------------------- getnzs ----------------------
    | A | nzs
    | nzs are the number of nonzeros in A
    |
    /getnzs {
      getnzs_nzs 1 index exectype
    } bind def

    /getnzs_nzs {
      /dense {
        dup /m get exch /n get mul
      }
      /blockdense {
        dup /m get exch /n get mul
      }
      /sparse {
        /params get /icols get length
      }
    } bind makestruct def

    |-------------------------------------------------- get_matrix
    |
    |---------------- matrix_result_splitters --------------------
    | pawn# local-offset | global-offset
    | 
    | Called by matrix_result to calculate global offset for matrix
    |   data reported by a pawn.
    | pawn#: rank of pawn reporting data.
    | local-offset: local offset of the data (from the start of the matrix)
    |   on the pawn.
    | global-offset: global-offset corresponding to local-offset.
    /matrix_result_splitters {
      /sparse {
        Aval /params get /icols_off get
        3 -1 roll get add
      }
      /dense {
        exch Aval /m get rangestart Aval /n get mul add
      }
      /blockdense {
        exch Aval /m get rangestart Aval /n get mul add
      }
    } bind makestruct def

    |---------------- densematrix_result_splitters --------------------
    | <d data> global-row ... | --
    | 
    | Called by matrix_result to calculate global offset for matrix
    |   data reported by a pawn.
    /densematrix_result_splitters {
      | <d data> global-row icols | --
      /sparse {
        /icols name
        data exch 2 index length mul 2 index length getinterval /rdata name
        0 1 icols length {/i name
          dup i get rdata icols i get put
        } for
        pop
      }
      | <d data> global-row | --
      /dense {
        data exch 2 index length mul 2 index length getinterval copy pop
      }
      | <d data> global-row | --
      /blockdense {
        data exch 2 index length mul 2 index length getinterval copy pop
      }
    } bind makestruct def
    
    |------------------------ matrix_result -----------------------
    | splitters A <d data> | --
    |
    | Store the info for recv_matrix_result. Called from get_matrix.
    | A: dictionary from mat_create for the matrix.
    | data: d-array into which the (non-zero for sparse) data for matrix
    |   will be stored.
    /matrix_result {
      {
        /data name /Aval name 
        Aval gettype get /splitter name
        ~[Aval getid ~matrix_result] sexecpawns
      } in_petsc
    } bind def

    /matrix_result_end {
      ~matrix_result_end sexecpawns
    } bind def

    |----------------------- recv_matrix_result ----------------------
    | save <d data> pawn# local_interval_start | --
    |
    | Called by pawn to report a sub-set of its local data for the matrix.
    | Called indirectly from pawn from get_matrix.
    |
    | save: save-box from send.
    | data: the data reported by the pawn
    | pawn#: rank of pawn reporting data
    | local_interval_start: the pawn local offset into the 
    |    matrix (as an array) of the data.
    |  
    /recv_matrix_result {
      {
        splitter 1 index length data 3 1 roll getinterval copy pop
        restore
      } lock
    } bind def  

    |----------------------- recv_densematrix_result ----------------------
    | save <d data> global-row ... | --
    |
    | Called by pawn to report a sub-set of its local data for the matrix.
    | Called indirectly from pawn from get_matrix.
    |
    | save: save-box from send.
    | data: the data reported by the pawn
    |  
    /recv_densematrix_result {
      {splitter restore} lock
    } bind def

    |----------------------- get_matrix ------------------------------
    | A <d data> | <d data>
    |
    | Calls get_matrix on pawns and return all the matrix's data.
    | A: dictionary for matrix from mat_create.
    | data: d-array into which the data (non-zero if sparse) for the matrix
    |   will be stored.
    |
    /get_matrix {
      {
        matrix_result_splitters 3 1 roll matrix_result
        ~[Aval getid ~get_matrix] sexecpawns
        matrix_result_end

        data
      } in_petsc
    } bind def

    |----------------------- get_densematrix ---------------------------
    | A | <d data>
    |
    /get_densematrix {
      {
        densematrix_result_splitters
        exch dup /m get 1 index /n get mul /d array 0 exch copy
        matrix_result
        ~[Aval getid ~get_densematrix] sexecpawns
        matrix_result_end

        data
      } in_petsc
    } bind def

    |---------------------------------------------------- ksp_create
    |
    |------------------- kspsettings --------------------
    | dictionary with parameters for ksp_create on pawns.
    | * signify use petsc default.
    |
    | rtol: relative convergence. Convergence achieved when
    |   ||b-Ax|| \< rtol*||b|| Default is 1e-5.
    | atol: absolute convergence. Convergence achieved when
    |   ||b-Ax|| \< atol. Default is 1e-50.
    | dtol: Divergence achieved when 
    |   ||b-Ax|| \> dtol*||b||. Default is 1e50.
    | maxits: maximum iteration until divergence.
    |   Default is 1e5.
    | pctype: one of pctypes defining preconditioner for solver.
    |   Default is left preconditioner, block Jacobi
    | ksptype: one of the ksptypes defining the Krylov solver.
    |   Default is gmres, with classical Gram-Schmidt orthogonalization.
    | pcparam, kspparam: parameter for pctype, ksptype that requires
    |   additional data for initialization.
    | monitortype: one of the monitortypes defining monitoring output
    |  during the solver.
    |
    /kspsettings {
      /rtol     1e-12
      /atol     *
      /dtol     {1d rtol div}
      /maxits   *
      /pctype   *
      /ksptype  *
      /kspparam null
      /pcparam  null
      /monitortype *
      /id null
      /sv null
      /ptype /ksp
    } bind makestruct def
    
    |------------------------ kspcreate ----------------
    | /ksp | kspsettings
    |
    | Create a solver name /ksp on pawns.
    | /ksp: name of solver on pawns.
    | kspsettings: the kspsetting currently in dictionary stack,
    |   augmented with /id=/ksp.
    |
    /ksp_create {
      kspsettings _transcribe  | /ksp ksp
      2 copy /id put
      ~[3 -1 roll 2 index ~ksp_create] sexecpawns | ksp
      _cap                   | ksp
    } bind def
    
    |---------------------------------------------- vec_destroy
    | x | --
    |
    | Call vec_destroy on pawns.
    | x: dictionary identifying vector from vec_create.
    |
    /vec_destroy {
      {
        ~[1 index getid ~vec_destroy] sexecpawns
        _destroy
      } in_petsc
    } bind def
    
    |---------------------------------------------- mat_destroy
    | A | --
    |
    | Call mat_destroy on pawns.
    | A: dictionary identifying matrix from mat_create.
    |
    /mat_destroy {
      {
        ~[1 index getid ~mat_destroy] sexecpawns
        _destroy
      } in_petsc
    } bind def

    |------------------------------------------------ mat_dup 
    |
    | /B A | B(=A)
    |
    /mat_dup {
      {
        _transcribe                           | /B B
        2 copy ~[
          3 1 roll getid ~mat_dup
        ] sexecpawns                          | /B B
        exch 1 index /id put                  | B
        _cap                                  | B
      } in_petsc
    } bind def
    
    |------------------------------------------------ mat_dup_shape
    |
    | /B A | B (uninitialized, but same shape)
    |
    /mat_dup_shape {
      _transcribe           | /B B
      2 copy ~[
        3 1 roll getid ~mat_dup_shape
      ] sexecpawns          | /B B
      exch 1 index /id put  | B
      _cap                  | B
    } bind def

    |----------------------------------------------- mat_copy
    | A B | B (=A)
    | B must already have the same shape as A
    |
    /mat_copy {
      dup 3 1 roll
      ~[3 1 roll getid exch getid exch ~mat_copy] sexecpawns
    } bind def

    |--------------------------------------------- mat_transpose
    |
    | A | At
    |
    /mat_transpose {
      {
        /Aval name
        ~[Aval getid ~mat_transpose] sexecpawns

        Aval /n get
        Aval /m get Aval /n put
        Aval /m put

        mpidata /pawns get 1 sub Aval /m get rangesize Aval /mmax put
        ~[
          Aval getid 
          Aval /mmax get 
          Aval /n get 
          ~mat_transpose_update
        ] sexecpawns
        mat_transposers_condense Aval exectype
      } in_petsc
    } bind def

    | -- | --
    /mat_transposers_condense ~[
      /dense null mkact
      /blockdense null mkact
      /sparse {
        Aval dup condense_sparse
        exch /params get /icols_off put
      }
    ] bind makestruct def
    
    |----------------------------------------------- ksp_destroy
    | ksp | --
    |
    | Call ksp_destroy on pawns.
    | ksp: dictionary identifying solver from ksp_create
    |
    /ksp_destroy {
      {
        ~[1 index getid ~ksp_destroy] sexecpawns
        _destroy
      } in_petsc
    } bind def

    |------------------------------------------------ ksp_solve
    |
    |---------------------- ksp_solve -------------------------
    | ksp A x b | --
    |
    | Solve for x: Ax=b on pawns.
    | ksp: dictionary identifying solver from ksp_create.
    | A: dictionary identifying matrix from mat_create.
    | x: dictionary identifying left-hand side vector from vec_create.
    |   Will use current value of x to seed the solver.
    | b: dictionary identify right-hand side vector from vec_create.
    |
    /ksp_solve {
      {
        ~[5 1 roll 4 {getid 4 1 roll} repeat ~ksp_solve] sexecpawns
      } in_petsc
    } bind def
    
    |------------------ ksp_resolve ----------------------------
    | ksp x b | --
    |
    | Solve for x: Ax=b on pawns, where A is the last matrix used
    |   with this solver. Rest of parameters are same as ksp_solve.
    |
    /ksp_resolve {
      {
        ~[
          4 1 roll 3 {getid 3 1 roll} repeat 
          null 
          3 1 roll 
          ~ksp_solve
        ] sexecpawns
      } in_petsc
    } bind def

    |-------------------- get_ksp_solve ---------------------------
    | ksp A x b <d data> | <d data>
    |
    | Solve for x: Ax=b on pawns, and return the elements of x.
    | Parameters are the same as ksp_solve, except for:
    | data: d-array to insert elements of solution x.
    |
    /get_ksp_solve {
      {
        2 index exch vector_result
        ~[
          5 1 roll 4 {getid 4 1 roll} repeat 
          ~get_ksp_solve
        ] sexecpawns
        data
      } in_petsc
    } bind def

    |-------------------- get_ksp_resolve -------------------------
    | ksp x b <d data> | <d data>
    |
    | Solve for x: Ax=b on pawns, where A is the last matrix used
    |  for this solver, and return the x's value.
    | Same params as ksp_resolve, except for data, which is the same
    |  as in get_ksp_solve.
    |
    /get_ksp_resolve {
      {
        2 index exch vector_result
        ~[
          4 1 roll 
          3 {getid 3 1 roll} repeat 
          null 
          3 1 roll 
          ~get_ksp_solve
        ] sexecpawns
        data
      } in_petsc
    } bind def
    
    |------------------------------------------------ report
    | bool | --
    |
    | set report on pawn rank 0. When true, solving a system will
    |  print out the iterations till convergence.
    |
    /report {
      0 ~[3 -1 roll {{/report name} in_petsc restore} ~lock] rsend
    } bind def
    
    |--------------------------------------------------- execrange
    | length ~active | --
    | active: global-offset elements | ...
    |
    | Execute ~active on all pawns. Pass to them the global range of
    |   some series.
    | length: number of elements for all pawns (as in 'range')
    | ~active: executable to execute on pawns.
    |    global-offset: as returned from range
    |    elements: as return from range.
    |
    /execrange {
      {/proc name /len name
        {
          ~[exch len range /proc construct_execn]
        } execpawns
      } in_petsc
    } bind def  
  } def

  |============================================== dm_type
  |
  | define on basis of node/pawn type
  |
  | Build this module on the basis of whether we are in a 
  |  node or pawn.
  | dm_type defined to /dnode or /dpawn in startup_common.d
  |  loaded by d-machines when initialized.
  |
  dm_type mkact exec

} moduledef
