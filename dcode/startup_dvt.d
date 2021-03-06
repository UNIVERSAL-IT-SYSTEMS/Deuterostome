| -*- mode: d; -*-
| Copyright 2011 Alexander Peyser & Wolfgang Nonner
|
| This file is part of Deuterostome.
|
| This program is free software: you can redistribute it and/or modify
| it under the terms of the GNU General Public License as published by
| the Free Software Foundation, either version 2 of the License, or
| (at your option) any later version.
|
| This program is distributed in the hope that it will be useful,
| but WITHOUT ANY WARRANTY; without even the implied warranty of
| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
| GNU General Public License for more details.
|
| You should have received a copy of the GNU General Public License
| along with this program.  If not, see <http://www.gnu.org/licenses/>.

|============================ D Startup =================================

| Contains procedures for:
|  - inspection of objects
|  - object/text interconversion
|  - transcription of objects
|  - file <=> VM interchange
|  - module support

/dm_type /dvt def

save /startup_common_save name 
/startup_common_buf vmstatus sub 10 div /b array def
startup_common_save capsave {
  getstartupdir (startup_common.d) startup_common_buf readfile mkact exec
} stopped startup_common_save restore {
  (Unable to load: ) toconsole 
  getstartupdir toconsole (startup_common.d\n) toconsole
  stop
} if

| pid (source) code
/error_ops_length 3 def

| -- | pid true
/_makeerror {
  getpid unpid
  true
} bind def

100 /b array debug_dict /line1 put

|============================= userdict =================================

/lock   ~exec bind def    | just to make dnodes & dvts symmetric
/unlock ~exec bind def
/locked false def

|--------------------------- Supervisor of the dvt ---------------------------

