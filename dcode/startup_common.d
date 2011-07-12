| -*- mode: d; -*-

|======================== userdict ===================================

/abort {dstate_ abort} bind def

2 list dictstack dup 0 get /systemdict name   | name the roots
                     1 get /userdict   name

/false 0 1 eq def                             | boolean prototypes
/true  0 0 eq def

save /startup_in_save name
/startup_in_buf vmstatus sub 10 div /b array def
startup_in_save capsave {
  getstartupdir (startup_common_in.d) startup_in_buf readfile mkact exec
} stopped startup_in_save restore {
  1024 /b array 0
  (Unable to load: ) fax
  getstartupdir fax (startup_common_in.d\n) fax
  0 exch getinterval toconsole
  stop
} if

|================================= block binding ======================
| We want to make toconsole, error, quit and die late-binding 
| even if a procedure is defined with bind, 
| so that redefines always work.
|
{
  {/toconsole /toconsole_base}
  {/error /error_base}
  {/die /die_base}
  {/quit /quit_base}
} {exec
  systemdict 2 index known not {pop pop} {
    2 copy ~[3 -1 roll mkact] bind def | /x_base ~[~x] bind def
    mkact def                          | /x ~x_base def
  } ifelse
} forall

|========================== warning ===============================
| ~active | --
|
| ~active: buffer index | buffer index+fill_length
|
| convert a string into a red warning string.
| ~active just fills a buffer and updates the index to the end.
| 
/warning_buffer 1024 /b array def
/warning ~[
  {
    /warning_func name
    loadcolor
    warning_buffer {
      {/red} {
        (Warning: ) fax
        warning_func
        (\n) fax
      } color_text
    } tostring
  } bind userdict ~indict ~toconsole_base
] def

|================================ makefont ===========================
| ~font-spec-getter [null col_idx h_align v_align] | ~drawtextproc
| 
| drawtextproc: -- | [(font-spec) col_idx h_align v_align]
|
| creates a procedure that gives the top operand for drawtext.
| ~font-spec-getter is a procedure that returns a font-spec string
|   at the time that the ~drawtextproc is called,
| col_idx is a color obtained from mapcolor,
| h_align and v_align are integers that define the alignment of the
|  text, as defined for drawtext in dm9.c
|
| This little function is used to late-bind a font to a font-spec,
|  to allow redefining the font-spec for a font until after all
|  the files (particularly .dvt) are loaded.
|
/makefont {
    ~[exch 3 -1 roll 1 ~index 0 ~put] bind
} bind def


|====================================== dictionary builders
|
|------------- makeenum -----------------
| [/name|num...] | dict == /name0 num, /name1 num+1 ...
|
| Creates a dictionary that represents an enumerated type
| The names in the dictionary will represent integers,
| which start from 0 to n. If, instead of a name, an integer
| is in the list, the current intenger will be replaced with
| that value. For ex:
| [/a /b 5 /c /d] makeenum 
| will create a dict with the elements: a=0, b=1, c=5, d=6
|
| Dict is read only.
|
/makeenum {
  dup length dict dup begin
  0 3 -1 roll {
    dup class /numclass eq {exch pop} {
      1 index def
      1 add
    } ifelse
  } forall pop
  end mkread
} bind def

|------------------ makestruct ----------------
| [/name val /name2 val2 ...] | dict == /name val, /name2 val2 ...
|
| Creates a dictionary with exactly the size to fit every name
| in the list, with the values from the list
|
| So: {/a 1 /b {doit} /c 1e-9} makestruct
|  returns a dictionary 3 long, with a=1, b={doit}, c=1e-9
|
/makestruct {
  dup length dup 2 div dict dup begin {3 1 roll| dict [/name val ...] length
    0 2 3 -1 roll 1 sub {                      | dict [/name val ...] i
      1 index exch 2 getinterval {} forall def | dict [/name val ...]
    } for
  } stopped end ~stop if
  pop
} bind def

