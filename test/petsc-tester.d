| -*- mode: d; -*-

/PETSC_TESTER 200 {

  /dim 5 def
  /show true def 

  /pctype /DEFAULT def
  /sparse_pctype ~pctype def
  /dense_pctype ~pctype def

  /ksptype /DEFAULT def
  /sparse_ksptype ~ksptype def
  /dense_ksptype ~ksptype def

  /activeS true def
  /activeSD true def
  /activeD true def

  /dp {~[exch {_ pop a_ (\n) toconsole} ~exec] sexecpawns} bind def
  /dp ~pop bind def

  | (name) ~active:--|-- | --
  /timer {
    gettimeofday 3 -1 roll exec 
    gettimeofday timediff neg
    exch toconsole (: ) toconsole _ pop
  } bind def

  /timediff {
    4 1 roll exch 4 1 roll
    sub 3 1 roll sub 1e-6 exch mul exch add
  } bind def

  /loaded false def

  /loadpawns {
    0 dp
    {
      /PETSC_TESTER 200 {} moduledef
      ~kickdnode PETSC_TESTER indict ~stop if
    } sexecpawns
    1 dp
    /loadpawns {
      2 dp
      {~kickdnode PETSC_TESTER indict ~stop if} sexecpawns
      3 dp
    } def
  } bind def

  /unloadpawns ~kickpawns def

  /test {
    loadpawns
    
    ~[
      dim {PETSC {/dim name kickdnode ~stop if} exch swapdict} ~exec
    ] sexecpawns 4 dp

    /PETSC_TESTER_ ~inlayerall PETSC {
      5 dp
      (\n) toconsole
      (matD create) {/matD dup /dense dim dup mat_create def} timer
      6 dp
      (matD data) {
        {
          /matDdata 0 matD _getmatrix /MATRIX_M get dim mul /d array copy def
          0 1 matD _getmatrix /MATRIX_M get 1 sub {/row name
            matDdata row dim mul dim getinterval 
            matD _getmatrix /MATRIX_GM get row add dim 1 index sub getinterval
            1 exch copy pop
          } for
        } sexecpawns
      } timer
      7 dp
      (matD fill) {matD ~matDdata mat_fill_data} timer
      8 dp
      
      /vecxS  dup dim vec_create def
      9 dp
      /vecxD  dup dim vec_create def
      10 dp
      /vecxSD dup dim vec_create def
      11 dp
      {
        5 vecxS _getvector /VECTOR_N get /d array copy /vecxdata name
      } sexecpawns    
      12 dp
      (\n) toconsole

      (matS init) {
        dim {/nl name /n0 name
          /matSrows 0 nl 1 add /l array copy def
          1 1 matSrows last {/row name
            dim n0 row add 1 sub sub 
            matSrows row 1 sub get add
            matSrows row put
          } for
          /matScols matSrows dup last get /l array def
          matScols 0
          1 1 matSrows last {
            matSrows exch get 1 index sub
            dim 1 index sub
            1
            ramp 
          } for pop pop
        } execrange
      } timer
      13 dp
      (matS create) {
        /matS dup ~matSrows ~matScols /sparse dim dup mat_create def
      } timer
      14 dp
      (matS data) {
        {
          /matSdata 1 matScols length /d array copy def
        } sexecpawns
      } timer
      15 dp
      (matS fill) {matS ~matSdata mat_fill_data} timer
      16 dp
      (\n) toconsole

      (matSD init) {
        dim {/nl name /n0 name
          /matSDrows nl 1 add /l array 
          0 1 index length 0 dim ramp pop 
          def
          /matSDcols matSDrows dup last get /l array 
          0 nl {dim 0 1 ramp} repeat pop
          def
        } execrange
      } timer
      17 dp
      (matSD create) {
        /matSD dup ~matSDrows ~matSDcols /sparse dim dup mat_create def
      } timer
      18 dp
      (matSD data) {
        {
          /matSDdata 0 matSDcols length /d array copy def
          0 1 matSD _getmatrix /MATRIX_M get 1 sub {/row name
            matSDdata row dim mul dim getinterval
            matSD _getmatrix /MATRIX_GM get row add dim 1 index sub getinterval
            1 exch copy pop
          } for
        } sexecpawns
      } timer
      19 dp
      (matSD fill) {matSD ~matSDdata mat_fill_data} timer
      20 dp

      {
        {/kS  sparse_pctype sparse_ksptype}
        {/kSD sparse_pctype sparse_ksptype}
        {/kD  dense_pctype  dense_ksptype}
      } {exec /ksptype_name name /pctype_name name /ksp_name name
        pctypes  pctype_name  get kspsettings /pctype  put
        ksptypes ksptype_name get kspsettings /ksptype put
        ksp_name dup ksp_create def
        21 dp
      } forall
      
      /vecb dup dim vec_create def
      22 dp
      {
        /vecbdata vecb _getvector /VECTOR_N get /d array
        0 vecb _getvector /VECTOR_N get 
        dim vecb _getvector /VECTOR_GN get sub -1 ramp pop
        def
      } sexecpawns
      23 dp
      vecb ~vecbdata vec_fill
      24 dp
      
      /vecb2 dup vecb vec_dup 2 vec_mul def
      25 dp
      
      /res dim /d array def
      {
        {(sparse)       kS  matS  vecxS  activeS}
        {(sparse dense) kSD matSD vecxSD activeSD}
        {(dense)        kD  matD  vecxD  activeD}
      } {
        (\n==============================\n) toconsole
        exec not {
          3 ~pop repeat

          (Skipping: ) toconsole toconsole (\n) toconsole
        } {
          /vecx name /mat name /k name /mt name
          
          vecx ~vecxdata vec_fill
          26 dp
          (Testing: ) toconsole mt toconsole (\n\n) toconsole
          (Solution: \n) toconsole
          gettimeofday k mat vecx vecb res get_ksp_solve gettimeofday
          27 dp
          3 -1 roll show ~v_ if 
          1 sub dup mul 0d exch add sqrt (Distance: ) toconsole _ pop
          timediff neg (Time: ) toconsole _ pop
          (\n) toconsole

          (Resolve: \n) toconsole
          gettimeofday k vecx vecb res get_ksp_resolve gettimeofday
          28 dp
          3 -1 roll show ~v_ if 
          1 sub dup mul 0d exch add sqrt (Distance: ) toconsole _ pop
          timediff neg (Time: ) toconsole _ pop

          vecx ~vecxdata vec_fill
          29 dp
          (\n) toconsole

          (Solution x2: \n) toconsole
          gettimeofday k vecx vecb2 res get_ksp_resolve gettimeofday
          30 dp
          3 -1 roll show ~v_ if
          2 sub dup mul 0d exch add sqrt (Distance: ) toconsole _ pop
          timediff neg (Time: ) toconsole _ pop
        } ifelse
      } forall
      
      {
        vecxS  matS  kS
        vecxD  matD  kD
        vecxSD matSD kSD
        vecb vecb2
      } {exec destroy 31 dp} forall
      32 dp
    } 4 1 roll swapdict
    33 dp

    kickpawns
    34 dp
    unloadpawns
    35 dp
  } bind def
} moduledef