/dvtsup 100 dict dup begin | {

  /linebuf 8192 /b array def
  /linebuf2 8192 /b array def
  /combuf 1024 /b array def

|------------------------ supervisor  loop of the dvt ----------------------
|
| In the dvt, the supervisor of the D mill is implemented in the D code
| defined in this section. A supervisor loop polls for a string received
| from the dvt console (typically a shell running in emacs) or a message
| received from a connected dnode (such a message may include a D object in
| addition to the received string). The received string (an extra object)
| are dealt with by executing the active name 'consoleline' or 'nodemessage',
| dependent on the source. The D procedures associated with these names 
| may pre-process the string and submit it to the current target, who 'owns'
| the console keyboeard. This target can be the dvt, a single dnode, or a
| group of dnodes, either one of which can spawn D activities, or linux
| commands in the local host.
|
| Once an activity is underway in the dvt, it will not be interrupted by
| more recent messages. Hence only one dvt service is being attended to at a
| given time, and competing demands for services made to the dvt are dealt
| with sequentially. The only means to terminate a dvt service before it
| comes to its natural end is to press 'control-c' on the keyboard. This is
| equivalent to executing the 'abort' operator of the dvt. Errors detected
| by the D mill of the dvt are reported to the console and force execution
| of 'abort'. The outermost 'aborted' capsule is in the supervisor loop in
| the dvt; if control drops to this level, the operand stack is cleared,
| the dictionary stack is dropped to the two permanent dictionaries, and
| execution of the dvt supervisor loop resumes.
|
| We first define 'consoleline' and 'nodemessage' for the dvt. Connections
| with dnodes and their use is the subject of a set of front-end procedures
| and of an X window interface described subsequently.

  /supervisor
  {
    {
      {linebuf nextevent} aborted { 
        countdictstack 2 sub ~end repeat
        clear dvtsup begin
        /kbdowner 0 def 
        {c_} aborted {(!! c_ error\n)} if
      } if
    } loop
  } bind def

|---------------------------------------------- consoleline
|
| A phrase typed on the console keyboard will first be stripped of a
| possible leading tag character (presently one of '!$#@'). The tag
| directs the use of the rest of the phrase by the dvt:
|
|  untagged         - the phrase contains D code to be submitted to the
|                     target
|  %                - the phrase contains D code to be submited to the
|                     dvt
|  !                - the phrase contains D code to be submitted to the
|                     target regardless of the ready/busy status of the
|                     target
|  $                - the phrase is a linux command to be executed by
|                     the linux system of the local host of the target
|  #                - the phrase contains D code to be executed in the
|                     dvt to produce a secondary phrase to be executed
|                     by the linux system of the local host of the target
|  @                - the phrase contains D code to be executed in the
|                     D mill of the target to produce a secondary phrase
|                     that is to be executed by the linux system of the
|                     local host of the target
|
|  Phrases tagged by # or @ are D code that describes how to compose a linux
|  command from smaller elements; one purpose of this construct is to extract
|  file or directory names selected in theeye. Operators useful in such
|  phrases are:
|
|   (string) fax    - include literal string (like a shell command name)
|   faxLpage        - include object selected in the left page of theeye
|                     in the form of a string
|   faxRpage        - do like LS_, but use all selected objects from the right
|                     page of theeye
|
|  In normal D phrases, the following operators are useful to extract objects
|  selected in theeye:
|
|   getLpage        - return the object selected in the left page
|   getRpage        - return a list of the objects selected in the right page
|
| When a phrase is sent to a dnode, this dnode becomes 'busy'. The phrase is
| transparently complemented by code that is sent back from the dnode to the
| dvt when the phrase has been executed by the dnode. This code resets the
| dnode's 'busy' status to 'ready'. The dnode status is a bookkeeping
| feature of the dvt (to prevent it from sending ordinary phrases to a dnode).
| You can reset a hung 'busy' status from the keyboard and by mouse action
| on the 'nodes' window.

  /consoleline {
    /ENABLE_REGEX {
      (^[ \n]+) regexsi {pop pop} if
    } if_compile
    dup /line name length 0 gt {
      (%!$#@^) line 0 1 getinterval search { 
        length 1 add /linetag name pop pop
        /line line 1 line length 1 sub getinterval def
      } { 
        pop 0 /linetag name 
      } ifelse

      tags linetag get exec
    } if
  } bind def

  /dvt_exec {
    line mkact [ currentdict end ~stopped push begin ~stop if |]
  } bind def

  /tags [

  |-- no tag
  | dvt   - execute phrase
  | dnode - ready: encapsulate phrase and send it to dnode
  |         busy: discard phrase and print 'Wait!'

    { 
      kbdowner 0 eq ~dvt_exec { {
        node 3 get {(Wait!\n) toconsole} { 
          knode setbusy 
          {
            node 2 get ~[~[line knode ~dvtreceive] ~lock] send
          } insave
        } ifelse
      } fornodes} ifelse
    } bind
  
    |-- %
    | dvt - execute phrase
    | dnode - execute phrase on dvt
    ~dvt_exec

    |-- !
    | dvt   - ignore tag and execute rest of phrase
    | dnode - send phrase regardless of dnode state
    
    { 
      kbdowner 0 eq ~dvt_exec {
        { node 2 get line send } fornodes
      } ifelse
    } bind
    
    |-- $
    | dvt   - submit line to linux of dvt
    | dnode - ready: encapsulate and submit as linux command to dnode
    |         busy: discard phrase and print 'Wait!'
  
    { 
      kbdowner 0 eq { 
        combuf 0 line fax ( &) fax 0 exch getinterval tosystem
      } { 
        { 
          node 3 get  {(Wait!\n) toconsole}  { 
            knode setbusy
            save
            node 2 get ~[~[line knode ~dvtsystem] ~lock] send
            restore
          } ifelse
        } fornodes
      } ifelse
    } bind
  
    |-- #
    | dvt   - treat like '@'
    | dnode - ready: evaluate, encapsulate, and submit as shell command to dnode
    |       - busy: discard phrase and print 'Wait!'
    
    { 
      kbdowner 0 eq { 
        combuf 0 dvt_exec
        ( &) fax 0 exch getinterval tosystem
      } { 
        { 
          node 3 get {(Wait!\n) toconsole} { 
            knode setbusy
            save
            node 2 get ~[~[dvt_exec knode ~dvtsystem] ~lock] send
            restore
          } ifelse
        } fornodes
      } ifelse
    } bind
  

    |-- @
    | dvt   - evaluate phrase and submit to shell
    | dnode - ready: encapsulate, submit to dnode where the phrase is evaluated
    |                and the result is submitted as shell command
    |       - busy: discard phrase and print 'Wait!'
    
    { 
      kbdowner 0 eq { 
        combuf 0 dvt_exec
        ( &) fax 0 exch getinterval tosystem
      } { 
        { 
          node 3 get {(Wait!\n) toconsole}  { 
            knode setbusy
            save 
            node 2 get ~[~[line knode ~dvtexecsystem] ~lock] send
            restore
          }  ifelse
        } fornodes
      } ifelse
    } bind

    |-- ^
    | dvt   - execute phrase
    | dnode - execute on dnode, not pawns

    { 
      kbdowner 0 eq ~dvt_exec { { 
        node 3 get {node 2 get line send} { 
          knode setbusy 
          save
          node 2 get ~[~[line knode ~dvtreceive_np] ~lock] send
          restore
        } ifelse
      } fornodes} ifelse
    } bind
  ] def

  |-- loop operator to invoke an individual dnode or group of dnodes
  
  /fornodes { /procfornodes name
    kbdowner 0 gt { 
      /knode kbdowner def /node nodelist knode get def
      procfornodes
    } { 
      1 1 nodelist last { /knode name
        nodelist knode get /node name
        node 4 get kbdowner eq ~procfornodes if
      } for
    } ifelse
  } bind def

|------------------------------------------------ nodemessage
| execute the message string

  /nodemessage {
    mkact exec
  } bind def

|-------------------- administration of the nodes -----------------------
|
| The nodes in a cluster are the dvt and the currently connected dnodes.
| The node list stores information on the whereabouts, state, and grouping
| of the nodes. Node list entries are lists themselves:
| 
| [(hostname) port# socket status group color_list color_name [ssh-pid ssh-fd]]
|
| The status is busy (true) or ready (false). Busy nodes are not given
| dvt phrases unless this is forced by the '!' tag. The group is a negative
| integer shared by all members of a group.
|
| Nodes are administrated by a set of front-end procedures that must be
| invoked by keyboard commands to the dvt. Nodes are also administrated
| by a window maintained in startup_dvt; this window shows node information
| and maps some administration commands to mouse clicks. The keyboard
| interface of node administration is defined first, followed by the
| machinery of the nodes window.

  /max_nodes 10 ~def userdict indict
  /makeNodes {
    /nodelist [
        [(dvt) null null false 0 {} null [null null]]
      max_nodes 1 sub {
        [null  null null false 0 {} null [null null]]
      } repeat
    ] def
  } bind def

|------------------------------- front-end ------------------------------
| Note that thes procedures are defined in userdict!

|---------------------------------------------------- print help message

  /h_ {
(The dvt provides the following services:
_          show top object of operand stack in brief form
v_         show value of composite top object of operand stack
s_         show value of string top object of operand stack 
a_         show all objects on operand stack in brief form, top first

d_         show top object of dictionary stack in brief form
da_        show all objects on dictionary stack in brief form
dg_        get k-th element from top of dictionary stack \(0 = top\)

xa_        show all objects on execution stack in brief form
xg_        get k_th element from top of execution stack \(0 = top\)

m_         show current stack, VM, and AM use

tofiles    dirname filename { object_generator } | --
fromfiles  dirname filename | objects..  \(and/or side effects\)

forgetmodule   /module_name | --
savemodule     /project_name /snapshot_name | --
restoremodule  /snapshot_name | --

_c         hostname port# group | --  \(connect to a dnode\)
_cx        hostname port# group | -- \(connect & gets eye a dnode\)
_cc        [/color..] hostname port# group | -- \(connect & color text\)
_ccx       [/color..] hostname port# group | -- \(connect w/ eye & color text\)
_csu       hostname port# group <l opds dicts execs vm/M userdict > | --
   \(connect to a dnode and set up new resources\)
_ccsu      [/color..] hostname port# group <l opds dicts execs vm/M userdict>
           | --
   \(connect, setup resource, and color text\)
_dc        node# | --  \(disconnect from a dnode\)
_dx        node# | -- \(disconnect from a dnode & remove Eye\)
_t         target | --  \(choose new owner\(s\) of the keyboard\)
_r         node# | --  \(reset 'busy status of a node\)
c_         list all connections
) toconsole 
  } bind userdict 3 -1 roll put

  /hk_ {
(
  Emacs dvt keys:
    f1: d-comint-mode-invert, execute the previous command line
    f2: d-comint-mode-continue, send continue to the dvt/dnode
    f3: d-comint-mode-stop, send stop to the dvt/dnode
    f4: d-comint-mode-abort, send abort to the dvt/dnode
    f5: d-comint-mode-raise-the-horses, pop up TheHorses window
    f6: d-comint-mode-raise-all, pop up all dvt/dnode windows
    shift-f6: d-comint-mode-hide-all, iconify all dvt/dnode windows
    f7: d-comint-mode-focus-raise, raise the dvt emacs frame
    f8: start a local dnode
    control-h d: get this help
    control-!: d-comint-mode-scream, ignore busy state when sending to dnodes
    control-1: same as control-!
    control-c c: d-comint-mode-clear, clear preceding text from emacs window
    control-c control-a: d-comint-mode-dabort, send command wrapped 
                         in debug abort
    control >: d-comint-mode-redirect-mode, send output to log file
    control-c control-n: d-comint-mode-narrow, narrow dvt buffer
    control-c control-w: d-comint-mode-widen, widen dvt buffer
) toconsole
  } bind userdict 3 -1 roll put

|---------------------------------------------------- list active connections

  /c_ {
    dvtsup begin
    0 1 nodelist last { /knode name
      nodelist knode get /node name
      printnode
    } for
    end
  } bind userdict 3 -1 roll put

|---------------------------------------------------- connect to node
| hostname port# group# | -- 
|
| connects to the node and makes itself the current dvt of the node;
| the node is assigned a group number (enter as NEGATIVE integer)

  /_c {
    dvtsup begin {
      false 0 1 nodelist last { /knode name
        nodelist knode get /node name
        node 0 get class /nullclass eq { pop true exit } if
      } for not { (Too many nodes!\n) toconsole stop } if
      node 4 put
      2 copy connect node 2 put node 1 put node 0 put
      false node 3 put
      node 2 get (getsocket setconsole) send
      printnode  
    } stopped pop end
  } bind userdict 3 -1 roll put

|---------------------------------------------------- connect to node
| [/color...] hostname port# group# | -- 
|
| connects to the node and makes itself the current dvt of the node;
| the node is assigned a group number (enter as NEGATIVE integer)

  /_cc {
    dvtsup begin {
      false 0 1 nodelist last { /knode name
        nodelist knode get /node name
        node 0 get class /nullclass eq { pop true exit } if
      } for not { (Too many nodes!\n) toconsole stop } if
      node 4 put
      2 copy connect node 2 put node 1 put node 0 put
      false node 3 put
      node 6 put
      
      save
      node 2 get ~[node 0 get knode {
        getsocket setconsole /dvtnodeid name
        console ~[3 -1 roll ~dvtsup ~begin ~_cc1] send
      } ~exec ~restore] send
      restore
    } stopped pop end
  } bind userdict 3 -1 roll put

  /_cc1 {
    exch restore {color_node_def} stopped pop end
  } bind userdict 3 -1 roll put

  | ------ handle ssh connections for display -----------
  Xwindows {
    /ssh_display [
      /result 1024 /b array
      /flags []
      /dnodeexec null
      /ssh (ssh)
      /localhostdisplay (^\(localhost|127.0.0.1\)?:)
      /localhost (^\(localhost|127.0.0.1\)$)
      /in_w null
      /in_r null
      /out_r null
      /out_w null

      | -- | [ (ssh) flags node | ]
      /command {
        openlist ssh flags {} forall node 0 get
        dnodeexec length (getdisplay) length add /b array {
          dnodeexec fax (getdisplay) fax
        } tostring
      } bind
      
      | -- | (display) fd pid
      /ssh_proc {
        pipefd /in_w  name /in_r  name
        pipefd /out_w name /out_r name
        command {
          in_r out_w STDERR sh_bg
          in_r close out_w close
        } PROCESSES indict | pid

        result {
          out_r {readline ~close if} PROCESSES indict
        } tostring | pid (display)

        in_w 3 -1 roll | (display) fd pid
      } bind

      /nodeclear {
        | clear out old ssh display connection
        node 7 get dup 0 get dup null eq {pop pop} { | [pid fd] pid
          1 index dup 1 get dup null eq {pop pop} {  | [pid fd] pid [pid fd] fd
            ~close PROCESSES indict
            null exch 1 put
          } ifelse | [pid fd] pid
          {
            dup isdead {pop pop} { | [pid fd] pid
              dup /QUIT kill       | [pid fd] pid
              wait pop             | [pid fd]
            } ifelse               | [pid fd]
          } PROCESSES indict       | [pid fd]
          null exch 0 put          | --
        } ifelse                   | --
      } bind

      | (startupdir) (default-display) | (dnode-display)
      /display {exch /dnodeexec name
        nodeclear
        | and setup the new if necessary
        node 0 get localhost regexs {3 ~pop repeat} {pop 
          localhostdisplay regexs {
            3 ~pop repeat
            ssh_proc dup ~isdead PROCESSES indict not {
              node 7 get 0 put
              node 7 get 1 put
            } {
              pop pop pop
              (display) /NOSYSTEM makeerror
            } ifelse
          } if
        } ifelse
        dup userdict /lastdvtdisplay put
      } bind
    ] makestruct def

    | ~next | --
    /getdnodedisplay {
      {
        node 2 get ~[
          3 -1 roll destruct_exec knode getdisplayhost {
            /displayhost name /knode name /dvtnext name
            getsocket ~[
              ~dup ~capsave
              /dvtnext find getexecdir displayhost knode {
                {
                  /knode name
                  /node nodelist knode get def
                  ~display ssh_display indict
                  exch exec
                } dvtsup indict
                restore
              } ~exec
            ] send
            restore
          } ~lock
        ] send
      } insave
    } bind def
  } {
    /getdnodedisplay {null exch exec} def
  } ifelse

|---------------------------------------------------- connect to node
| hostname port# group# | -- 
|
| connects to the node and makes itself the current dvt of the node;
| the node is assigned a group number (enter as NEGATIVE integer)
| Also connects the eye.

  Xwindows {
    | hostname port# group | --
    /_cx {
      {
        false 0 1 nodelist last {/knode name
          nodelist knode get /node name
          node 0 get class /nullclass eq {pop true exit} if
        } for not {(Too many nodes!\n) toconsole stop} if
        node 4 put
        2 copy connect node 2 put node 1 put node 0 put
        true node 3 put printnode
        
        ~_cx1 getdnodedisplay
      } dvtsup indict
    } bind userdict 3 -1 roll put

    | (display) | --
    /_cx1 {
      {
        node 2 get ~[3 -1 roll knode fontdict commonmousedict node 0 get {
          getsocket setconsole /dvtnodeid name
          /commonmousedict name /fontdict name /knode name /getdnodedisplay name
          capsave
          
          Xwindows_ not {(No Xwindows on node!\n) toconsole stop} if
          Xdisconnect
          getdnodedisplay Xconnect

          /filesave save def
          /fbuf vmstatus sub 10 div /b array def
          filesave capsave {
            getstartupdir (theeye.d) fbuf readfile mkact exec
          } stopped pop filesave restore
          
          console ~[knode ~dvtsup ~begin ~_cx2] send
        } ~exec] send
      } insave
    } bind def

    | knode | --
    /_cx_ready {
      nodelist 1 index get 7 get dup 1 get dup null eq {pop pop} {
        (X) writefd ~close PROCESSES indict
        null exch 1 put
      } ifelse
      setready
    } bind def
  
    | save knode | -- <<end dvtsup>>
    /_cx2 {
      exch restore ~_cx_ready stopped pop end
    } bind def
  } if

|---------------------------------------------------- connect to node
| [/color...] hostname port# group# | -- 
|
| connects to the node and makes itself the current dvt of the node;
| the node is assigned a group number (enter as NEGATIVE integer)
| this version also sets the eye on the current console

  Xwindows {
    /_ccx {
      {
        false 0 1 nodelist last { /knode name
          nodelist knode get /node name
          node 0 get class /nullclass eq { pop true exit } if
        } for not { (Too many nodes!\n) toconsole stop } if
        node 4 put
        2 copy connect node 2 put node 1 put node 0 put
        node 6 put
        true node 3 put printnode
   
        ~_ccx1 getdnodedisplay
      } dvtsup indict
    } bind userdict 3 -1 roll put

    /_ccx1 {
      {
        node 2 get ~[3 -1 roll knode fontdict commonmousedict node 0 get {
          getsocket setconsole /dvtnodeid name
          /commonmousedict name /fontdict name /knode name /getdnodedisplay name
          capsave

          Xwindows_ not {(No Xwindows on node!\n) toconsole stop} if
          Xdisconnect
          getdnodedisplay Xconnect

          /filesave save def
          /fbuf vmstatus sub 10 div /b array def
          filesave capsave {
            getstartupdir (theeye.d) fbuf readfile mkact exec
          } stopped pop filesave restore

          console ~[knode ~dvtsup ~begin ~_ccx2] send
        } ~exec]  send
      } insave
    } bind def
    
    | save knode | -- <<end dvtsup>>
    /_ccx2 {
      exch restore {dup color_node_def _cx_ready} stopped pop end
    } bind def
  } if
  
|---------------------------------------------------- set up node
| hostname port# group# <l opds dicts execs vm/M userdict > | -- 
|
| connects to the node like '-c', primes its memory setup, reads
| startup_dnode.d, and makes itself the dvt of the node;
|
| uses getdvtdisplay as the Xserver for the dnode
| by default, dvtdisplay (in c)
| but can be redefined in userdict

  /_csu {
    { 
      false 0 1 nodelist last {/knode name
        nodelist knode get /node name
        node 0 get class /nullclass eq { pop true exit } if
      } for not { (Too many nodes!\n) toconsole stop } if
      4 1 roll node 4 put
      2 copy connect node 2 put node 1 put node 0 put
      true node 3 put printnode
      {
        node 2 get ~[
          3 -1 roll {exch pop getsocket setconsole vmresize} ~lock
        ] send
      } insave
      null node 6 put

      ~_csu1 getdnodedisplay
    } dvtsup indict
  } bind userdict 3 -1 roll put

  | (display) | --
  /_csu1 {
    {
      node 2 get ~[3 -1 roll Xwindows knode node 0 get {
        getsocket setconsole
        6 -1 roll not {killsockets abort} if | bool from vmresize
        /dvtnodeid name /knode name 
        Xwindows_ and /otherXwindows name 
        /getdnodedisplay name
        capsave

        /filesave save def
        /fbuf vmstatus sub 10 div /b array def
        filesave capsave { 
          getstartupdir (startup_dnode.d) fbuf readfile mkact exec
        } stopped pop filesave restore

        console ~[knode 
          otherXwindows {
            ~dvtsup ~begin ~_csu1x
          } {~dvtsup ~begin ~csu1nox} ifelse
        ] send
      } ~exec] send
    } insave
  } bind def

  /_csu1x {
    /knode name {
      nodelist knode get /node name
      node 2 get ~[
        debug_dict /line1 get 0 node 0 get fax (:) fax * node 1 get * number
        0 exch getinterval 
        knode {/knode name
          1 index capsave
          getdnodedisplay Xconnect
          dup length /b array copy userdict /myid put
          save console ~[knode ~dvtsup ~begin ~_csu2x] send restore
        } ~exec ~restore
      ] send
      restore
    } stopped pop end
  } bind userdict 3 -1 roll put

  /_csu1nox {
    /knode name {
      nodelist knode get /node name
      node 2 get ~[
        debug_dict /line1 get 0 node 0 get fax (:) fax * node 1 get * number
        0 exch getinterval 
        knode {/knode name
          1 index capsave
          dup length /b array copy userdict /myid put
          save console ~[knode ~dvtsup ~begin ~_csu2nox] send restore
        } ~exec ~restore
      ] send
      restore
    } stopped pop end
  } bind userdict 3 -1 roll put

  /_csu2x {
    /knode name {
      nodelist knode get /node name
      node 2 get ~[knode fontdict commonmousedict node 0 get {
        /dvtnodeid name
        /commonmousedict name /fontdict name /knode name capsave

        /filesave save def
        /fbuf vmstatus sub 10 div /b array def
        filesave capsave { 
          getstartupdir (theeye.d) fbuf readfile mkact exec
        } stopped pop filesave restore

        save console ~[knode ~dvtsup ~begin ~_csu3] send restore
      } ~exec] send
      restore
    } stopped pop end
  } bind userdict 3 -1 roll put

  /_csu2nox {
    /knode name {
      nodelist knode get /node name 
      node 2 get ~[
        knode {/knode name
          console [knode ~dvtsup ~begin ~_csu3] send
        } ~exec ~restore
      ] send
      restore
    } stopped pop end
  } bind userdict 3 -1 roll put

  /_csu3 {
    exch restore {dup color_node_def _cx_ready} stopped pop end
  } bind userdict 3 -1 roll put

|---------------------------------------------------- set up node
| [/color...] hostname port# group# <l opds dicts execs vm/M userdict > | -- 
|
| In addition to normal _csu behavior, colors the node on setup
|
  /_ccsu {
    _csu dvtsup begin {node 6 put} stopped pop end
  } bind userdict 3 -1 roll put

  /_ccsum {
    _csum dvtsup begin {node 6 put} stopped pop end
  } bind userdict 3 -1 roll put
|---------------------------------------------------- disconnect
|  node# | --

  /_dc {
    dvtsup begin /knode name
    nodelist knode get /node name
    node 0 get class /nullclass ne {
      node 2 get disconnect
      nodeclear
    } if
    end
  } bind userdict 3 -1 roll put

| ... error-pending socket | --
  /socketdead {
    {
      /deadsocket name
      true 
      1 1 nodelist last {/knode name
        nodelist knode get /node name
        node 2 get deadsocket eq {
          node 2 get disconnect
          {
            (** [) fax * knode * number (] Dead connection on ) fax
            node 0 get fax (:) fax * node 1 get * number
          } warning
          nodeclear
          pop false exit
        } if
      } for 
      {_makeerror pop (socketdead) ERRORS /DEAD_SOCKET get showerror} if 
      ~error if
    } dvtsup indict
  } bind userdict 3 -1 roll put

  Xwindows {
    /_dx {
      dvtsup begin /knode name
      nodelist knode get /node name
      node 0 get class /nullclass ne {
        save
        node 2 get ~[
          knode {/knode name
            Xwindows {Xdisconnect} if
            console ~[knode ~dvtsup ~begin ~_dx1] send
          } ~exec ~restore
        ] send
        restore
      } if
    } bind userdict 3 -1 roll put

    /_dx1 {/knode name restore
      nodelist knode get /node name
      node 2 get disconnect
      nodeclear
      end | dvtsup dict
    } bind def
  } if

  /_kill {
    dvtsup begin /knode name
    nodelist knode get /node name
    node 0 get class /nullclass ne {
      node 2 get dup (getsocket setconsole null vmresize) send disconnect
      nodeclear
    } if
    end    
  } bind userdict 3 -1 roll put

  /_sendabort {
    dvtsup begin /knode name
    knode 0 ne {
      nodelist knode get /node name
      node 0 get class /nullclass ne {
        node 2 get /INT signal
        knode setready
      } if
    } if
    end
  } bind userdict 3 -1 roll put

|---------------------------------------------------- connection convenience
|
  Xwindows {
    /getdvtdisplay Xdisplayname def
    /getdisplayhost ~getdvtdisplay def

    /dnode_memory_ <x 0 0 0 0 0> def    
    /dnode_setup 11 dict dup begin
    /display ~getdvtdisplay def
    /host (localhost) def
    /port 0 def
    /group -1 def
    /color null def
    /memory (=== Memory names ==) def
    /opds  100000 def
    /dicts 5000    def
    /execs 5000    def
    /mb    500    def
    /user  400    def
    end userdict 3 -1 roll put

    /dnode_resize {
      /_getdisplayhost getdisplayhost def
      /getdisplayhost dnode_setup /display get def
      {
        color dup null eq {pop ~_csu} {
          dup class /listclass ne {[exch]} if
          ~_ccsu
        } ifelse
        host port group dnode_memory_
        opds  1 index 0 put
        dicts 1 index 1 put
        execs 1 index 2 put
        mb    1 index 3 put
        user  1 index 4 put
      } dnode_setup indict 
      5 -1 roll exec
      /getdisplayhost _getdisplayhost def
    } bind def

    | ~_c ~_cc | --
    /dnode_up {
      /_getdisplayhost getdisplayhost def
      /getdisplayhost dnode_setup /display get def
      {
        color dup null eq {pop pop} {
          3 -1 roll pop
          dup class /listclass ne {[exch]} if
          exch
        } ifelse
        host port group
      } dnode_setup indict
      4 -1 roll exec
      /getdisplayhost getdisplayhost def
    } bind def

    /dnode_display {dnode_setup /display put} bind userdict 3 -1 roll put
    /dnode_host    {dnode_setup /host    put} bind userdict 3 -1 roll put
    /dnode_port    {dnode_setup /port    put} bind userdict 3 -1 roll put
    /dnode_group   {dnode_setup /group   put} bind userdict 3 -1 roll put
    /dnode_color   {dnode_setup /color   put} bind userdict 3 -1 roll put
    /dnode_opds    {dnode_setup /opds    put} bind userdict 3 -1 roll put
    /dnode_dicts   {dnode_setup /dicts   put} bind userdict 3 -1 roll put
    /dnode_execs   {dnode_setup /execs   put} bind userdict 3 -1 roll put
    /dnode_mb      {dnode_setup /mb      put} bind userdict 3 -1 roll put
    /dnode_user    {dnode_setup /user    put} bind userdict 3 -1 roll put
  } if

|---------------------------------------------------- talk to node
|  target | --
|
|  0  - dvt
| >0  - node#
| <0  - group#

  /_t {
    dvtsup begin {/target name
      target 0 ge { 
        target nodelist length ge ~stop if
        nodelist target get /node name 
        node 0 get class /nullclass ne { 
          target /kbdowner name /knode target def
        } ~stop ifelse
      } { 
        false 1 1 nodelist last { /knode name
          nodelist knode get /node name
          node 0 get class /nullclass ne { 
            node 4 get target eq { /kbdowner target def pop true } if
          } if
        } for
        not ~stop if
      } ifelse

      0 1 nodelist last {/knode name
        nodelist knode get /node name
        printnode
      } for

    } stopped {(Think!\n) toconsole} if
    end
  } bind userdict 3 -1 roll put

  /_r {
    dvtsup begin {
      dup * eq {{pop knode setready} fornodes} {
        dup nodelist length ge {pop stop} if
        setready
      } ifelse
    } stopped {(Think!\n) toconsole} if
    end
  } bind userdict 3 -1 roll put

  /emacs_next_talk {
    kbdowner 0 lt {0 {pop knode} fornodes _t} if

    kbdowner {
      1 add nodelist length mod
      dup kbdowner eq {false exit} if
      nodelist 1 index get 2 get null ne 1 index 0 eq or {
        true exit
      } if
    } loop

    ~_t ~pop ifelse
    end
  } bind def

  /emacs_last_talk {
    kbdowner 0 lt {0 {pop knode exit} fornodes _t} if

    kbdowner {
      1 sub dup 0 lt {pop nodelist length 1 sub} if
      dup kbdowner eq {false exit} if
      nodelist 1 index get 2 get null ne 1 index 0 eq or {
        true exit 
      } if
    } loop

    ~_t ~pop ifelse
    end
  } bind def

  /emacs_next_group_talk {
    kbdowner 0 gt {nodelist kbdowner get 4 get _t} if

    -1000
    0 1 nodelist last {/knode name
      nodelist knode get /node name
      node 2 get null ne {
        node 4 get kbdowner lt {
          node 4 get 2 copy lt ~exch if pop
        } if
      } if
    } for
    dup kbdowner eq {pop 0} if
    dup -1000 eq {pop 0} if

    _t
    end
  } bind def

  /emacs_last_group_talk {
    kbdowner 0 gt {nodelist kbdowner get 4 get _t} if

    0
    0 1 nodelist last {/knode name
      nodelist knode get /node name
      node 2 get null ne {
        node 4 get kbdowner gt {
          node 4 get 2 copy gt ~exch if pop
        } if
      } if
    } for
    dup kbdowner eq {
      0 1 nodelist last {/knode name
        nodelist knode get /node name
        node 2 get null ne {
          node 4 get 2 copy gt ~exch if pop
        } if
      } for
    } if

    _t
    end
  } bind def


|------------------------ front end support ------------------------

|-------------------------------------- print node info
| If a nodes window exists, the node's entry is updated there (this
| includes showing a blank field left by disconnected nodes);
| otherwise the (existing) connection is printed (requires knode, node)

  /nodeclear {
    knode setready
    
    null  node 0 put
    null  node 1 put
    null  node 2 put
    false node 3 put
    0     node 4 put
    {}    node 5 put
    null  node 6 put
    ~nodeclear ssh_display indict

    knode kbdowner eq {0 _t} if
  } bind def

  /pbuf 80 /b array def
  
  /printnode {
    {
      Xwindows ~drawnode {
        node 6 get null ne {loadcolor} if
        node 0 get class /nullclass ne {
          pbuf 0 {
            -4 knode * number node 0 get fax
            knode 0 ne {
              (:) fax * node 1 get * number
              node 3 get { ( - busy  ) } { ( - ready ) } ifelse fax
              * node 4 get * number
            } if
            (\n) fax
          } node 6 get dup null ne {exch color_text} {pop exec} ifelse
          0 exch getinterval toconsole
        } if
      } ifelse
    } dvtsup indict
  } bind def

|-------------------------------------- setready or setbusy
| - usage: node# | --
| - sets node ready or busy
| - shows new node state in cluster window

  /setready { /knode name
    nodelist knode get /node name false node 3 put
    printnode
  } bind def

  /setbusy { /knode name
    nodelist knode get /node name true node 3 put
    printnode
  } bind def

  /setready_dnode {
    setready end restore
  } bind def

|---------------------------------------- setcolor
| Used when color_node is called
| translates [/color...] type list for color.d
| into instructions for the window system to add
| a color code to the node.
|
| [/color_name...] node# | -- <<nodelist->node#->5 is set>> 
|
  /setcolor {
    Xwindows {
      dvtsup begin colorize begin {/knode name /colorlist name
        /node nodelist knode get def
        reset
        colorlist {mkact exec} forall
        ~[
          (   ) BLACKTEXT ~drawtext
          nodeforecolor
          nodebackcolor
          nodebold
          nodeitalic
          nodefaint
          nodeul
          nodeblink
          nodeneg
        ] node 5 put
        drawnode
      } stopped end end ~stop if
    } {pop pop} ifelse
  } bind userdict 3 -1 roll put

|---------------------------------------- color_node_def
| Used when _csu2 is called
| Checks for a color setting in nodelist,
| and if non-null, call color_node for that node
|
| <<nodelist->node#->6 is set/null>> node# | --
|
  /color_node_def {
    dvtsup /nodelist get 1 index get 6 get
    dup null eq {pop pop Xwindows ~drawnode if} {exch color_node} ifelse
  } bind userdict 3 -1 roll put
  
  Xwindows {
    /colorize 100 dict dup begin | {
      /NORMALFONT {fontdict /NORMALFONT get} bind def
      /BOLDFONT {fontdict /BOLDFONT get} bind def
      /ITALICFONT {fontdict /ITALICFONT get} bind def
      /BOLDITALICFONT {fontdict /BOLDITALICFONT get} bind def
      
      /BLACK   <d 0   0   0  > mapcolor def
      /RED     <d 1   0   0  > mapcolor def
      /GREEN   <d 0   1   0  > mapcolor def
      /BLUE    <d 0   0   1  > mapcolor def
      /WHITE   <d 1   1   1  > mapcolor def
      /YELLOW  <d 1   1   0  > mapcolor def
      /MAGENTA <d 1   0.5 0.5> mapcolor def
      /CYAN    <d 0.5 0.5 1  > mapcolor def
      
      /makecolortext {~NORMALFONT [null 4 -1 roll -1 0] makefont} bind def
      |/makecolortext {[NORMALFONT 3 -1 roll -1 0]} bind def
      /BLACKTEXT   BLACK   makecolortext def
      /REDTEXT     RED     makecolortext def
      /GREENTEXT   GREEN   makecolortext def
      /YELLOWTEXT  YELLOW  makecolortext def
      /BLUETEXT    BLUE    makecolortext def
      /MAGENTATEXT MAGENTA makecolortext def
      /CYANTEXT    CYAN    makecolortext def
      /WHITETEXT   WHITE   makecolortext def

      /makefonttext {[null BLACK -1 0] makefont} bind def
      |/makefonttext {[exch BLACK -1 0]} bind def
      /BOLDTEXT   ~BOLDFONT       makefonttext def
      /ITALICTEXT ~ITALICFONT     makefonttext def
      /FAINTTEXT  {BLACKTEXT}                  def
      /UNDERTEXT  {BLACKTEXT}                  def
      /SLOWTEXT   {BOLDTEXT}                   def
      /RAPIDTEXT  ~BOLDITALICFONT makefonttext def
      /NEGTEXT    {WHITETEXT}                  def 

      /red     {/nodeforecolor {( Fr) REDTEXT     ~drawtext} bind def} bind def
      /black   {/nodeforecolor {( Fb) BLACKTEXT   ~drawtext} bind def} bind def
      /green   {/nodeforecolor {( Fg) GREENTEXT   ~drawtext} bind def} bind def
      /yellow  {/nodeforecolor {( Fy) YELLOWTEXT  ~drawtext} bind def} bind def
      /blue    {/nodeforecolor {( Fl) BLUETEXT    ~drawtext} bind def} bind def
      /magenta {/nodeforecolor {( Fm) MAGENTATEXT ~drawtext} bind def} bind def
      /cyan    {/nodeforecolor {( Fc) CYANTEXT    ~drawtext} bind def} bind def
      /white   {/nodeforecolor {( Fw) WHITETEXT   ~drawtext} bind def} bind def
      
      /on_red  {/nodebackcolor {( Br) REDTEXT     ~drawtext} bind def} bind def
      /on_black {/nodebackcolor {( Bb) BLACKTEXT   ~drawtext} bind def} bind def
      /on_green {/nodebackcolor {( Bg) GREENTEXT   ~drawtext} bind def} bind def
      /on_yellow 
      {/nodebackcolor {( By) YELLOWTEXT  ~drawtext} bind def} bind def
      /on_blue    
      {/nodebackcolor {( Bl) BLUETEXT    ~drawtext} bind def} bind def
      /on_magenta 
      {/nodebackcolor {( Bm) MAGENTATEXT ~drawtext} bind def} bind def
      /on_cyan    
      {/nodebackcolor {( Bc) CYANTEXT    ~drawtext} bind def} bind def
      /on_white   
      {/nodebackcolor {( Bw) WHITETEXT   ~drawtext} bind def} bind def

      /bold        {/nodebold   {( Sb) BOLDTEXT   ~drawtext} bind def} bind def
      /italic      {/nodeitalic {( Si) ITALICTEXT ~drawtext} bind def} bind def
      /faint       {/nodefaint  {( Sf) FAINTTEXT  ~drawtext} bind def} bind def
      /underlined  {/nodeul     {( S-) UNDERTEXT  ~drawtext} bind def} bind def
      /slow_blink  {/nodeblink  {( Ss) SLOWTEXT   ~drawtext} bind def} bind def
      /rapid_blink {/nodeblink  {( Sr) RAPIDTEXT  ~drawtext} bind def} bind def
      /negative    {/nodeneg    {( Sn) NEGTEXT    ~drawtext} bind def} bind def
      
      /reset {
        /nodebold      {} def
        /nodeitalic    {} def
        /nodefaint     {} def
        /nodeul        {} def
        /nodeblink     {} def
        /nodeneg       {} def
        /nodeforecolor {} def
        /nodebackcolor {} def
      } def | }
    end def
  } if

|------------------ machinery of 'nodes' window -----------------------
|
| If Xwindows is available, we maintain a window that indicates the state
| of the dvt and currently connected dnodes (the 'nodes') and allows some
| functions to be initiated by mouse clicks.
|
| The nodes window starts with a single entry, 'dvt', in the top row,
| and adds new connections in lower rows. Each dnode is shown as
| 'hostname:port#'. The current owner(s) of the keyboard is(are) highlighted
| (blue, bold text). The status each dnode is indicated by the color of its
| background (white for 'ready' and green for 'busy'). Busy dnodes will not
| be given a new keyboard phrase unless the phrase is tagged by '!'.
|
| A simple mouse click into the nodes window selects a new owner of the
| keyboard, regardless of the state of dnodes. Note that this chooses a
| single node as the owner of the keyboard. This node is highlighted in
| the nodes window.
|
| A 'control' mouse click over a dnode selects the entire group of dnodes
| to which this dnode belongs as owners of the keyboard. All dnodes of the
| group are highlighted in the nodes window.
|
| A dnode that is hung in the busy state is reset by a 'shift-click' into
| its cluster window field (this resets only the lock that makes the dvt
| reject normal keyboard phrases for this dnode; the dnode itself is not
| altered).
|
| The services of the cluster window are duplicated through dvt procedures
| that you can invoke from the keyboard (obviously this is your resort when
| Xwindows is not available).
  Xwindows {
    /makeTheHorses {
      /wW 200 2 add def
      /wH nodelist length 13 mul 2 add def
      /woutline [ 0 0 wW 1 sub 0 wW 1 sub wH 1 sub 0 wH 1 sub 0 0 ] def

      /noderects [
        /x 1 def
        1 13 nodelist length 1 sub 13 mul 1 add { /y name
          /r 4 /w array def
          x r 0 put  y r 1 put wW 2 sub r 2 put 13 r 3 put
          r
        } for
      ] def

      /nodelocs [
        /x 5 def
        12 13 nodelist length 1 sub 13 mul 12 add { /y name
          [ x y 6 sub ] mkact
        } for
      ] def

      screensize /scrH name /scrW name
      [ [ scrW wW sub 10 sub scrH wH sub 10 sub wW wH ] | ]
      (TheHorses) (Horses) makewindow /wid name pop
      dvtsup userdict debug_dict /line get {
        (/w) fax * wid * number
      } tostring mkact exec put
      /busy false def
      wid true mapwindow
      wid userdict /TheHorsesWid put
    } bind def

    /NORMALFONT {fontdict /NORMALFONT get} def
    /BOLDFONT {fontdict /BOLDFONT get} def
    
    /BLACK <d 0 0 0 >      mapcolor def
    /GRAY  <d 0.2 0.2 0.2> mapcolor def
    /BLUE  <d 0 0 1 >      mapcolor def
    /RED   <d 1 0 0 >      mapcolor def
    /LBLUE <d 0.1 0.1 0.9> mapcolor def

    /BG <d 235 243 248 >  255 div mapcolor def
    /HBG <d 166 219 160 > 255 div mapcolor def
    
    /NORMALTEXT ~NORMALFONT [null BLACK -1 0] makefont def
    /HIGHTEXT ~BOLDFONT [null BLUE -1 0] makefont def

|--------------------------------------------- resist resizing

    /windowsize {
      wH ne exch wW ne or {
        { [ | ]
          wid wW wH resizewindow
        } stopped cleartomark
      } if end
    } bind def

|--------------------------------------------- draw cluster window

    /drawwindow {
      { [ busy ~stop if     | stop capsule + reentry prevention ]
        /busy true def
        wid woutline BLACK drawline
        0 1 nodelist length 1 sub { /knode name
          nodelist knode get /node name
          drawnode
        } for
      } stopped cleartomark /busy false def
      end
    } bind def

    /drawnode {
      wid noderects knode get 
      node 3 get ~HBG ~BG ifelse fillrectangle

      node 0 get class /nullclass ne {
        wid nodelocs knode get exec
        pbuf {
          * knode * number (: ) fax
          node 0 get fax
          knode 0 ne {
            (:) fax * node 1 get     * number
            ( ) fax * node 4 get neg * number
          } if
        } tostring
        kbdowner 0 ge ~knode {node 4 get} ifelse kbdowner eq 
        ~HIGHTEXT ~NORMALTEXT ifelse
        drawtext node 5 get exec pop pop pop
      } if
    } bind def

|------------------------------------------------- mouseclick
| - a simple mouse click selects a node

    /thehorses_actions 5 dict dup begin | {
      /raise {userdict begin raise_emacs} bind def
      
      /click {node 0 get class /nullclass ne {
        /kbdowner knode def c_
      } if} bind def
      
      /cancel {node 0 get class /nullclass ne {
        false nodelist knode get 3 put c_
      } if} bind def
      
      /group {node 0 get class /nullclass ne {
        node 4 get _t
      } if} bind def

      /map {node 0 get class /nullclass ne {
        knode 0 eq {null true mapwindow} {
          node 3 get not {
            node 2 get {Xwindows {null true mapwindow} if restore} send
          } if
        } ifelse
      } if} bind def | }
    end def

    /mouseclick { 
      { [ 4 1 roll busy {stop} if  | stopped and reentry lock | ]
        /busy true def
        /mS name /mY name /mX name
        /knode mY 1 sub 13 div def
        nodelist knode get /node name
        mS /thehorses thehorses_actions commonmousedict mouseaction pop
      } stopped cleartomark /busy false def
      end 
    } bind def
  } if
  | }