|------------------ makestruct_close ----------------
| \[ /name val /name2 val2 ... | dict
|
| Like makestruct, except the list isn't closed and the
| memory for making the list is returned.
|
/makestruct_close {
  save                                           | [/name val... save     |]
  counttomark 1 add 1 roll closelist ~makestruct | save [/name val..] ~mk
  [ 4 -1 roll dup capsave ~stopped push |]       | dict stopped save
  restore                                        | dict stopped
  ~stop if                                       | dict
} bind def

|---------------- makestruct_stack ----------------
| n1 ... nn \[ /n1 .. /nn | dict == /n1 n1 .. /nn nn
|
| Creates a dictionary with exactly the size to fit every name
| on the stack after the mark, with the values from the stack
| before the mark.
|
| So: 1 {doit} 1e-9 \[ /a /b /c makestruct_stack
|  returns a dictionary 3 long, with a=1, b={doit}, c=1e-9
|
/makestruct_stack {
  counttomark dup dict {
    3 add {dup 3 eq ~exit if
      exch 1 index -1 roll def
      1 sub
    } loop pop pop
    currentdict
  } exch indict
} bind def

|---------------- makestruct_name ----------------
| \[ /n1 .. /nn | dict == /n1 null .. /nn null
|
| Creates a dictionary with exactly the size to fit every name
| on the stack after the mark, with null values
|
| So: \[ /a /b /c makestruct_stack
|  returns a dictionary 3 long, with a=null, b=null, c=null
|
/makestruct_name {
  counttomark dup dict {
    {null def} repeat pop
    currentdict
  } exch indict
} bind def

|===================== save encapsulations =====================

|----------------------- incap -----------------------------
| ~active | ... save
|
| exec ~active in a save environment, cap it and return it
|
/incap {
  openlist save ~stopped push | ... stop save
  exch {restore stop} if      | ... save
  dup capsave                 | ... save
} bind def

|--------------------- insave -------------------------------------
| ~active | ...
|
| exec ~active in a save environment, then restore it after exec
|
/insave {
  openlist save ~stopped push | ... stop save
  restore ~stop if            | ...
} bind def

|----------------------- incapsave ----------------------------------
|
| ~active-cap ~active | ...
|
| exec ~active-cap in a save, cap the save, execute ~active
|  then restore the save.
|
/incapsave {
  ~incap openlist 3 -1 roll mkpass ~stopped push |   ... save false /active
                                                 | / ...      true  /active
  exch {pop stop} if                             | ... save /active
  mkact openlist 3 -1 roll ~stopped push         | ... stop save
  restore ~stop if                               | ...
} bind def

|-------------- caplocal ----------------------------
| n1 ... nn-x ~names ~active | ...
| ~names: n1 .. nn-x | n1 .. nn [/n1 .. /nn |]
|
| in a save context, executes ~names, then creates
| from the operand stack a dictionary with the names /n1 .. /nn
| defined as n1 ... nn.
|
| Caps the save, and executes active with the dictionary as currentdict.
| All is done in a stopped context. Afterwards, the save
| is restored, and stop propagated if necessary.
|
| So: 1 2 3 {1 dict exch [/a /b /c /d]} {a _ b 0 2 /d array copy} caplocal
|  prints 1, and leaves 1 2 <d 0 0> on the stack. 
|  /d is equal 3 and /c is a dictionary which is removed from memory
|  afterwards.
|
/caplocal {
  {openlist exch mkpass {exec makestruct_stack} push} 
  {mkact exch indict}
  incapsave
} bind def

|---------------- caplocalfunc -----------------------------
| ~names ~active | ~caplocalfunc
|
| returns a new procedure: {~name ~active caplocalfunc}
|
/caplocalfunc {
  ~[3 -1 roll destruct_exec 3 -1 roll destruct_exec ~caplocal]
} bind def

|--------------- layerlocal -------------------------------
| n1 .. nn-x /layer ~names ~active | ...
| ~names: n1 .. nn-x | n1 .. nn [n1 .. nn |]
|
| like caplocal, except it creates a layer for the entire
| ~active procedure with name /layer, instead of a save-cap-restore
| sequence
|
| So: 1 2 3 /x {2 /d array exch [/a /b /c /d]} {a _ b 0 c copy} local
|  prints 1, and leaves 1 2 <d 0 0> on the stack
|  with a layer named /x created, where the array is inside the layer
|
/layerlocal {
  3 -1 roll {
    openlist exch mkpass {exec makestruct_stack} push
    mkact exch indict
  } layerdef
} bind def

|--------------------- localfunc -----------------------
| /name ~names ~active | /name ~localfunc
|
| returns a new procedure: {/name_l ~names ~active layerlocal}
|
/layerlocalfunc_ /NAMEBYTES get_compile /b array def
/layerlocalfunc {
  layerlocalfunc_ 0 * 5 index mkact text (_l) fax 0 exch getinterval
  token pop exch pop mkpass
  ~[exch 4 -1 roll destruct_exec 4 -1 roll destruct_exec ~layerlocal]
} bind def

|-------------- local ----------------------------
| n1 ... nn-x ~names ~active | ...
| ~names: n1 .. nn-x | n1 .. nn [/n1 .. /nn |]
|
| in a save context, executes ~names, then creates
| from the operand stack a dictionary with the names /n1 .. /nn
| defined as n1 ... nn.
|
| Executes active with the dictionary as currentdict.
| All is done in a stopped context. Afterwards, the save
| is restored, and stop propagated if necessary.
|
| So: 1 2 3 {1 dict exch [/a /b /c /d]} {a _ b 0 2 /d array copy} caplocal
|  prints 1, and leaves 1 2 on the stack; <d 0 0> is 'restore'd off the stack. 
|  /d is equal 3 and /c is a dictionary which is removed from memory
|  afterwards.
|
/local {
  {
    openlist exch mkpass {exec makestruct_stack} push
    mkact exch indict
  } insave
} bind def

|-------------- localfunc -----------------------
| ~names ~active | {~names ~active local}
|
| Creates a new wrapper procedure.
|
/localfunc {
  ~[3 -1 roll destruct_exec 3 -1 roll destruct_exec ~local]
} bind def

|---------------- currentdef ---------------------------
| /name ~active dict | --
|
| defines /name in dict with a procedure
| that executes active in currentdict
|
/currentdef {
  ~[3 -1 roll destruct_exec currentdict ~indict]
  exch 3 -1 roll put
} bind def

|----------------- userdef --------------------------
| /name ~active | --
|
| defines /name in userdict with a procedure
| that executes active in currentdict
|
/userdef {
  userdict currentdef
} bind def

|================ makelist =======================
| ~store | dict
| 
| See linkedlist.d for details
| store can be ~dynamic, ~static or ~linked
|  (with approprate arguments on stack)
|
/makelist {
  {exec new} LINKEDLIST indict
} bind def

|================ inlist =========================
| ~active linked-list | ...
| execute ~active with linked-list and LINKEDLIST 
|  on dictionary stack
/inlist {
  ~indict LINKEDLIST indict
} bind def

|===================================== executable wrappers
|
|------------- construct_exec ------------------
| anything | anything or {proc} ~exec
|
| takes an object, and wraps it up for use in a 
|  on-the-fly procedure so that it will get executed
|  in that procedure
|
/construct_exec {
  dup active {
    dup class /listclass eq {~exec} if
  } if
} bind def

|-------------- destruct_exec ------------------
| anything | anything or {~active}
|
| takes an object, and wraps it up for use in a
|  on-the-fly procedure so that it will ||not|| get
|  executed in that procedure, but left on the stack.
|
/destruct_exec {
  dup active {
    dup class /listclass ne {~[exch]} if
  } if
} bind def

|------------- construct_execn -----------------
| /name-for-anything | anything or {proc} ~exec
|
| take a name, finds it and then wraps it up for
|  use in an on-the-fly procedure so that it will
|  be executed in that procedure
|
/construct_execn {find construct_exec} bind def

|-------------- destruct_execn
| /name-for-anything | anything or {~active}
|
| takes a name, finds it and then wraps it up for
|  use in an on-the-fly procedure so that it will
|  ||not|| be executed in that procedure, but
|  left on the stack
|
/destruct_execn {find destruct_exec} bind def

|=================================== indict convenience
|
|----------------- indict -----------------
| ~exec dict | ...
|
| executes ~exec in dictionary dict
|
/indict {begin stopped end ~stop if} bind def

|----------------- underdict -----------------
| ~exec dict | ...
|
| executes ~exec in current dictionary
| with dict directly underneath
|
/underdict {
  currentdict end exch begin begin | ~exec 
  stopped                          | ... true/false
  currentdict end end begin        | ... true/false
  ~stop if                         | ...
} bind def

|----------------- swapdict -----------------
| ~exec | ...
|
| executes ~exec with the top two dicts swapped
|
/swapdict {
  currentdict end currentdict end | ~exec top next
  exch begin begin                | ~exec
  stopped                         | ... true/false
  currentdict end currentdict end | ... true/false next top
  exch begin begin                | ... true/false
  ~stop if                        | ...
} bind def

|----------------- notindict -----------------
| ~exec dict | ...
|
| executes ~exec without the sequence
| of top dicts equal to dict temporarily removed.
|
/notindict {
  0 {
    1 index currentdict ne ~exit if
    end 1 add
  } loop
  [3 1 roll exch ~stopped push|]
  {dup begin} repeat pop
  ~stop if
} bind def

|------------------- enddict ------------
| ~exec | ...
|
| execute ~exec with currentdict end'ed
|
/enddict {
  [currentdict end ~stopped push|] ... true/false currentdict
  begin ~stop if
} bind def

|------------------- enddicts -----------
| ~active | ...
|
| executes ~active with all dicts above
| systemdict and userdict temporarily ended.
| On return, dictstack is returned to original
| state. Error is reported if any extra dicts
| are left on stack.
|
/enddicts {
  [
    {
      countdictstack 2 ne {(enddicts) /RNG_CHK makeerror} if
      ~begin repeat
    }
    countdictstack 2 sub dup 0 ne {
      currentdict end
      2 1 3 index {
        currentdict end exch 1 roll
      } for
    } if
    counttomark 2 add -1 roll push |]
} bind def

|------------------ tostring -------------
| (string-buf) ~active | (sub-string-buf)
| active: (string-buf) index | (string-buf) index
|
| Wraps up common idiom of:
|   buffer 0 .... 0 exch getinterval
|
/tostring {
  0 exch exec 0 exch getinterval
} bind def

|============================================ SIGNALS
|
| these must be in the same order as sigmap in dm-signals.c
| for the use of sendsig, rsendsig.
|
/SIGNALS {
  /QUIT
  /KILL
  /TERM
  /HUP
  /INT
  /ALRM
  /FPE
  /ABRT
  /BUS
  /CHLD
  /CONT
  /ILL
  /PIPE
  /SEGV
  /STOP
  /TSTP
  /TTIN
  /TTOU
  /USR1
  /USR2
  /POLL
  /PROF
  /SYS
  /TRAP
  /URG
  /VTALRM
  /XCPU
  /XFSZ
} makeenum def

|------------ signal ---------------
| socket /SIGNAL | --
|
| send signal to a node by name
|
/signal ~[SIGNALS ~exch ~get ~sendsig] bind def

|------------- rsignal ---------------
| /SIGNAL | --
|
| send signal to all pawns by name (only if you have pawns!)
|
/rsignal ~[SIGNALS ~exch ~get ~rsendsig] bind def

|============================================ PERMS
|
| file mask permission bits & functions around
| umask.
| The perm bit flags in PERMS are {USER,GROUP,OTHER}_{R,W,X}
| as per posix standard (OTHER_EXECUTE = 1, OTHER_WRITE = 2, ...).
|
/PERMS [
  0 1 {
    /OTHER_X /OTHER_W /OTHER_R
    /GROUP_X /GROUP_W /GROUP_R
    /USER_X  /USER_W  /USER_R 
  } {
    3 1 roll dup 3 1 roll
    exch 1 index or exch
    1 bitshift
  } forall pop
  /ALL exch
] makestruct def

|--------------------- _setfilemask -------------------
| \[ /PERM_NAME... | \[ old-umask
|
| Internal: takes PERM names and sets the umask to 
| not or(perms...). Returns previous umask.
|
/_setfilemask {
  0 counttomark 1 sub {PERMS 3 -1 roll get or} repeat not
  PERMS /ALL get and
  umask
} bind def

|---------------------- setfilemask ---------------------
| \[ /PERM_NAME... | --
|
| Sets the file mask to the union of the bits from PERM by /PERM_NAME.
| Aka, umask = not or(perms).
|
/setfilemask {_setfilemask pop pop} bind def

|----------------------- filemask --------------------------
| [ /PERM_NAME.. | [ /PERM_NAME...
|
| Like setfilemask, except it returns the mask permission names.
|
/filemask {
  _setfilemask not PERMS {
    1 index /ALL eq {pop pop} {
      2 index and 0 eq ~pop ~exch ifelse
    } ifelse
  } forall pop
} bind def

|--------------------- getfilemask ----------------------------
| -- | [ /PERM_NAME....
|
| Gets the current permission names for use in setfilemask.
| So: getfilemask setfilemask does nothing at all.
|
/getfilemask {
  {
    openlist filemask
    counttomark 1 add copy setfilemask
  } lock
} bind def

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

/line /NAMEBYTES get_compile 2 mul 20 add /b array def

/nulltypes 3 dict dup begin
  /T {(:socket=) fax * object socketval * number} def
  /P {(:pid=) fax * object unpid * number} def
  /N {} def
end mkread def

/oclasses 12 dict dup begin                      | object
   /nullclass  {
     /object find active {(~) fax} if (null) fax
     nulltypes /object find type get exec
   } bind def
   /numclass   { * object * number } bind def
   /opclass    { * (op: ) text * /object find text } bind def
   /nameclass  { 
     /object find active not { * (/) text } if
     * /object find text 
   } bind def
   /arrayclass { 
     * (<) text  * /object find type text * ( .. > of ) text
     * /object find length * number 
   } bind def
   /listclass  { 
     * /object find active
     { ({ .. } of ) } { ([ .. ] of ) } ifelse text
     * /object find length * number 
   } bind def
   /dictclass  { 
     * (dict of ) text
     * object length * number * ( max and ) text
     * object used * number * ( used) text 
   } bind def
   /markclass  { * ([) text } bind def
   /boolclass  { * object {(true)} {(false)} ifelse text } bind def
   /boxclass   { 
     * (box of ) text
     * object length * number * ( bytes) text 
   } bind def
   /streamclass { 
     * (stream: ) text
     object closedfd {* (closed) text} {
       * (open=) text * object unmakefd * number
     } ifelse
     * (, ro=) text * object readonlyfd {(t)} {(f)} ifelse text
     object used 1 eq {* (, bf) text} if
   } bind def
end mkread def

/vclasses 12 dict dup begin                  | value
   /nullclass  /_ mkact def
   /handleclass ~_ def
   /numclass   /_ mkact def
   /opclass    /_ mkact def
   /nameclass  /_ mkact def
   /arrayclass { intuples } def
   /listclass  { { _ pop } forall } bind def
   /dictclass  { { exch
                   line 0
                   /NAMEBYTES get_compile neg 4 add 4 -1 roll text 
                   0 exch getinterval toconsole showobj pop
                 } forall
               } bind def 
   /markclass  /_ mkact def
   /boolclass  /_ mkact def
   /boxclass   /_ mkact def
   /streamclass /_ mkact def
end mkread def

/showobj { dup /object name
   /object find readonly { (r ) } { (  ) } ifelse toconsole
   line 0 /object find oclasses begin class mkact exec end
   * (\n) text 0 exch getinterval toconsole
} bind def

/tuples 6 dict dup begin
   /B 10 def
   /W 10 def
   /L 5 def
   /X 2 def
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
|
| active handling isn't quite right. It needs to know whether it's in
| or out of a procedure.

/xtext  {~totext xtext_dict ~indict xtext_d_bnum  indict} bind def
/xtexts {~totext xtext_dict ~indict xtext_d_blit  indict} bind def
/pstext {~totext xtext_dict ~indict xtext_ps_blit indict} bind def

/xtext_d_bnum 3 dict dup begin
  /dprec 15 def
  /arrayclass ~d_bnum def
  /act (mkact) def
end mkread def

/xtext_d_blit 3 dict dup begin
  /dprec 15 def
  /arrayclass ~d_blit def
  /act (mkact) def
end mkread def

/xtext_ps_blit 3 dict dup begin
  /dprec 6 def
  /arrayclass ~ps_blit def
  /act (cvx) def
end mkread  def

/xtext_dict 40 dict dup begin
 
/inword {dup class mkact exec} bind def

/newline {
  * (\n) text
  indents () text
  /colleft 75 indents sub def
} bind def

/indent {indents add /indents name} bind def

/ftext {/chunk name
  colleft chunk length 1 add sub /colleft name colleft 0 lt {
    newline * chunk text /colleft colleft chunk length sub def
  } {
    * ( ) text * chunk text
  } ifelse
} bind def

/objstr /NAMEBYTES get_compile 2 mul /b array def

/nullclass {/obj name
  (null) ftext
  /obj find active {act ftext} if
} bind def
/numclass {dup type mkact exec} bind def
/opclass {
  objstr 0 * 4 -1 roll text 0 exch getinterval ftext
} bind def
/nameclass {/obj name
  objstr 0
    /obj find active not {(/) fax} if
    * /obj find text
  0 exch getinterval ftext
  /obj find tilde {act ftext} if
} bind def

| arrayclass is alternately associated with:

/d_bnum {
  d_bnum 1 index type get exec
} bind def

/d_bnum 6 dict dup begin
   /B ~_arrayclass def
   /W {mkpass _arrayclass} def
   /L {mkpass _arrayclass} def
   /X {mkpass _arrayclass} def
   /S {mkpass _arrayclass} def
   /D {mkpass _arrayclass} def
end mkread def

/d_blit {
  d_blit_dict 1 index type get exec
} bind def

/d_blit_dict 6 dict dup begin
   /B ~_stringclass def
   /W {mkpass _arrayclass} def
   /L {mkpass _arrayclass} def
   /X {mkpass _arrayclass} def
   /S {mkpass _arrayclass} def
   /D {mkpass _arrayclass} def
end mkread def

/ps_blit {
  ps_blit_dict 1 index type get exec
} bind def

/ps_blit_dict 6 dict dup begin
   /B ~_stringclass def
   /W {mkpass listclass} def
   /L {mkpass listclass} def
   /X {mkpass listclass} def
   /S {mkpass listclass} def
   /D {mkpass listclass} def
end mkread def

/listclass {
  dup /obj name active {
    newline ({)
      ftext 2 indent
      /obj find ~inword forall
      -2 indent
    (}) ftext
  } {
    newline ([)
      ftext 2 indent
      obj ~inword forall
      -2 indent
    (]) ftext
  } ifelse
} bind def

/dictclass  {mkpass /obj name
  newline
  obj length
  objstr 0 * 4 -1 roll * number 0 exch getinterval
  ftext (dict dup begin) ftext
  2 indent
  obj {
    4 -2 roll newline
    4 -1 roll inword 3 -1 roll inword (def) ftext
  } forall
  -2 indent (end) ftext
} bind def

/boxclass    {pop (null) ftext} bind def | discard a box object
/markclass   {/obj name
  ([) ftext
  /obj find tilde {(mktilde) ftext} if
} bind def
/streamclass {pop (null) ftext} bind def
/boolclass   {
  {(true)} {(false)} ifelse ftext
} bind def

/_stringclass {/obj name
  newline
  (\() fax /obj find fax (\)) fax
  /obj find active {newline act ftext} if
} bind def

/_arrayclass {/obj name
  newline
  objstr 0
    (<) fax * /obj find type text
  0 exch getinterval ftext
  3 indent
  obj {dup type mkact exec} forall
  -3 indent
  (>) ftext
} bind def

/B {objstr 0 4 4 -1 roll * number 0 exch getinterval ftext} bind def
/W {objstr 0 6 4 -1 roll * number 0 exch getinterval ftext} bind def
/L {objstr 0 11 4 -1 roll * number 0 exch getinterval ftext} bind def
/X {objstr 0 21 4 -1 roll * number 0 exch getinterval ftext} bind def
/S {objstr 0 13 4 -1 roll 6 number 0 exch getinterval ftext} bind def
/D {
  objstr 0 dprec 8 add 4 -1 roll dprec number
  0 exch getinterval ftext
} bind def

/totext {/obj name
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
  save /tofilessave name { 
    vmstatus sub 5 div 4 mul /b array tofilessave capsave
    0 3 -1 roll exec
    0 exch getinterval 3 1 roll writefile
  } stopped tofilessave restore ~stop if
} bind def

| 'fromfiles' performs the converse of 'tofiles', by reading a text file
| into a transient string object and executing that string.
| use: dirname filename | objects..  (and/or side effects)

/fromfiles_dict {
  /fd {  | 0 is read-only, 438 is 0666 (rw-rw-rw-)
    save {
      3 1 roll 0 438 openfd ~suckfd stopped {closefd stop} if
      exch capsave mkact exec
    } [2 index ~stopped push | ]
    restore ~stop if
  }

  | override fromfiles -- we need the old, simple version 
  | since we don't have fd handling.
  /read {
    save /fromfilessave name {
      vmstatus sub 3 div /b array fromfilessave capsave
      readfile mkact exec
    } stopped fromfilessave restore ~stop if
  }

  /dgen /read
  /dnode /fd
  /dvt /fd
  /dpawn /read
} bind makestruct def

/fromfiles fromfiles_dict dup dm_type get get def

| fromxfiles does the same as fromfiles, but first checks that the file
| exists.

/FTYPEMASK 61440L def
/DIRTYPE 16384L def
/FUSERREAD 256 def

| (dir) (file) | bool
/fileisdir {
  findfile not {(fileisdir) /FILE_NOSUCH makeerror} if
  3 1 roll pop pop FTYPEMASK and DIRTYPE eq
} bind def

| (dir) (file) | bool
/fileexists {
  findfile {pop pop pop true} ~false ifelse
} bind def

| dirname filename | 
|   if file exists: objects.. true
|   else:           false
/fromxfiles {
  2 copy findfile not {pop pop false} {
    3 1 roll pop pop
    dup FTYPEMASK and DIRTYPE eq {pop pop pop false} {
      FUSERREAD and 0 eq {pop pop false} {fromfiles true} ifelse
    } ifelse
  } ifelse
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

/forgetmodule {                               | /name
  userdict exch 2 copy known not {pop pop} {  | userdict /name
    get dup class /dictclass eq not ~pop {    | dict
      dup {                                   | dict /n v
        dup class /boxclass eq                | dict /n v b
        3 -1 roll /mySave   ne and            | dict v b
        ~restore ~pop ifelse                  | dict
      } forall                                | dict
      /mySave get dup class /boxclass eq      | val b
      ~restore ~pop ifelse                    | --
    } ifelse
  } ifelse
} bind def

|---------------------------- module
| /module_name | /module_name savebox
|
| discards an existing former version of 'module_name', performs a 'save'
| operation.

/module {dup forgetmodule save} bind def

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

|-------------------------- moduledef
|
| /module_name size ~active | --
|  size is the size of module_dict,
|    which is created and begin'd
|  active fills in module_dict

/moduledef {
  3 -1 roll module 4 2 roll 
  exch dict dup begin exch exec end
  _module
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
      dup find dup class /boxclass eq ~restore ~pop ifelse
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

|-------------------------- inlayer
| ~active /layer_name | ...
|
| encapsulates the common idiom of /x layer {...} stopped /x _layer ~stop if
|  which then becomes {...} /x inlayer
|  ... is whatever active leaves behind.
|  propagates stops.
|
/inlayer {
  dup layer [ exch ~stopped push |]
  _layer ~stop if
} bind def

|-------------------------- layerdef
| /layer_name ~active | ...
| Just reverse inlayer.
/layerdef {exch inlayer} bind def

|-------------------------- caplayer
| ~capped ~body /layer_name | ...
|
| executes ~capped with a layer /layer_name,
|  caps the layer, and then executes body,
|  restoring the layer if body is stopped
|
/caplayer {
  dup layer ~[
    4 -1 roll construct_exec
    counttomark 1 add index ~find ~capsave
    counttomark 3 add -1 roll construct_exec
  ] [3 -1 roll ~stopped push |]
  exch {find restore stop} ~pop ifelse
} bind def

|-------------------------- caplayerdef
| /layer_name ~capped ~body | ...
| Just calls caplayer with layer name rolled
/caplayerdef {3 -1 roll caplayer} bind def

|-------------------------- exitdef
| /label ~active | ...
| Just calls label with /name exch'd
/exitdef {exch exitlabel} bind def

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
  userdict 3 -1 roll 2 copy known { 
    get dup class /dictclass eq { 
      save exch transcribe exch dup capsave exch
      dup 3 1 roll /mySave put
      def true
    } {pop pop false} ifelse
  } {pop pop pop false} ifelse
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

|---------------------------- dstate_
| some debugging stuff of alex's, puts
| opstack in userdict->[d_opstack]
| dictstack in userdict->[d_dictstack]
| execstack in userdict->[d_execstack]
/reverse { | [ n1 .. nx ] | [ nx ... n1] 
  dup length list 2 copy {
    dup length 0 eq ~exit if
    1 index 0 get 1 index dup last put
    0 1 index last getinterval exch
    1 1 index last getinterval exch
  } loop
  pop pop exch pop
} bind def

/dstate_ {
  userdict /dstate_sv known {dstate_sv restore} if
  save userdict /dstate_sv put

  countexecstack list execstack dup length 1 sub 0 exch getinterval
    reverse
    userdict /d_execstack put

  count list {
    count 1 eq ~exit if
    dup 3 1 roll count 3 sub put
  } loop
    dup reverse
    userdict /d_opstack put
    {} forall
    
  countdictstack list dictstack dup length 0 exch getinterval
    reverse
    userdict /d_dictstack put

  userdict /dstate_sv get capsave
} bind def


| (source) /ERROR_NAME | --
/makeerror {
  {
    _makeerror {error_ops_length dup 2 sub roll} if
    ERRORS exch get
  } userdict indict
  error
} bind def

| e1...ex ... n | ... e1..ex
/rollerror {error_ops_length 1 index add exch roll} bind def

| ... | --
/showerror ~[
  ~[
    2 ~rollerror 1024 /b array ~errormessage ~fax 1 ~sub
  ] ~warning
] bind def

| (startup-name) | (buffer)
/loadstartup {
  warning_buffer {(Loading: ) fax 2 index fax (\n) fax} tostring toconsole
  getstartupdir 1 index fromfiles
  warning_buffer {(Done ) fax 3 -1 roll fax (\n) fax} tostring toconsole
} bind def

| (dir) (name) | (buffer)
/loadopt {
  warning_buffer {
    (Trying: ) fax 3 index fax 2 index fax (...\n) fax
  } tostring toconsole

  2 copy fromxfiles {
    warning_buffer {
      (Read: ) fax 3 index fax 2 index fax (\n) fax
    } tostring toconsole
  } if
  pop pop
} bind def

/loadcolor {
  userdict /color known not {getstartupdir (color.d) fromfiles} if
} bind def


|========================= mouse & font functions ===================

/basefontdesc 8 dict dup begin
  /family (lucida) def
  /weight (medium) def
  /slant (r) def
  /points (140) def
  /BOLDFONT 2 dict dup begin /weight (bold) def /slant (r) def end def
  /ITALICFONT 1 dict dup begin /slant (i) def end def
  /BOLDITALICFONT 2 dict dup begin /weight (bold) def /slant (i) def end def
end def

/mkfontdict {/fontdesc name
  4 dict {
    /NORMALFONT /BOLDFONT /ITALICFONT /BOLDITALICFONT
  } {/fontname name
    /fontlength 0 def [
      {
        /foundry /family /weight /slant /width /style /pixels /points
        /resx /resy /space /avgwidth /registry /encoding
      } {/fontvalue name
        (-) (*) {
          fontdesc fontname known {
            fontdesc fontname get fontvalue known {
              pop fontdesc fontname get fontvalue get
              exit
            } if
          } if
          
          fontdesc fontvalue known {pop fontdesc fontvalue get exit} if
          
          basefontdesc fontname known {
            basefontdesc fontname get fontvalue known {
              pop basefontdesc fontname get fontvalue get exit} if
          } if
          
          basefontdesc fontvalue known {pop basefontdesc fontvalue get} if
          exit
        } loop

        dup length fontlength add 1 add /fontlength name
      } forall
    ] fontlength /b array 0 3 -1 roll {fax} forall pop
    1 index fontname put
  } forall
  mkread
} bind def

/fontdict1 1 dict mkfontdict def
/fontdict4 1 dict dup begin 
  /points (100) def
end mkfontdict def
/fontdict2 3 dict dup begin
  /family (helvetica) def
  /ITALICFONT 1 dict dup begin /slant (o) def end def
  /BOLDITALICFONT 1 dict dup begin /slant (o) def end def
end mkfontdict def
/fontdict3 4 dict dup begin
  /family (helvetica) def
  /points (100) def
  /ITALICFONT 1 dict dup begin /slant (o) def end def
  /BOLDITALICFONT 1 dict dup begin /slant (o) def end def
end mkfontdict def

/fontdict fontdict1 def
/lucida_140_fontdict fontdict1 def
/lucida_100_fontdict fontdict4 def
/helvetica_140_fontdict fontdict2 def
/helvetica_100_fontdict fontdict3 def

|-- mouse key combos
/mousebuttons 11 dict dup begin | {
  /left        1  def
  /middle      2  def
  /right       3  def
  /scrollUp    4  def
  /scrollDown  5  def
  /scrollLeft  6  def
  /scrollRight 7  def 
  /button8     8  def
  /button9     9  def
  /button10    10 def
  /button11    11 def| }
end mkread def

/mousekeys 12 dict dup begin | {
  /plain    0            def 
  /shift    1 0 bitshift def
  /capslock 1 1 bitshift def 
  /ctrl     1 2 bitshift def
  /mod1     1 3 bitshift def
  /mod2     1 4 bitshift def
  /mod3     1 5 bitshift def
  /mod4     1 6 bitshift def
  /mod5     1 7 bitshift def
  | aliases
  /alt     mod1 def
  /numlock mod2 def
  /super   mod4 def | }
end mkread def

| [/key1...] or /key, /button | {mB n1 eq mM n2 eq and}
/mkmousepair {
  ~[
    exch mousebuttons 1 index known {mousebuttons exch get} {
      (Warning unknown mouse button: ) toconsole _ pop -1
    } ifelse
    ~mB ~eq

    0 6 -1 roll dup class /listclass ne {[exch]} if {
      mousekeys 1 index known {mousekeys exch get or} {
        (Warning unknown mouse key: ) toconsole _ pop
      } ifelse
    } forall
    ~mM ~eq ~and
  ] bind
} bind def

/basemousedesc [
  /windows [/theeye /thehorses /macros /default]
  /events [
    /scrollProp /scrollUp /scrollDown /pageUp /pageDown 
    /click /open /check /remove
    /cancel /group /map /raise
  ]

  /ignore     [/capslock /numlock] | ignore for all
  /macros [ | ignore for macros
    /ignore [/capslock /numlock /ctrl /shift /alt /super]
  ] makestruct

  /click      [/plain /left       mkmousepair] | all 
  /remove     [/shift /left       mkmousepair] | theeye
  /scrollUp   [/plain /scrollUp   mkmousepair] | theeye
  /scrollDown [/plain /scrollDown mkmousepair] | theeye

  /pageUp     [
    /ctrl          /scrollUp   mkmousepair
    /plain         /scrollLeft mkmousepair
  ]  | theeye
  /pageDown   [
    /ctrl         /scrollDown  mkmousepair
    /plain        /scrollRight mkmousepair
  ] | theeye

  /scrollProp [ | theeye
    /plain        /right  mkmousepair 
    /shift        /left   mkmousepair
  ] 
  /open [       | theeye
    /plain        /right  mkmousepair
    /ctrl         /left   mkmousepair 
  ] 
  /check [      | theeye
    /plain        /middle mkmousepair
    /alt          /left   mkmousepair 
  ] 

  /map [        | thehorses
    /alt          /left   mkmousepair
    [/ctrl /alt]  /right  mkmousepair
    [/shift /alt] /right  mkmousepair
  ] 
  /cancel [    | thehorses
    /plain        /right  mkmousepair
    /shift        /left   mkmousepair 
  ] 
  /group  [    | thehorses
    /plain        /middle mkmousepair
    /ctrl         /left   mkmousepair 
    /shift        /right  mkmousepair
  ] 
  /raise  [    | thehorses
    /ctrl         /right  mkmousepair 
    [/shift /alt] /left   mkmousepair
    [/ctrl  /alt] /left   mkmousepair
  ]
] makestruct def

/mkmousedict_types {
  /mousedesc name
  mousedesc /basedesc known {
    mousedesc /basedesc get /mousebasedesc name
    mousebasedesc /windows known {
      mousebasedesc /windows get /mousewindows name
    } if
    mousebasedesc /events known {
      mousebasedesc /events get /mouseevents name
    } if
  } {
    /mousebasedesc 0 dict def
  } ifelse

  mousedesc /windows known {mousedesc /windows get /mousewindows name} if
  mousedesc /events known {mousedesc /events get /mouseevents name} if

  mousewindows length dict 
  mousewindows {/mousepage name
    mouseevents length 1 add dict 1 index mousepage put 
    [mouseevents {} forall /ignore] {/event name
      null {
        mousedesc mousepage known {
          mousedesc mousepage get event known {
            pop mousedesc mousepage get event get /mousepage exitto
          } if
        } if
          
        mousedesc event known {
          pop mousedesc event get /mousepage exitto
        } if
        
        mousebasedesc mousepage known {
          mousebasedesc mousepage get event known {
            pop mousebasedesc mousepage get event get /mousepage exitto
          } if
        } if
        
        mousebasedesc event known {pop mousebasedesc event get} if
      } /mousepage exitlabel
      1 index mousepage get event put
    } forall
    dup mousepage get /ignore get null eq {
      [] 1 index mousepage get /ignore put
    } if
  } forall
} bind def

/mkmousedict_keys {
  dup {/mousepage name pop
    mousepage {
      1 index /ignore eq {
        dup class /listclass ne {mousekeys exch get} {
          0 exch {mousekeys exch get or} forall
        } ifelse not
      } {
        ~[
          ~[
            false 4 -1 roll {
              dup active {
                dup class /listclass eq {~exec} if
              } {
                (Warning illegal mouse command: ) toconsole _ pop
              } ifelse
              {pop true /mousepage exitto} ~if
            } forall 
          ] /mousepage ~exitlabel
        ] bind 
      } ifelse mousepage 3 -1 roll put
    } forall
  } forall
  mkread
} bind def
    
/mkmousedict {
  {mkmousedict_types mkmousedict_keys} 10 dict indict
} bind def

/no_alt_mousedesc [
  /basedesc basemousedesc
  /check [      | theeye
    /super          /left   mkmousepair 
    /plain         /middle  mkmousepair
  ]

  /map        [ | thehorses
    /super /left            mkmousepair
    [/ctrl /super]  /right  mkmousepair
    [/shift /super] /right  mkmousepair
  ]
  /cancel [    | thehorses
    /shift          /left   mkmousepair 
    /plain          /right  mkmousepair
  ]
  /group  [    | thehorses
    /ctrl           /left   mkmousepair 
    /plain          /middle mkmousepair
    /shift          /right  mkmousepair
  ]
  /raise  [    | thehorses
    [/shift /super] /left   mkmousepair
    [/ctrl  /super] /left   mkmousepair
    /ctrl           /right  mkmousepair 
  ]
] makestruct def

/basemousedict [/basedesc basemousedesc] makestruct mkmousedict def
/no_alt_mousedict no_alt_mousedesc mkmousedict def
/commonmousedict basemousedict def

| mousestate /wintype actiondict mousedict | -- <<action exec'd>> 
/mouseaction {/mousedict name /actiondict name
  | bottom 8 bits are the modifier keys, bottom 8 of top 16 is mouse button
  | Why? No clear reason.
  exch dup -16 bitshift /mB name 255 and /mM name   | /wintype
  mousedict 1 index get /ignore get mM and /mM name | /wintype
  false mousedict 3 -1 roll get {                   | false /event {}
    1 index /ignore eq {pop pop} {
      actiondict 2 index known not {pop pop} {
        exec {exch pop true exit} {pop} ifelse
      } ifelse
    } ifelse
  } forall
  {actiondict exch get exec true} {false} ifelse
} bind def

/PROGS [
  {/GS /PDFLATEX /EPSTOPDF /PDFCROP /PDFTOPS /SED /BASH} {
    dup get_compile
  } forall |]
makestruct_close def

save 1024 /b array 1 index capsave | [
  dup 0 (Home:  )   fax gethomedir    fax (\n) fax 0 exch getinterval toconsole
  dup 0 (Startup: ) fax getstartupdir fax (\n) fax 0 exch getinterval toconsole
  {(errors.d) (linkedlist.d)} ~loadstartup forall
pop restore
