/PETSC_TESTER module 200 dict dup begin

/dim 5 def
/show true def 

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

/petsc_test {
  /PETSC_TESTER_ layer PETSC_TESTER begin {
    ~[
      {
        /PETSC_TESTER_ layer 
        PETSC begin
        100 dict dup /PETSC_TESTER name begin
      } ~exec
      /dim dim ~def
    ] sexecpawns

    (\n) toconsole
    (matD create) {/matD dup /dense dim dup mat_create def} timer
    (matD data) {
      {
        /matDdata 0 matD /MATRIX_M get dim mul /d array copy def
        0 1 matD /MATRIX_M get 1 sub {/row name
          matDdata row dim mul dim getinterval 
          matD /MATRIX_GM get row add dim 1 index sub getinterval
          1 exch copy pop
        } for
      } sexecpawns
    } timer
    (matD fill) {matD ~matDdata mat_fill_data} timer
    
    /vecxS  dup dim vec_create def
    /vecxD  dup dim vec_create def
    /vecxSD dup dim vec_create def
    {
      5 vecxS /VECTOR_N get /d array copy /vecxdata name
    } sexecpawns
    
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
    (matS create) {
      /matS dup ~matSrows ~matScols /sparse dim dup mat_create def
    } timer
    (matS data) {
      {
        /matSdata 1 matScols length /d array copy def
      } sexecpawns
    } timer
    (matS fill) {matS ~matSdata mat_fill_data} timer
      
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
    (matSD create) {
      /matSD dup ~matSDrows ~matSDcols /sparse dim dup mat_create def
    } timer
    (matSD data) {
      {
        /matSDdata 0 matSDcols length /d array copy def
        0 1 matSD /MATRIX_M get 1 sub {/row name
          matSDdata row dim mul dim getinterval
          matSD /MATRIX_GM get row add dim 1 index sub getinterval
          1 exch copy pop
        } for
      } sexecpawns
    } timer
    (matSD fill) {matSD ~matSDdata mat_fill_data} timer
    
    /kS  dup ksp_create def
    /kD  dup ksp_create def
    /kSD dup ksp_create def
    
    /vecb dup dim vec_create def
    {
      /vecbdata vecb /VECTOR_N get /d array
      0 vecb /VECTOR_N get dim vecb /VECTOR_GN get sub -1 ramp pop
      def
    } sexecpawns
    vecb ~vecbdata vec_fill
    
    /vecb2 dup dim vec_create def
    {
      /vecb2data vecbdata dup length /d array copy 2 mul def
    } sexecpawns
    vecb2 ~vecb2data vec_fill
      
    /res dim /d array def
    {
      {(sparse)       kS  matS  vecxS}
      {(sparse dense) kSD matSD vecxSD}
      {(dense)        kD  matD  vecxD}
    } {exec /vecx name /mat name /k name /mt name
      vecx ~vecxdata vec_fill
      (\n) toconsole
      (Testing: ) toconsole mt toconsole (\n) toconsole
      (Solution: \n) toconsole
      gettimeofday k mat vecx vecb res get_ksp_solve gettimeofday
      3 -1 roll show {v_} if 
      1 sub dup mul 0d exch add sqrt (Distance: ) toconsole _ pop
      timediff neg (Time: ) toconsole _ pop
      
      (\n) toconsole
      (Resolve: \n) toconsole
      gettimeofday k vecx vecb res get_ksp_resolve gettimeofday
      3 -1 roll show {v_} if 
      1 sub dup mul 0d exch add sqrt (Distance: ) toconsole _ pop
      timediff neg (Time: ) toconsole _ pop

      vecx ~vecxdata vec_fill
      (Solution x2: \n) toconsole
      gettimeofday k vecx vecb2 res get_ksp_resolve gettimeofday
      3 -1 roll show {v_} if
      2 sub dup mul 0d exch add sqrt (Distance: ) toconsole _ pop
      timediff neg (Time: ) toconsole _ pop
    } forall
    
    {
      {vecxS  matS  kS}
      {vecxD  matD  kD}
      {vecxSD matSD kSD}
    } {exec ksp_destroy mat_destroy vec_destroy} forall
      
    {vecb vecb2} {exec vec_destroy} forall
      
    {
      end
      end
      false /PETSC_TESTER_ _layer pop
    } sexecpawns
  } stopped end /PETSC_TESTER_ _layer {stop} if
} bind def

end _module