end userdict 3 -1 roll put

|--------------------------------- macros ------------------------------
| 
| This facility lets you establish macro windows that show a set of
| keywords. Clicking a keyword writes a command template to the console.
| You can use this template with standard emacs commands; in addition,
| function key 1, in conjunction with 'control', has been set up for the
| following shorthands:
|
| F1          - copy the last line of output (the template) into the
|               console input and enter an automatic 'return' to execute
|               the phrase
| control-F1  - copy the last line of output (the template) into the
|               console input (so you can edit the phrase and then press
|               'return' to execute the phrase)
|
| 'makemacros' (referenced in userdict) sets up a macro window:
| use: macrodict | --
|
| 'macrodict' will become the window dictionary of the macro window (a
| capacity of 50 should suffice). You need to define the following
| parameter entries in 'macrodict' before submitting 'macrodict' to
| 'makemacros':
|
|   myname       - header string for the macro window
|   myshortname  - ditto for the icon
|   keywords     - a procedure for placing keywords
|   commands     - flat list of strings associated with the keywords
|
| 'keywords' uses four operators to define keywords and placement:
|    NL             - close a prefixed group, start new row
|    (prefix) PRE   - define a prefix, open a group
|    (keyword) KEY  - define a keyword
|    #cols GAP      - close a prefixed group, insert white space
|
|  - keywords may be grouped but do not have to (groups are only a visual
|    help)
|  - 'prefix' strings usually are terminated by a colon; 'keyword' strings
|    include leading white space as to please the eye
|  - each 'command' string should be terminated by '\n'
|

