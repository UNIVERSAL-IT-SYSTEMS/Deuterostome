/PROCESSES 100 {
  | These need to be in the same order as
  |  flags struct array in dm-proc.c.
  /FFLAGS {
    /READ_ONLY
    /WRITE_TRUNCATE
    /WRITE_APPEND
  } makeenum def

  /STDIN  0 true  makefd def
  /STDOUT 1 false makefd def
  /STDERR 2 false makefd def
  /NULLR  3 true  makefd def
  /NULLW  4 false makefd def

  /fds ~[
    STDIN STDOUT STDERR
  ] bind def
  
  /nfds ~[
    NULLR NULLW NULLW
  ] bind def

  | oldfd newfd | --
  /stddup {
    1 index exch dupfd close
  } bind def

  | (dir) (file) | fd
  /wropen {
    2 copy () 3 1 roll writefile
    FFLAGS /WRITE_APPEND get openfd
  } bind def

  | fd | --
  /close {
    (close) dout
    dup unmakefd 5 lt ~pop ~closefd ifelse
  } bind def

  /closeifopen {
    dup closedfd ~pop ~close ifelse
  } bind def

  /pidsockets [100 {[null null]} repeat] def

  /debug 1024 /b array def
  | stream (string) | stream
  /dout ~pop bind def | {
    |   /tp name
    |   dup /fd name
    |   getpid unpid  /pid name
    |   fd readonlyfd /ro  name
    |   fd used       /us  name
    |   fd closedfd   /cl  name
    |   cl {-1} {fd unmakefd} ifelse /fd name

    |   debug 0 |{
      |     * pid * number (: ) fax tp fax (: ) fax
      |     (fd=) fax * fd                * number (, ) fax
      |     (cl=) fax * cl {1} {0} ifelse * number (, ) fax
      |     (ro=) fax * ro {1} {0} ifelse * number (, ) fax
      |     (us=) fax * us                * number (\n) fax |}
    |   0 exch getinterval tostderr
    | }


  | ~active fd-in fd-out fd-err | pid
  /bg {
    openlist bg_
  } bind def

  | ~active fd-in fd-out fd-err \[fd-chained... | pid
  /bg_ {
    fork {setconsole
      {
        |       debug 0 (forked: ) fax * getpid unpid * number (\n) fax
        |       0 exch getinterval toconsole
        true PROCESSES /childproc put
        {
          /error {
            userdict begin
            /error ~error def
            console ~[
              2 rollerror getpid unpid {
                (From child ) fax * 4 -1 roll * number (: ) fax
                2 rollerror 1024 /b array errormessage fax 1 sub
              } ~warning ~restore
            ] send
            -1 die
          } bind def
        } userdict indict

        {dup class /markclass eq ~exit if closeifopen} loop pop
        {STDERR STDOUT STDIN} {exec
          1 index exch dupfd 3 1 roll
        } forall
        3 ~closeifopen repeat

        exec 0 die
      } aborted
      console {(child) /CHILD_FAILURE makeerror} send
      -1 die
    } if | pid socket

    pidsockets {
      dup 0 get null ne 1 index 1 get null ne or ~pop {| pid socket [null null]
        exch    1 index 0 put | pid [socket null]
        1 index exch    1 put | pid
        exit
      } ifelse
    } forall
    {exch dup class /markclass eq ~exit if pop} loop pop

    5 1 roll 4 ~pop repeat
  } bind def

  | pid /SIGNAME | --
  /kill {
    SIGNALS exch get killpid
  } bind def

  | n | pid 
  /job {
    pidsockets {
      dup 1 get null eq ~pop {
        1 index 0 ne {pop 1 sub} {1 get exch pop exit} ifelse
      } ifelse
    } forall
  } bind def

  /jobstr 256 /b array def
  | -- | --
  /jobs {
    0 pidsockets {
      dup 1 get null eq ~pop {
        jobstr 0 * 4 index               * number (: ) fax
        * 4 -1 roll 1 get unpid * number (\n) fax
        0 exch getinterval toconsole
        1 add
      } ifelse
    } forall pop
  } bind def

  | pid | bool
  /wait {
    dup waitpid {0 eq} {pop false} ifelse 
    exch pidsockets {
      dup 1 get 2 index ne ~pop {
        null exch 1 put
        pop exit
      } ifelse
    } forall
  } bind def

  | ... error-pending socket | -- <<error thrown>>
  /socketdead ~[
    /socketdead destruct_execn {  | ... bool socket {}
      false pidsockets {          | ... bool socket {} false pidpair
        dup 0 get 4 index eq {    | ... bool socket {} false pidpair
          null exch 0 put         | ... bool socket {} false
          3 ~pop repeat true exit | ... bool true
        } if                      | ... bool socket {} false pidpair
        pop                       | ... bool socket {} false
      } forall                    | ... bool true / ... bool socket {} false
      {~error if} ~exec ifelse    | --
    } currentdict ~indict
  ] bind userdict 3 -1 roll put

  | ~active fd-in fd-out fd-err / pid | true/false
  /fg {
    dup class /nullclass ne ~bg if
    wait
  } bind def

  | ~active fd-in fd-out fd-err \[ fd-close... | true/false
  /fg_ {
    bg_ wait
  } bind def

  | \[ (exec) .. fd-in fd-out fd-err \[ fd-close... | pid
  /sh_ {
    {countdictstack 2 sub ~end repeat closelist spawn} 
    counttomark 5 add 1 roll bg_
    counttomark 1 add 1 roll cleartomark
  } bind def

  | \[ (exec) ... fd-in fd-out fd-err | pid
  /sh {
    {countdictstack 2 sub ~end repeat closelist spawn} 4 1 roll bg
    counttomark 1 add 1 roll cleartomark
  } bind def

  | ~active fd-in fd-out fd-err | pid
  |   active: -- | \[ (exec) ... 
  /shex {
    {exec closelist spawn} fds bg
    counttomark 1 add 1 roll cleartomark
  } bind def


  | \[ (exec) ... | --
  /shfg {
    fds sh fg not {(shfg) /NOSYSTEM makeerror} if
  } bind def

  | \[ ~active ... | --
  /pipefg {
    pipe not {(pipefg) /NOSYSTEM makeerror} if
  } bind def

  | \[ ~active ... | bool
  /pipe {
    |  (master: ) toconsole getpid _ pop
    counttomark openlist exch 2 add 1 roll | \[ \[ ~active ...
    STDOUT {                   | \[pid socket... \[~active... out
      2 index class /markclass eq ~exit if

      pipefd 3 copy 7 3 roll   | ... out inr inw ~active out inr inw
      | must close inw in child to avoid file-descriptor loop
      3 1 roll exch STDERR     | ... out inr inw ~active inw inr out STDERR
      openlist 5 -1 roll bg_   | ... out inr inw pid
      counttomark 1 add 1 roll | ... out inr inw
      3 1 roll close close     | ... inw
    } loop                     | \[pid... \[ ~active fd-out

    exch STDIN 2 index STDERR bg   | \[pid ... \[fd-out pid
    3 1 roll close pop
    
    true {                         | \[pid... bool
      exch wait and                | \[pid... bool
      1 index class /markclass eq ~exit if
    } loop
    exch pop
  } bind def

  | \[ ~active ... | bool
  /andp {
    {
      counttomark dup 1 eq ~pop {-1 roll} ifelse
      fds fg not {cleartomark false exit} if
      dup class /markclass eq {pop true exit} if
    } loop
  } bind def

  | \[ ~active ... | --
  /andfg {
    andp not {(andfg) /NOSYSTEM makeerror} if
  } bind def

  | \[ ~active ... | bool
  /orp {
    {
      counttomark dup 1 eq ~pop {-1 roll} ifelse
      fds fg {cleartomark true exit} if
      dup class /markclass eq {pop false exit} if
    } loop
  } bind def

  | \[ ~active ... | --
  /orfg {
    orp not {(orfg) /NOSYSTEM makeerror} if
  } bind def

  | (buffer) offset fd char | (buffer) offset fd true / (buffer) offset false
  /readtomark {
    4 copy pop pop  | (buffer) offset fd char (buffer) offset
    1 index length exch sub getinterval 3 -1 roll
    | (buffer) offset (subbuffer) fd char
    readtomarkfd    | (buffer) offset (subbuffer) /fd true/false/
    dup {4 -2 roll} {3 -1 roll} if
    | (buffer) /fd true/false/ offset (subbuffer)
    length add 1 index {3 -1 roll} ~exch ifelse
    | (buffer) offset /fd true/false/
  } bind def

  | (buffer) offset fd | (buffer) offset fd true / (buffer) offset false
  /readline {
    (\n) readtomark
  } bind def

  | \[(exec) ... | (string)
  /readresult {
    {
      pipefd 2 copy counttomark 1 add 2 roll | pr pw \[.. pr pw 
      exch pop STDIN exch STDERR sh fg not { | \[.. STDIN pw STDERR
        close close (readresult)             |      --\> pr pw bool
        /NOSYSTEM makeerror
      } if                                   | pr pw
      close (\n) readtomarkfd_nb             | (buffer) pr true / (buffer) false
      ~close if                              | (buffer)
    } /readresult_ inlayer
    dup length /b array copy
  } bind def

  | (dir) (file) norecur-bool | --
  /_removepath {
    /norecur exch {{/DIR_NOTEMPTY makeerror}} {null mkact} ifelse def
    __removepath
  } bind def

  | (dir) (file) <</norecur defined>> | --
  /__removepath {
    2 copy fileisdir {
      2 copy finddir {
        norecur
        {1 index exch __removepath} forall pop
      } if
    } if
    rmpath
  } bind def

  | (dir) (file) | --
  /removefile {
    true ~_removepath /removepath_ ~inlayer PROCESSES indict
  } bind def

  | (dir) (file) bool | --
  /removedir {
    false ~_removepath /removepath_ ~inlayer PROCESSES indict
  } bind def

  | (dir) (subdir) | --
  /setwdirp {
    exch setwdir setwdir
  } bind def

  | linked list of error stream ouputs
  | [ readfd writefd [ readfd writefd [... null ]]]
  /estreamrd null def
  /estreamwt null def

  | -- | writefd
  /estreamopen {
    pipefd dup 3 1 roll
    /estreamwt name
    /estreamrd name
  } def

  | bool | bool
  | if true, output contents of estreams
  /estreamclose {
    estreamwt dup null eq ~pop {
      close estreamrd 1 index {suckfd toconsole} ~close ifelse
      /estreamwt null def /estreamrd null def
    } ifelse
  } bind def

  /estreamerror {
    ~error PROCESSES /childproc known ~exec {
      PROCESSES /estreamdict get /error put
      showerror
    } ifelse
    stop
  } bind def

  /estreamdict 1 dict def

  | ~active | ...
  /estreamwith {
    /estreamerror find {
      estreamopen exch
      /error ~name estreamdict indict
    } PROCESSES indict

    exch estreamdict ~swapdict stopped
    ~estreamclose PROCESSES indict 
    ~stop if
  } bind def
} moduledef
