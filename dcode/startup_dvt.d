
|============================ D Startup =================================

(Using startup_dvt 6/15/05\n) toconsole        | hi!

| Contains procedures for:
|  - inspection of objects
|  - object/text interconversion
|  - transcription of objects
|  - file <=> VM interchange
|  - module support


|============================= userdict =================================

/false 0 1 eq def                             | boolean prototypes
/true 0 0 eq def

2 list dictstack dup 0 get /systemdict name   | name the roots
                     1 get /userdict name

/setlock {pop} bind def  | null ops to parallel dnode
/getlock {true} bind def |
/lock {exec} bind def    | 

|------------------------ low-level information -------------------------
| For debugging and quick information about objects, stacks, and system
| resources use:

| _   show top object of operand stack in brief form
| v_  show value of composite top object of operand stack
| s_  show value of string top object of operand stack 
| a_  show all objects on operand stack in brief form, top first

| d_  show top object of dictionary stack in brief form
| da_ show all objects on dictionary stack in brief form
| dg_ get k-th element from top of dictionary stack (0 = top)

| xa_ show all objects on execution stack in brief form
| xg_ get k_th element from top of execution stack (0 = top)

| m_  show current stack, VM, and AM use


/debug_dict 50 dict dup begin

/line 100 /b array def
/line1 100 /b array def