/makemacros {
  { 
    Xwindows not ~stop if
    macros ~def forall

    screensize /scrH name /scrW name
    /nkeys 0 def /nrows 1 def
    [ [~keywords pass0 indict] ] /rowlist name
    commands length nkeys ne
      { (Macros: keys do not match commands!\n) toconsole stop } if
    /wW 1 def /wH nrows rowH mul 6 add def
    [ [ 2 scrH wH sub 2 sub wW wH ] | ]
    myname myshortname makewindow /wid name pop
    /woutline ~[[0 0 wW 1 sub 0 wW 1 sub wH 1 sub 0 wH 1 sub 0 0] {
      wW 1 sub 1 index 2 put
      wW 1 sub 1 index 4 put
      } ~exec] bind def
    |/woutline [ 0 0 wW 1 sub 0 wW 1 sub wH 1 sub 0 wH 1 sub 0 0 ] def
    /wpane ~[[ 1 1 wW 2 sub wH 2 sub ] {
      wW 2 sub 1 index 2 put
      } ~exec] bind def
    |/wpane [ 1 1 wW 2 sub wH 2 sub ] def
    /line 4 /x array def
    /newmacros true def
    currentdict userdict debug_dict /line get 0 (/w) fax * wid * number
      0 exch getinterval mkact exec put
    wid true mapwindow
  } exch ~indict stopped pop
} userdict 3 -1 roll put

   
|---------------------------- macros ----------------------------------