/oclasses 10 dict dup begin                      | object
   /nullclass  { * (null) text } bind def
   /numclass   { * object * number } bind def
   /opclass    { * (op: ) text * /object find text } bind def
   /nameclass  { /object find active not { * (/) text } if
                 * /object find text } bind def
   /arrayclass { * (<) text  * /object find type text * ( .. > of ) text
                 * /object find length * number } bind def
   /listclass  { * /object find active
                    { ({ .. } of ) } { ([ .. ] of ) } ifelse text
                 * /object find length * number } bind def
   /dictclass  { * (dict of ) text
                 * object length * number * ( max and ) text
                 * object used * number * ( used) text } bind def
   /markclass  { * ([) text } bind def
   /boolclass  { * object {(true)} {(false)} ifelse text } bind def
   /boxclass   { * (box of ) text
                 * object length * number * ( bytes) text } bind def
end mkread def

/vclasses 10 dict dup begin                  | value
   /nullclass  /_ mkact def
   /numclass   /_ mkact def
   /opclass    /_ mkact def
   /nameclass  /_ mkact def
   /arrayclass { intuples } def
   /listclass  { { _ pop } forall } bind def
   /dictclass  { { exch
                   line 0
                   -16 4 -1 roll text 
                   0 exch getinterval toconsole showobj pop
                 } forall
               } bind def 
   /markclass  /_ mkact def
   /boolclass  /_ mkact def
   /boxclass   /_ mkact def
end mkread def

/showobj { dup /object name
   /object find readonly { (r ) } { (  ) } ifelse toconsole
   line 0 /object find oclasses begin class mkact exec end
   * (\n) text 0 exch getinterval toconsole
} bind def

/tuples 5 dict dup begin
   /B 10 def
   /W 10 def
   /L 5 def
   /S 5 def
   /D 2 def
end def

/intuples { /col 0 def
   { /value name tuples value type get /tuple name
     line 0 -80 tuple div value * number
     0 exch getinterval toconsole
     /col col 1 add dup tuple ge { pop 0 (\n) toconsole } if def
   } forall
  col 0 ne { (\n) toconsole } if
} bind def

/topfirst {                        | show list value in reverse order
   dup length 1 sub -1 0 { 
      2 copy get _ pop pop
      } for
   pop
} bind def

end def                            | of debug_dict

/_ { debug_dict begin              | show top object on opd stack
   count 0 eq
     { (OPDS is empty\n) toconsole }
     { showobj }
     ifelse
   end
} bind def

/a_ { debug_dict begin              | show entire opd stack
   count 1 sub 0 1 3 -1 roll { index _ pop } for
   end
} bind def

/v_ { debug_dict begin              | show value at top of opd stack
  dup vclasses begin dup class mkact exec end
  end
} bind def

/s_ { dup                           | show text string at top of opd stack
dup dup class /arrayclass eq exch type /B eq and
  { { (\n) search { toconsole toconsole }
                  { toconsole (\n) toconsole exit } ifelse
    } loop
  } { v_ } ifelse
} bind def

/m_ { debug_dict begin              | show memory capacities and usage
   vmstatus  /vmused name  /vmmax name
   line  0 19 (VM) text
           10 (DICTS) text
           10 (EXECS) text
           10 (OPDS) text
           * (\n) text
         0 exch getinterval toconsole
   line  0 -10 (max) text
            10 vmmax * number
            * (\n) text
         0 exch getinterval toconsole
   line  0 -10 (used) text
            10 vmused * number
            10 countdictstack * number
            10 countexecstack * number
            10 count * number
            * (\n) text
         0 exch getinterval toconsole
   end
} bind def

/d_  { currentdict _ pop } bind def
/da_ { countdictstack list dictstack
       debug_dict begin topfirst end } bind def
/dg_ { countdictstack list dictstack
       dup length 3 -1 roll sub 1 sub get } bind def
/xa_ { countexecstack list execstack 
       debug_dict begin topfirst end } bind def
/xg_ { countexecstack list execstack
       dup length 3 -1 roll sub 1 sub get } bind def

|----------------------- object-to-text conversion ------------------------

| The following procedures operate on collections of objects organized
| in 'trees'. A tree comprises a root (dictionary or list) and recursively
| all objects nested therein.

| A tree can be encoded into text form through 'xtext', 'xtexts', or 
| 'pstext'. These translate a tree specified by its root object into
| text accumulated in a string as by the 'text' operator. 'xtext' expands
| byte array values as numerals, 'xtexts' expands byte array values
| literally, and 'pstext' works like 'xtexts' and in addition translates
| arrays into lists for use by PostScript.
| 
| use:  textbuffer index object | textbuffer index

/xtext  { xtext_dict begin /dprec 15 def /d_bnum totext end } bind def
/xtexts { xtext_dict begin /dprec 15 def /d_blit totext end } bind def
/pstext { xtext_dict begin /dprec 6 def /ps_blit totext end } bind def

/xtext_dict 40 dict dup begin
 
/inword { dup class mkact exec } bind def

/newline { * (\n) text indents () text /colleft 75 indents sub def 
} bind def

/indent { indents add /indents name } bind def

/ftext { /chunk name 
  colleft chunk length 1 add sub /colleft name colleft 0 lt 
    { newline * chunk text /colleft colleft chunk length sub def } 
    { * ( ) text * chunk text }
    ifelse
} bind def

/objstr 40 /b array def

/nullclass  { pop (null) ftext } bind def
/numclass   { dup type mkact exec } bind def
/opclass    { objstr 0 * 4 -1 roll text 0 exch getinterval ftext
            } bind def
/nameclass  { /obj name
              objstr 0 /obj find active not { * (/) text } if
              * /obj find text 0 exch getinterval ftext
            } bind def

| arrayclass is alternately associated with:

/d_bnum { mkpass _arrayclass } bind def

/d_blit { mkpass dup
          type mkact d_blit_dict begin exec end mkact exec } bind def
/d_blit_dict 5 dict dup begin
   /B /_stringclass def
   /W /_arrayclass def
   /L /_arrayclass def
   /S /_arrayclass def
   /D /_arrayclass def
end mkread def

/ps_blit { mkpass dup 
           type mkact ps_blit_dict begin exec end mkact exec } bind def
/ps_blit_dict 5 dict dup begin
   /B /_stringclass def
   /W /listclass def
   /L /listclass def
   /S /listclass def
   /D /listclass def
end mkread def

/listclass  { dup /obj name active
              { newline ({) ftext 2 indent 
                /obj find { inword } forall
                -2 indent (}) ftext
              }
              { newline ([) ftext 2 indent 
                obj { inword } forall
                -2 indent (]) ftext
              }
              ifelse
            } bind def
/dictclass  { mkpass /obj name newline 
              obj length 
              objstr 0 * 4 -1 roll * number 0 exch getinterval
              ftext (dict dup begin) ftext
              2 indent
              obj { 4 -2 roll newline
                    4 -1 roll inword 3 -1 roll inword (def) ftext
                  } forall
              -2 indent (end) ftext
            } bind def
/boxclass   { pop (null) ftext} bind def | discard a box object
/markclass  { pop * ([) text } bind def
/boolclass  { {(true)} {(false)} ifelse ftext } bind def

/_stringclass { /obj name
                newline * (\() text * obj text * (\)) text } bind def
/_arrayclass { /obj name
               newline objstr 0 * (<) text * obj type text
               0 exch getinterval ftext 3 indent
               obj { dup type mkact exec } forall
               -3 indent (>) ftext
             } bind def

/B { objstr 0 4 4 -1 roll * number 0 exch getinterval ftext } bind def
/W { objstr 0 6 4 -1 roll * number 0 exch getinterval ftext } bind def
/L { objstr 0 11 4 -1 roll * number 0 exch getinterval ftext } bind def
/S { objstr 0 13 4 -1 roll 6 number 0 exch getinterval ftext } bind def
/D { objstr 0 dprec 8 add 4 -1 roll dprec number
     0 exch getinterval ftext } bind def

/totext { find /arrayclass name /obj name
   /indents 0 def newline
   /obj find inword
   newline
} bind def

end def  | of xtext_dict

|------------------------------ file <-> VM -----------------------------

| Two symmetrical procedures, 'tofiles' and 'fromfiles' transport any
| objects and collections thereof between files and VM. These objects
| may be organized in a tree, but do not have to.

| 'tofiles' collects objects layed down in text form by a generating
| procedure that uses operators such as 'text' or procedures such as 
| 'pstext', and saves the resulting string as a file.
| use:  dirname filename { object_generator } | --

/tofiles {
   save /tofilessave name
 { 
   vmstatus sub 5 div 4 mul /b array tofilessave capsave
   0 3 -1 roll exec
   0 exch getinterval 3 1 roll writefile
 } stopped pop tofilessave restore
} bind def

| 'fromfiles' performs the converse of 'tofiles', by reading a text file
| into a transient string object and executing that string.
| use: dirname filename | objects..  (and/or side effects)

/fromfiles { 
   save /fromfilessave name
 {
   vmstatus sub 3 div /b array fromfilessave capsave
   readfile mkact exec
 } stopped pop fromfilessave restore
} bind def

|====================== Support for toolboxes and projects =====================
|
| Toolboxes, projects, and snapshots all are modules. A module is a tree of
| objects rooted in a module dictionary, which is referenced in 'userdict'.
| The procedures 'module', '_module', and 'forgetmodule' found in 'userdict'
| support the concept of discardable modules. They involve a 'save' object
| that is referenced under 'mySave' in the dictionary of the module; the name
| of the module is automatically referenced in that dictionary under 'myName'.
| These are the only book keeping devices of a module.
|
| Toolboxes, projects, and snapshots are different varieties of module but 
| there is no formal difference between these modules. The difference is 
| between their uses. 
|
| A toolbox holds a collection of procedures that can subserve a variety of
| projects. Toolboxes can be swapped on the fly, replacing older by newer
| versions without interrupting the continuity of the projects that they
| subserve. The VM space used by the toolbox is reclaimed in the swap.
| The tools 'module' and '_module' found in 'userdict' effect swaps
| transparently.
|
| Toolboxes are not responsible for information that belongs to clients. The
| client must provide the appropriate current dictionary when using a
| tool. The chosen current dictionary belongs to the client and receives
| the objects defined during the activity of tools. This rule is necessary if
| toolboxes are to be swappable, or are to be usable in arbitrary order in
| arbitrary projects.
|
| A project module is a tree of objects that model a reality. The module 
| dictionary is the root of that tree. The project may also comprise private
| tools. A project is typically built in layers that correspond to well-defined
| stages of completion. Thus, besides the organization as a tree of objects,
| there exists an organization of layers, each represented by a 'save' object
| that is referenced under a layer name in the project dictionary itself.
| Individual layers of growth can be built/discarded/rebuilt using the 
| 'layer' and '_layer' tools found in 'userdict'. Note that, unlike 
| removal of a layer of growth from a natural tree, removal of a layer of a
| project does not automatically remove the layers of more recent growth.  
|
| Sometimes it is desirable to store a snapshot of an entire project for later
| retrieval. This concept is supported by the 'savemodule' and
| 'restoremodule' tools found in 'userdict'. The restoration automatically
| discards an existing incarnation of the project by reclaiming the VM space 
| of the project module itself and of all layers of the old project tree.
| It then creates a project as a replica of the snapshot, preserving the
| snapshot itself for future uses. In order to discard a snapshot, apply
| the tool 'forgetmodule' found in userdict.
|
| A snapshot is suited for transfer/retrieval to/from an external VM (using
| 'tobox'/'frombox') or to/from  a text file (using 'tofiles'/'fromfiles').
|
| A subtlety of snapshots involves the reclaiming of VM space that is used
| by layers. When a snapshot is saved, the VM spaces of the project's 
| layers are merged with the VM space of the virgin project. New layers
| may be created and discarded after a project is restored from a snapshot,
| but the VM space taken by that snapshot, which includes all layers of the
| project existing at the time of the snapshot, is reclaimed only when the
| project itself is discarded or replaced by  another snapshot.

|---------------------------- forgetmodule
| /module_name | --
|
| discards the module 'module_name', reclaiming its VM space. 'forgetmodule'
| has to be used with no references to the module existing on stacks.
| It discards not only the module itself, but also all layers of a module 
| that constitutes a project.

/forgetmodule {
  userdict exch 2 copy known { | userdict /module
    get dup class /dictclass eq { | module
      dup { | module key value
        dup class /boxclass eq 3 -1 roll | module value bool key
        /mySave ne and {restore} {pop} ifelse | module 
      } forall | module
      /mySave get dup class /boxclass eq {restore} {pop} ifelse | module
    } {pop} ifelse
  } {pop pop} ifelse |
} bind def

|---------------------------- module
| /module_name | /module_name savebox
|
| discards an existing former version of 'module_name', performs a 'save'
| operation.

/module { dup forgetmodule save } bind def

|---------------------------- _module
| /module_name savebox module_dict | --
|
| caps 'savebox', references it under 'mysave' in 'module_dict', references
| '/module_name' under 'myName' in 'module_dict', and references 'module_dict'
| under 'module_name' in 'userdict'.

/_module {
  begin dup capsave /mySave name dup /myName name currentdict end
  userdict 3 -1 roll put
} bind def

|----------------------------- layer
| /layer_name | --
|
| use with the project dictionary as the current dictionary. 'layer'
| discards an existing version of 'layer_name', performs a 'save' operation,
| and references the 'save' object under 'layer_name' in the project
| dictionary.

/layer {
  dup currentdict exch known { 
    dup find dup class /boxclass eq { restore } { pop } ifelse
  } if
  save def
} bind def
| The definitions of objects in the layer must be encapsulated in a 'stopped'
| context:
|
| { definition ... } stopped

|------------------------------ _layer
| boolean /layer_name | boolean
|
| use with the project dictionary as the current dictionary. '_layer'
| checks 'boolean'. If 'boolean' is true (signaling that a 'stop' operation
| has been executed somewhere inside the context of the layer), the 'save'
| object referenced by 'layer_name' is restored, thus discarding the 
| objects accrued in the layer. If 'boolean' is false (signaling that the
| definitions of the layer have been sucessfully executed), the 'save' object
| referenced under 'layer_name' is capped. '_layer' passes on the value of
| 'boolean' to its client.

/_layer {
  find exch {restore true} {capsave false} ifelse
} bind def 

|------------------------------- savemodule
|  /project_name /snapshot_name | --
|
| Execute 'savemodule' with 'userdict' as the current dictionary. 
| 'savemodule' looks up the module dictionary referenced under
| 'project_name' in 'userdict'. Executes 'save', makes a replica of the module
| tree, caps the 'save' object, and references the 'save' object under
| 'mySave' in the replica. References the replica under 'snapshot_name' in
| 'userdict'. If 'projectname' does not exist or does not reference a
| dictionary, you are asked to Think. 

/savemodule {
  userdict 3 -1 roll 2 copy known
   { get dup class /dictclass eq
     { save exch transcribe exch dup capsave exch
       dup 3 1 roll /mySave put
       def true
     } { pop pop false } ifelse
   } { pop pop pop false } ifelse
  not { (Think!\n) toconsole } if
} bind def

|-------------------------------- restoremodule 
|  /snapshot_name | --
|
| Execute 'restoremodule' with 'userdict' as the current dictionary.  
| 'restoremodule' looks up the dictionary referenced under 'snapshot_name'
| in 'userdict'. Looks up the project name referenced under 'myName' in the
| snapshot dictionary. Discards a project existing under that name in 
| 'userdict'. Makes a replica 'snapshot_name' and references that replica
| under the project name in 'userdict'. 

/restoremodule {
  userdict exch get dup /myName get dup forgetmodule
  exch save exch transcribe exch dup capsave exch
  dup 3 1 roll /mySave put
  def
} bind def

|--------------------------- Supervisor of the dvt ---------------------------

100 dict dup begin

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
{ {
    { linebuf nextevent } aborted
       { countdictstack 2 sub ~end repeat clear dvt begin
         /kbdowner 0 def c_
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
  dup /line name length 0 gt {
      (!$#@) line 0 1 getinterval search
         { length 1 add /linetag name pop pop
           /line line 1 line length 1 sub getinterval def
         }
         { pop 0 /linetag name }
         ifelse
      tags linetag get exec
    } if 
} bind def

/tags [

|-- no tag
| dvt   - execute phrase
| dnode - ready: encapsulate phrase and send it to dnode
|         busy: discard phrase and print 'Wait!'

{ kbdowner 0 eq
   { line end mkact exec dvt begin
   }
   { { node 3 get 
        { (Wait!\n) toconsole
        }
        { knode setbusy
          node 2 get
          linebuf2 0 ({ ) fax
            line fax
            ( } stopped pop console \(dvt begin ) fax
            * knode * number ( setready end\) send) fax
          0 exch getinterval send
        } ifelse
     } fornodes
   }
   ifelse
} bind

|-- !
| dvt   - ignore tag and execute rest of phrase
| dnode - send phrase regardless of dnode state

{ kbdowner 0 eq
    { line end mkact exec dvt begin
    }
    { { node 2 get line send } fornodes
    }
    ifelse
} bind

|-- $
| dvt   - submit line to linux of dvt
| dnode - ready: encapsulate and submit as linux command to dnode
|         busy: discard phrase and print 'Wait!'

{ kbdowner 0 eq
   { combuf 0 line fax ( &) fax 0 exch getinterval tosystem
   }
   { { node 3 get 
        { (Wait!\n) toconsole
        }
        { knode setbusy
          node 2 get
          combuf 0 (\() fax line fax
          (\) tosystem console \(dvt begin ) fax
          * knode * number ( setready end\) send) fax
          0 exch getinterval send
        }
        ifelse
      } fornodes
   }
   ifelse
} bind

|-- #
| dvt   - treat like '@'
| dnode - ready: evaluate, encapsulate, and submit as shell command to dnode
|       - busy: discard phrase and print 'Wait!'

{ kbdowner 0 eq
   { combuf 0 line mkact end exec dvt begin
     ( &) fax 0 exch getinterval tosystem
   }
   { { node 3 get 
        { (Wait!\n) toconsole
        }
        { knode setbusy
          node 2 get
          combuf 0 (\() fax line mkact exec 
          (\) tosystem console \(dvt begin ) fax
          * knode * number ( setready end\) send) fax
          0 exch getinterval send
        }
        ifelse
     } fornodes
   }
   ifelse
} bind


|-- @
| dvt   - evaluate phrase and submit to shell
| dnode - ready: encapsulate, submit to dnode where the phrase is evaluated
|                and the result is submitted as shell command
|       - busy: discard phrase and print 'Wait!'

{ kbdowner 0 eq
   { combuf 0 line mkact end exec dvt begin
     ( &) fax 0 exch getinterval tosystem
   }
   { { node 3 get 
        { (Wait!\n) toconsole
        }
        { knode setbusy
          node 2 get
          combuf 0 (shellbuf 0 { ) fax line fax ( } exec 0 exch getinterval
          tosystem console \(dvt begin ) fax
          * knode * number ( setready end\) send) fax
          0 exch getinterval send
        }
        ifelse
     } fornodes
   }
   ifelse
} bind

] def

|-- loop operator to invoke an individual dnode or group of dnodes

/fornodes { /procfornodes name
  kbdowner 0 gt 
    { /knode kbdowner def /node nodelist knode get def
      /procfornodes find exec
    }
    { 1 1 nodelist length 1 sub { /knode name
          nodelist knode get /node name
          node 4 get kbdowner eq { /procfornodes find exec } if
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
| [ (hostname) port# socket status group color_list color_name]
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

/nodelist [
   [ (dvt) null null false 0 {} null ]
   9 { [ null null null false 0 {} null] } repeat
] def

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
_csu       hostname port# group <l opds dicts execs vm/M userdict > | --
   \(connect to a dnode and set up new resources\)
_dc        node# | --  \(disconnect from a dnode\)
_t         target | --  \(choose new owner\(s\) of the keyboard\)
_r         node# | --  \(reset 'busy status of a node\)
c_         list all connections
) toconsole 
} bind userdict 3 -1 roll put

|---------------------------------------------------- list active connections

/c_ {
  dvt begin
  0 1 nodelist length 1 sub { /knode name
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
  dvt begin {
    false 0 1 nodelist length 1 sub { /knode name
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
  dvt begin {
    false 0 1 nodelist length 1 sub { /knode name
      nodelist knode get /node name
      node 0 get class /nullclass eq { pop true exit } if
    } for not { (Too many nodes!\n) toconsole stop } if
    node 4 put
    2 copy connect node 2 put node 1 put node 0 put
    false node 3 put
    node 6 put

    node 2 get [[knode {
      getsocket setconsole
      console [[4 -1 roll] (0 get dvt begin _cc1)] send
    }] ({} forall exec)] send
  } stopped pop end
} bind userdict 3 -1 roll put

/_cc1 {
  {color_node_def} stopped pop end
} bind userdict 3 -1 roll put

|---------------------------------------------------- connect to node
| hostname port# group# | -- 
|
| connects to the node and makes itself the current dvt of the node;
| the node is assigned a group number (enter as NEGATIVE integer)
| Also connects the eye.

/_cx {
  dvt begin {
    false 0 1 nodelist length 1 sub { /knode name
      nodelist knode get /node name
      node 0 get class /nullclass eq { pop true exit } if
    } for not { (Too many nodes!\n) toconsole stop } if
    node 4 put
    2 copy connect node 2 put node 1 put node 0 put
    true node 3 put printnode

    node 2 get [ [getmydisplay knode {/knode name
      getsocket setconsole
      Xdisconnect
      Xconnect
      /filesave save def
      /fbuf vmstatus sub 10 div /b array def
      filesave capsave {
        startupdir (/theeye.d) fbuf readfile mkact exec
      } stopped pop filesave restore
      console [[knode] (0 get dvt begin _cx1)] send
    }] ( {} forall exec )] send
  } stopped pop end
} bind userdict 3 -1 roll put

/_cx1 {
  {setready} stopped pop end
} bind userdict 3 -1 roll put

|---------------------------------------------------- connect to node
| [/color...] hostname port# group# | -- 
|
| connects to the node and makes itself the current dvt of the node;
| the node is assigned a group number (enter as NEGATIVE integer)
| this version also sets the eye on the current console

/_ccx {
  dvt begin {
    false 0 1 nodelist length 1 sub { /knode name
      nodelist knode get /node name
      node 0 get class /nullclass eq { pop true exit } if
    } for not { (Too many nodes!\n) toconsole stop } if
    node 4 put
    2 copy connect node 2 put node 1 put node 0 put
    node 6 put
    true node 3 put printnode

    node 2 get [ [getmydisplay knode {/knode name
      getsocket setconsole
      Xdisconnect
      Xconnect
      /filesave save def
      /fbuf vmstatus sub 10 div /b array def
      filesave capsave {
        startupdir (/theeye.d) fbuf readfile mkact exec
      } stopped pop filesave restore
      console [[knode] (0 get dvt begin _ccx1)] send
    }] ( {} forall exec )] send
  } stopped pop end
} bind userdict 3 -1 roll put

/_ccx1 {
  {dup color_node_def setready} stopped pop end
} bind userdict 3 -1 roll put

|---------------------------------------------------- set up node
| hostname port# group# <l opds dicts execs vm/M userdict > | -- 
|
| connects to the node like '-c', primes its memory setup, reads
| startup_dnode.d, and makes itself the dvt of the node;
|
| uses getmydisplay as the Xserver for the dnode
| by default, dvtdisplay (in c)
| but can be redefined in userdict

/_csu {
  dvt begin
  { false 0 1 nodelist length 1 sub {/knode name
      nodelist knode get /node name
      node 0 get class /nullclass eq { pop true exit } if
    } for not { (Too many nodes!\n) toconsole stop } if
    4 1 roll node 4 put
    2 copy connect node 2 put node 1 put node 0 put
    true node 3 put printnode
    node 2 get [ 3 -1 roll ( vmresize ) ] send
    null node 6 put

    node 2 get [
      [otherXwindows knode
        { /knode name /otherXwindows name
          /filesave save def
          /fbuf vmstatus sub 10 div /b array def
          filesave capsave
          { startupdir (/startup_dnode.d) fbuf readfile mkact exec
          } stopped pop filesave restore
          console [
            [knode] otherXwindows {
              (0 get dvt begin _csu1x)
            } {
              (0 get dvt begin _csu1nox)
            } ifelse
          ] send
        }
      ] ( {} forall exec )
    ] send
  } stopped pop end
} bind userdict 3 -1 roll put

/getmydisplay 80 /b array Xdisplayname userdict 3 -1 roll put
/otherXwindows {Xwindows} bind userdict 3 -1 roll put

/_csu1x {/knode name
  {
    nodelist knode get /node name
    node 2 get [ [
      debug_dict /line1 get 0 node 0 get fax (:) fax * node 1 get * number
      0 exch getinterval 
      getmydisplay
      knode {/knode name
        Xconnect
        userdict /myid put
        console [[knode] (0 get dvt begin _csu2x)] send
      }] ( {} forall exec )]  send
  } stopped pop end
} bind userdict 3 -1 roll put

/_csu1nox {/knode name
  {
    nodelist knode get /node name
    node 2 get [ [
      debug_dict /line1 get 0 node 0 get fax (:) fax * node 1 get * number
      0 exch getinterval 
      knode {/knode name
        userdict /myid put
        console [[knode] (0 get dvt begin _csu2nox)] send
      }] ( {} forall exec )]  send
  } stopped pop end
} bind userdict 3 -1 roll put

/_csu2x {/knode name
  {
    nodelist knode get /node name 
    node 2 get [ [knode {/knode name
      /filesave save def
      /fbuf vmstatus sub 10 div /b array def
      filesave capsave
      { startupdir (/theeye.d) fbuf readfile mkact exec
      } stopped pop filesave restore
      1000 /b array userdict /shellbuf put
      console [[knode] (0 get dvt begin _csu3)] send
    } ] ( {} forall exec )] send
  } stopped pop end
} bind userdict 3 -1 roll put

/_csu2nox {/knode name
  {
    nodelist knode get /node name 
    node 2 get [ [knode {/knode name
      1000 /b array userdict /shellbuf put
      console [[knode] (0 get dvt begin _csu3)] send
    } ] ( {} forall exec )] send
  } stopped pop end
} bind userdict 3 -1 roll put

/_csu3 {/knode name
  {
    knode setready
    knode color_node_def
  } stopped pop end
} bind userdict 3 -1 roll put

|---------------------------------------------------- set up node
| [/color...] hostname port# group# <l opds dicts execs vm/M userdict > | -- 
|
| In addition to normal _csu behavior, colors the node on setup
|
/_ccsu {
  _csu dvt begin {node 6 put} stopped pop end
} bind userdict 3 -1 roll put

/_ccsum {
  _csum dvt begin {node 6 put} stopped pop end
} bind userdict 3 -1 roll put
|---------------------------------------------------- disconnect
|  node# | --

/_dc {
  dvt begin /knode name
  nodelist knode get /node name
  node 0 get class /nullclass ne { 
    node 2 get disconnect
    null node 0 put false node 3 put 0 node 4 put
    {} node 5 put null node 6 put
    printnode
  } if
  end
} bind userdict 3 -1 roll put

/_dx {
  dvt begin /knode name
  nodelist knode get /node name
  node 0 get class /nullclass ne {
    node 2 get (Xdisconnect) send
    node 2 get disconnect
    null node 0 put false node 3 put 0 node 4 put
    {} node 5 put null node 6 put
    printnode
  } if
  end
} bind userdict 3 -1 roll put


/_kill {
  dvt begin /knode name
  nodelist knode get /node name
  node 0 get class /nullclass ne {
    node 2 get (null vmresize) send
    node 2 get disconnect
        null node 0 put false node 3 put 0 node 4 put
        {} node 5 put null node 6 put
        printnode
      } if
  end    
} bind userdict 3 -1 roll put

|---------------------------------------------------- talk to node
|  target | --
|
|  0  - dvt
| >0  - node#
| <0  - group#

/_t {
  dvt begin
  { /target name
    target 0 ge
     { target nodelist length gt ~stop if
       nodelist target get /node name 
       node 0 get class /nullclass ne
         { target /kbdowner name /knode target def }
         ~stop
         ifelse
     }
     { false 1 1 nodelist length 1 sub { /knode name
          nodelist knode get /node name
          node 0 get class /nullclass ne
            { node 4 get target eq
               { /kbdowner target def pop true } if
            } if
        } for
       not ~stop if
     }
     ifelse
    0 1 nodelist length 1 sub { /knode name
        nodelist knode get /node name
        printnode
      } for
  } stopped { (Think!\n) toconsole } if
  end
} bind userdict 3 -1 roll put

|------------------------ front end support ------------------------

|-------------------------------------- print node info
| If a nodes window exists, the node's entry is updated there (this
| includes showing a blank field left by disconnected nodes);
| otherwise the (existing) connection is printed (requires knode, node)

/pbuf 80 /b array def

/printnode {
  Xwindows
    { drawnode
    }
    { node 0 get class /nullclass ne {
        pbuf 0 -4 knode * number node 0 get fax
        knode 0 ne {
            * node 1 get * number
            node 3 get { ( - busy ) } { (- ready ) } ifelse fax
            * node 4 get * number (\n) fax
         } if
        0 exch getinterval toconsole
      } if
    }
    ifelse
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

|---------------------------------------- setcolor
| Used when color_node is called
| translates [/color...] type list for color.d
| into instructions for the window system to add
| a color code to the node.
|
| [/color_name...] node# | -- <<nodelist->node#->5 is set>> 
|
/setcolor {
  dvt begin colorize begin {/knode name /colorlist name
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
} bind userdict 3 -1 roll put

|---------------------------------------- color_node_def
| Used when _csu2 is called
| Checks for a color setting in nodelist,
| and if non-null, call color_node for that node
|
| <<nodelist->node#->6 is set/null>> node# | --
|
/color_node_def {
  dvt /nodelist get 1 index get 6 get
  dup null eq {pop pop printnode} {exch color_node} ifelse
} bind userdict 3 -1 roll put

/colorize 100 dict dup begin
  /NORMALFONT 
     (-b&h-lucida-medium-r-normal-sans-0-0-75-75-p-0-iso8859-1) def
  /BOLDFONT 
     (-b&h-lucida-bold-r-normal-sans-0-0-75-75-p-0-iso8859-1) def
  /ITALICFONT 
    (-b&h-lucida-medium-i-normal-sans-0-0-75-75-p-0-iso8859-1) def
  /BOLDITALICFONT 
    (-b&h-lucida-bold-i-normal-sans-0-0-75-75-p-0-iso8859-1) def

  /BLACK   <d 0   0   0  > mapcolor def
  /RED     <d 1   0   0  > mapcolor def
  /GREEN   <d 0   1   0  > mapcolor def
  /BLUE    <d 0   0   1  > mapcolor def
  /WHITE   <d 1   1   1  > mapcolor def
  /YELLOW  <d 1   1   0  > mapcolor def
  /MAGENTA <d 1   0.5 0.5> mapcolor def
  /CYAN    <d 0.5 0.5 1  > mapcolor def

  /makecolortext {[NORMALFONT 3 -1 roll -1 0]} bind def
  /BLACKTEXT   BLACK   makecolortext def
  /REDTEXT     RED     makecolortext def
  /GREENTEXT   GREEN   makecolortext def
  /YELLOWTEXT  YELLOW  makecolortext def
  /BLUETEXT    BLUE    makecolortext def
  /MAGENTATEXT MAGENTA makecolortext def
  /CYANTEXT    CYAN    makecolortext def
  /WHITETEXT   WHITE   makecolortext def

  /makefonttext {[exch BLACK -1 0]} bind def
  /BOLDTEXT   BOLDFONT       makefonttext def
  /ITALICTEXT ITALICFONT     makefonttext def
  /FAINTTEXT  BLACKTEXT                   def
  /UNDERTEXT  BLACKTEXT                   def
  /SLOWTEXT   BOLDTEXT                    def
  /RAPIDTEXT  BOLDITALICFONT makefonttext def
  /NEGTEXT    WHITETEXT                   def 

  /red     {/nodeforecolor {( Fr) REDTEXT     ~drawtext} bind def} bind def
  /black   {/nodeforecolor {( Fb) BLACKTEXT   ~drawtext} bind def} bind def
  /green   {/nodeforecolor {( Fg) GREENTEXT   ~drawtext} bind def} bind def
  /yellow  {/nodeforecolor {( Fy) REDTEXT     ~drawtext} bind def} bind def
  /blue    {/nodeforecolor {( Fl) BLUETEXT    ~drawtext} bind def} bind def
  /magenta {/nodeforecolor {( Fm) MAGENTATEXT ~drawtext} bind def} bind def
  /cyan    {/nodeforecolor {( Fc) CYANTEXT    ~drawtext} bind def} bind def
  /white   {/nodeforecolor {( Fw) WHITETEXT   ~drawtext} bind def} bind def

  /on_red     {/nodebackcolor {( Br) REDTEXT     ~drawtext} bind def} bind def
  /on_black   {/nodebackcolor {( Bb) BLACKTEXT   ~drawtext} bind def} bind def
  /on_green   {/nodebackcolor {( Bg) GREENTEXT   ~drawtext} bind def} bind def
  /on_yellow  {/nodebackcolor {( By) REDTEXT     ~drawtext} bind def} bind def
  /on_blue    {/nodebackcolor {( Bl) BLUETEXT    ~drawtext} bind def} bind def
  /on_magenta {/nodebackcolor {( Bm) MAGENTATEXT ~drawtext} bind def} bind def
  /on_cyan    {/nodebackcolor {( Bc) CYANTEXT    ~drawtext} bind def} bind def
  /on_white   {/nodebackcolor {( Bw) WHITETEXT   ~drawtext} bind def} bind def

  /bold        {/nodebold   {( Sb) BOLDTEXT   ~drawtext} bind def} bind def
  /italic      {/nodeitalic {( Si) ITALICTEXT ~drawtext} bind def} bind def
  /faint       {/nodefaint  {( Sf) FAINTTEXT  ~drawtext} bind def} bind def
  /underlined  {/nodeul     {( S_) UNDERTEXT  ~drawtext} bind def} bind def
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
  } def
end def


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
/NORMALFONT 
    (-b&h-lucida-medium-r-normal-sans-0-0-75-75-p-0-iso8859-1) def
/BOLDFONT 
    (-b&h-lucida-bold-r-normal-sans-0-0-75-75-p-0-iso8859-1) def

/BLACK <d 0 0 0 >      mapcolor def
/GRAY  <d 0.2 0.2 0.2> mapcolor def
/BLUE  <d 0 0 1 >      mapcolor def
/RED   <d 1 0 0 >      mapcolor def
/LBLUE <d 0.1 0.1 0.9> mapcolor def

/BG <d 235 243 248 >  255 div mapcolor def
/HBG <d 166 219 160 > 255 div mapcolor def

/NORMALTEXT   [NORMALFONT BLACK -1 0] def
/HIGHTEXT     [BOLDFONT   BLUE  -1 0] def

|--------------------------------------------- resist resizing

/windowsize {
  wH ne exch wW ne or {
    { [
      wid wW wH resizewindow
    } stopped cleartomark
  } if end
} bind def

|--------------------------------------------- draw cluster window

/drawwindow {
{ [ busy { stop } if     | stop capsule + reentry prevention
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
     node 3 get { HBG } { BG } ifelse fillrectangle
   node 0 get class /nullclass ne {
     wid nodelocs knode get exec
     pbuf 0 node 0 get fax
     knode 0 ne {
       (:) fax * node 1 get * number
     } if 
     0 exch getinterval
     kbdowner 0 ge {knode} {node 4 get} ifelse
     kbdowner eq {HIGHTEXT} {NORMALTEXT} ifelse
     drawtext node 5 get exec pop pop pop
   } if
} bind def

|------------------------------------------------- mouseclick
| - a simple mouse click selects a node

|-- mouse key combos
/plain1 {
  mB 1 eq mM 0 eq and
} bind def

/shift1_plain2 {
  mB 1 eq mM 1 eq and
  mB 2 eq mM 0 eq and or
} bind def

/ctrl1_plain3 {
  mB 1 eq mM 4 eq and
  mB 3 eq mM 0 eq and or
} bind def

/mouseclick { 
    { [ 4 1 roll busy { stop } if  | stopped and reentry lock
      /busy true def
      dup -16 bitshift /mB name 255 and /mM name
      /mY name /mX name 
      /knode mY 1 sub 13 div def
      nodelist knode get /node name
      node 0 get class /nullclass eq { stop } if
      plain1 { /kbdowner knode def c_ stop } if
      shift1_plain2 { false nodelist knode get 3 put c_ stop } if
      ctrl1_plain3 { node 4 get _t stop } if
    } stopped cleartomark /busy false def
  end 
} bind def

end userdict /dvt put

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
|               'return' to execute the phrase
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

{ begin
  { Xwindows not ~stop if
    screensize /scrH name /scrW name
    macros /rowH get /rowH name
    /nkeys 0 def /nrows 1 def
    [ [ macros /pass0 get begin keywords end ] ] /rowlist name
    commands length nkeys ne
      { (Macros: keys do not match commands!\n) toconsole stop } if
    /wW scrW 3 div def /wH nrows rowH mul 6 add def
    [ [ 2 scrH wH sub 2 sub wW wH ]
      myname myshortname makewindow /wid name pop
    /woutline [ 0 0 wW 1 sub 0 wW 1 sub wH 1 sub 0 wH 1 sub 0 0 ] def
    /wpane [ 1 1 wW 2 sub wH 2 sub ] def
    /line 4 /l array def
    macros /windowsize get /windowsize name
    macros /drawwindow get /drawwindow name
    macros /mouseclick get /mouseclick name
    macros /checkcolor get /checkcolor name
    macros /outcolor   get /outcolor   name      
    macros /BLACK get /BLACK name
    macros /GRAY get /GRAY name
    macros /BG get /BG name
    macros /TEXT get /TEXT name
    /newmacros true def
    currentdict userdict debug_dict /line get 0 (/w) fax * wid * number
      0 exch getinterval mkact exec put
    wid true mapwindow
  } stopped pop end
} userdict /makemacros put 

   
|---------------------------- macros ----------------------------------

100 dict dup begin

/NORMALFONT 
    (-b&h-lucida-medium-r-normal-sans-0-0-75-75-p-0-iso8859-1) def
/BOLDFONT 
    (-b&h-lucida-bold-r-normal-sans-0-0-75-75-p-0-iso8859-1) def
/BLACK <d 0 0 0 > mapcolor def
/GRAY  <d 0.5 0.5 0.5 > mapcolor def
/BLUE  <d 0 0 1 > mapcolor def
/RED   <d 1 0 0 > mapcolor def
/BG <d 235 243 248 > 255 div mapcolor def
/TEXT [ BOLDFONT BLACK -1 -1 ] def
/rowH 20 def

|------------------ resist resizing of a macro window

/windowsize {
  wH ne exch wW ne or {
    { [
      wid wW wH resizewindow
    } stopped cleartomark
  } if end
} bind def

|------------------ draw a macro window

/drawwindow {
  { [ 
    wid woutline BLACK drawline
    wid wpane BG fillrectangle
    newmacros { [ [ } if
    rowH 1 sub dup line 1 put line 3 put
    /x 5 def /y rowH 2 sub def
    macros /pass1 get begin keywords end
    newmacros { ] ] /boxlist name } if
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
  
/mouseclick { 
    { [ 4 1 roll
      /mM name /mY name /mX name
      /krow mY 1 sub rowH div def
      /kbox 0 def
      checkcolor
      false boxlist krow get { /box name
           mX box 0 get ge mX box 1 get le and
             { pop true exit }
             { /kbox kbox 1 add def }
             ifelse
         } forall
      { rowlist krow get kbox get toconsole
      } if
    } stopped cleartomark
  end 
} bind def

|------------------ pass0: count keywords, rows for window layout

4 dict dup begin
/NL  { ] [ /nrows nrows 1 add def } bind def
/PRE { pop } bind def
/KEY { pop commands nkeys get /nkeys nkeys 1 add def } bind def
/GAP { pop } bind def
end mkread /pass0 name

|------------------ pass1: render (and measure) text and underlines;
|                          a box gives the left and right x of the
|                          keyword text
4 dict dup begin
/NL  { ul { /ul false def x line 2 put
            wid line GRAY drawline
          } if
       line 1 get rowH add dup line 1 put line 3 put
       /x 5 def /y y rowH add def
       newmacros { ] [ } if
     } bind def
/PRE { /s name x line 0 put /ul true def
       wid x y s TEXT drawtext pop /x name pop
     } bind def
/KEY { /s name
       /xl x def
       wid x y s TEXT drawtext pop /x name pop
       newmacros { /box 2 /l array def
                   xl box 0 put x box 1 put
                   box
                 } if
     } bind def
/GAP { ul { /ul false def x line 2 put
            wid line GRAY drawline
          } if
       { wid x y ( ) TEXT drawtext pop /x name pop } repeat
     } bind def
end mkread /pass1 name

end userdict /macros put

|================= debug abort ==================
| active_object -> ??
| wraps the object in an abort, and puts
| opstack in userdict->[d_opstack]
| dictstack in userdict->[d_dictstack]
| execstack in userdict->[d_execstack]
| in case of an abort
| call s_debug_abort to do this without wrapping debug_aborted
| and e_debug_abort to end that regime

/regular_abort /abort find def
/debug_abort_c false def

/s_debug_abort {
  true userdict /debug_abort_c put
  /debug_abort find userdict /abort put
} def

/e_debug_abort {
  false userdict /debug_abort_c put
  /regular_abort find userdict /abort put
} def

|--------------------------------------------- dstate_
| get current stacks state (see it in the eye)
/dstate_ {
  countexecstack list execstack dup length 1 sub 0 exch getinterval
    userdict /d_execstack put

  [count 1 ne {count 1 roll} if]
    userdict /d_opstack put
    
  countdictstack list dictstack dup length 2 sub 2 exch getinterval
    userdict /d_dictstack put
} bind def

|-------------------- debug_abort
| calls dstate_ to get debug info
| fixes abort to normal
| and continues aborting
/debug_abort {
  debug_abort_c not {/regular_abort find userdict /abort put} if
  dstate_
  abort
} bind def

|-------------------------------- debug_aborted
| version of aborted which sets abort to debug_abort
| and undoes it if no abort occurs
| -- debug_abort undoes itself when called
/debug_aborted { | {} --> ???
  /debug_abort find userdict /abort put
  
  aborted {(abort\n) toconsole abort} {
    debug_abort_c not {/regular_abort find userdict /abort put} if
  } ifelse
} bind def

|----------------------------------------- color_node
| set the default text color for a node
|
| [/color_name...] node# | --- <<changed text color>>
|
/color_send [ null (make_toconsole) ] def
/color_node {
  2 copy setcolor
  exch color_send 0 put
  dvt begin nodelist exch get 2 get end color_send send
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

|----------------------------- start the dvt ------------------------------
| A 'save' representing a clean dvt is associated with the name cleanDVT in
| userdict.

(dvt) userdict /myid put
dvt begin
save /cleanDVT name
/kbdowner 0 def
Xwindows {
  startupdir (/theeye.d) fromfiles
  startupdir (/dvt_macros.d) fromfiles
  screensize /scrH name /scrW name
  [ [ scrW wW sub 10 sub scrH wH sub 10 sub wW wH ]
    (TheHorses) (Horses) makewindow /wid name pop
  dvt userdict debug_dict /line get 0 (/w) fax * wid * number
      0 exch getinterval mkact exec put
  /busy false def
  wid true mapwindow  
} if
supervisor   | we never return