Xwindows {
  /macros 100 dict dup begin | {
  
    /NORMALFONT {fontdict /NORMALFONT get} bind def
    /BOLDFONT {fontdict /BOLDFONT get} bind def
    /BLACK <d 0 0 0 > mapcolor def
    /GRAY  <d 0.5 0.5 0.5 > mapcolor def
    /BLUE  <d 0 0 1 > mapcolor def
    /RED   <d 1 0 0 > mapcolor def
    /BG <d 235 243 248 > 255 div mapcolor def
    /TEXT ~BOLDFONT [null BLACK -1 -1] makefont def
    /rowH 20 def

  |------------------ resist resizing of a macro window

    /windowsize {
      wH ne exch wW ne or {
        { [ | ]
          wid wW wH resizewindow
        } stopped cleartomark
      } if
      end
    } bind def

  |------------------ draw a macro window

    /drawwindow {
      { [ | ]
        wid woutline BLACK drawline
        wid wpane BG fillrectangle
        newmacros { [ [ } if | ] ]
        rowH 1 sub dup line 1 put line 3 put
        /x_ 0 def /x 5 def /y rowH 2 sub def
        ~keywords pass1 indict
        /wW x_ 5 add def
        wid wW wH resizewindow | [ [
          newmacros { ] ] /boxlist name} if
        /newmacros false def
      } stopped cleartomark
      end
    } bind def

  |------------------ respond to a mouseclick into a macro window
    /outcolor [/blue /bold] def
    
    /checkcolor {
      userdict /color known {
        /checkcolor {} def
        0 1 rowlist length 1 sub {
          dup rowlist exch get length 1 sub
          0 1 3 -1 roll { | r# c#
            outcolor rowlist 3 index get 2 index get color_string
            rowlist 3 index get 3 -1 roll put
          } for
          pop
        } for
      } if
    } def
  
    /macros_actions {
      /click {}
    } bind makestruct def
    
    /mouseclick { 
      { [ 4 1 roll | ]
        /mS name /mY name /mX name
        mS /macros macros_actions commonmousedict mouseaction not ~stop if
        /krow mY 1 sub rowH div def
        /kbox 0 def
        checkcolor
        false boxlist krow get {/box name
          mX box 0 get ge {mX box 1 get le {pop true exit} if} if
          /kbox kbox 1 add def
        } forall {
          goto_point_emacs_
          rowlist krow get kbox get dup active ~exec ~toconsole ifelse
        } if
      } stopped cleartomark
      end 
    } bind def

  |------------------ pass0: count keywords, rows for window layout

    /pass0 {
      /NL  { ][ /nrows nrows 1 add def}
      /PRE pop
      /KEY {pop commands nkeys get /nkeys nkeys 1 add def}
      /GAP pop
    } bind makestruct mkread def

  |------------------ pass1: render (and measure) text and underlines;
  |                          a box gives the left and right x of the
  |                          keyword text
    /pass1 {
      /xname {dup /x name dup x_ le ~pop {/x_ name} ifelse}
    
      /NL  {
        ul { /ul false def x line 2 put
          wid line GRAY drawline
        } if
        line 1 get rowH add dup line 1 put line 3 put
        5 xname /y y rowH add def
        newmacros { ] [ } if
      }

      /PRE { /s name x line 0 put /ul true def
        wid x y s TEXT drawtext pop xname pop
      }
    
      /KEY { /s name
        /xl x def
        wid x y s TEXT drawtext pop xname pop
        newmacros { /box 2 /x array def
          xl box 0 put x box 1 put
          box
        } if
      }
  
      /GAP {
        ul { /ul false def x line 2 put
          wid line GRAY drawline
        } if
        {wid x y ( ) TEXT drawtext pop xname pop} repeat
      }
    } bind makestruct mkread def
  
    | }
  end userdict 3 -1 roll put
} if

|-------------------------------- debug_aborted
| version of aborted which sets abort to debug_abort
| and undoes it if no abort occurs
| -- debug_abort undoes itself when called
/debug_aborted { | {} --> ???
  debug_abort_su aborted debug_abort_end {(abort\n) toconsole abort} if
} bind def

|----------------------------------------- color_node
| set the default text color for a node
|
| [/color_name...] node# | --- <<changed text color>>
|
/color_send {
  {null 1 index capsave transcribe make_toconsole restore}
} def

/color_node {
  2 copy setcolor
  exch color_send 0 put
  dvtsup begin nodelist exch get 2 get end color_send send
} bind def

|----------------------------------------- color_nodes
| sets the default text color for node 1...n
|
| [[/color_name...]...] | --- <<changed text color>>
| if the list for a node is empty, the node is skipped
|  
/color_nodes {
  1 1 2 index length {
    2 copy 1 sub get dup length 0 ne {
      exch color_node
    } {pop pop} ifelse
  } for pop
} bind def

Xwindows {
  /take_input_focus ~end bind def
  /raise_emacs ~end bind def
  /goto_point_emacs ~end bind def
  /goto_point_emacs_ null mkact def

  /take_input_setup {pop pop} bind def
  /ENABLE_EMACSCLIENT {
    /take_input_setup {
      {
        /emacs_buffer_name name /emacs_server_name name
        /emacs_client_cmd | [
          getstartupdir length (emacsclient-run.sh) length add /b array 0
          getstartupdir fax (emacsclient-run.sh) fax pop | ]
        def
        /goto_point_emacs_ {currentdict begin goto_point_emacs} bind def

        {
          {/take_input_focus null mkact (focus)}
          {/raise_emacs null mkact (focus-raise)}
          {/goto_point_emacs null mkact (process-mark)}
          {/F1_KEY ~goto_point_emacs_ (invert)}
          {/F2_KEY ~goto_point_emacs_ (continue)}
          {/F3_KEY ~goto_point_emacs_ (stop)}
          {/F4_KEY ~goto_point_emacs_  (abort)}
          {/CTRL_1_KEY ~goto_point_emacs_ (toggle-scream)}
        } {
          exec ~[
            3 -1 roll
            ~openlist
            emacs_client_cmd
            emacs_server_name
            1024 /b array 0 | [
              (\(d-comint-mode-) fax 8 -1 roll fax 
              ( ") fax emacs_buffer_name fax (") fax
              (\)) fax
              0 exch getinterval | ]
            {
              {
                NULLR NULLW STDERR _sh_ 
                wait not {(emacs-client) /NOSYSTEM makeerror} if
              } PROCESSES ~indict stopped cleartomark
              end
            } ~exec
          ] bind def
        } forall
      } userdict indict
    } bind def
  } if_compile

  /raise_thehorses {TheHorsesWid true mapwindow end} bind def
  /raise_all {
    dvtsup /nodelist get 1 1 index length 1 sub getinterval {
      dup 0 get null eq {pop} {
        dup 3 get {pop} {
          2 get {{null true mapwindow} lock restore} send
        } ifelse
      } ifelse
    } forall
    null true mapwindow end
  } bind def
  /hide_all {
    dvtsup /nodelist get 1 1 index length 1 sub getinterval {
      dup 0 get null eq {pop} {
        dup 3 get {pop} {
          2 get {{null false mapwindow} lock restore} send
        } ifelse
      } ifelse
    } forall
    null false mapwindow end
  } bind def
} if

        
|----------------------------- start the dvt ------------------------------
| A 'save' representing a clean dvt is associated with the name cleanDVT in
| userdict.

(dvt) userdict /myid put

(Starting...\n) toconsole
{
  /reqfiles [
    (processes.d)
  ] def
  /optfiles [
    {getconfdir (dvt.d)} 
    {gethomedir (.dvt)}
  ] def
} {
  reqfiles ~loadstartup  forall
  optfiles {exec loadopt} forall
} ~incapsave aborted {countdictstack 2 sub ~end repeat clear} if

(Deuterostome Copyright \(C\) 2011 Alexander Peyser & Wolfgang Nonner
This program comes with ABSOLUTELY NO WARRANTY
This is free software, and you are welcome to redistribute it
under certain conditions. See COPYING for details.
) toconsole

{
  save /cleanDVT name
  /kbdowner 0 def
  makeNodes
  Xwindows {
    getstartupdir (theeye.d) fromfiles
    getstartupdir (dvt_macros.d) fromfiles
    makeTheHorses
  } if

  supervisor   | we never return
} dvtsup indict

