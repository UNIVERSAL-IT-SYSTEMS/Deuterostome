|================================== TheEye =================================
|   - graphically view/select contents of
|       - the VM and its composite objects
|       - file systems
|   - viewed objects are made available to other D code

200 dict dup begin  | of eyedict
(Loading TheEye.d  WN 15/4/03\n) toconsole

|=========================== window layout =================================
|  - horizontal:
|       - the top line is reserved to show detailed object info
|       - the body of the screen shows tables of objects
|       - bottom line is organized as a two scrollbars
|  - vertical: area below he top line forms two pages:
|       - left: root objects and objects previously opened
|       - right: contents of open object
|  - left-page objects are classified by icons along left margins;
|    each object entry list a name or index (dependend on the class
|    of the parent)
|  - one left-page object can be selected at a time and then is high-
|    lighted in red+boldface
|  - each right-page object is classified by the background color of
|    its row and by a short text description (the background of simple
|    objects is white); composite objects are classified also by a
|    short text description, whereas simple objects are shown as their
|    value 
|  - one or many right-page objects can be selected at a time and are
|    then highlighted in blue+boldface


/nL 30 def    | number of lines shown at once (master parameter!)

|-- fonts

  /NORMALFONT 
    (-b&h-lucida-medium-r-normal-sans-0-0-75-75-p-0-iso8859-1) def
  /BOLDFONT 
    (-b&h-lucida-bold-r-normal-sans-0-0-75-75-p-0-iso8859-1) def

|-- color templates

  /BLACK <d 0 0 0 > mapcolor def
  /BLUE  <d 0 0 1 > mapcolor def
  /RED   <d 1 0 0 > mapcolor def
 
  /ARROWBG  <d 206 213 218 > 255 div mapcolor def
  /LEFT  <d 0 0 1 > mapcolor def
  /RITE  <d 1 0 0 > mapcolor def
  /BG <d 235 243 248 > 255 div mapcolor def

  /DIRCOLOR   <d 231 214 227 > 255 div mapcolor def
  /LISTCOLOR  <d 204 235 197 > 255 div mapcolor def
  /ARRAYCOLOR <d 204 235 197 > 255 div mapcolor def
  /DICTCOLOR  <d 166 219 160 > 255 div mapcolor def
  /BOXCOLOR   <d 166 219 160 > 255 div mapcolor def 
  
|-- priming geometrical templates

  /wW 457 def /wH nL 13 mul 30 add def

  /woutline [ 0 0 wW 1 sub 0 wW 1 sub wH 1 sub 0 wH 1 sub 0 0 ] def
  /vdivider [ wW 2 div 14 wW 2 div wH 1 sub ] def
  /htdivider [ 0 14 wW 14 ] def
  /hbdivider [ 0 wH 15 sub wW 1 sub wH 15 sub ] def
  /grayrect [ 1 wH 14 sub wW 2 sub 13 ] def
  /inforect [ 1 1 wW 2 sub 13 ] def
  /leftpagerect [ 1 15 wW 3 sub 2 div wH 30 sub ] def
  /ritepagerect [ wW 3 sub 2 div 2 add 15 wW 3 sub 2 div wH 30 sub ] def
  /dx wW 12 div def /y wH 8 sub def

  /barsymbleft [
    /x dx 2 div def
    x y   x 8 add y
    /x x dx add def
    x 4 sub y x 4 add y
    /x x dx add def
    x y
    /x x dx 4 mul add def
     x y   x 8 add y
    /x x dx add def
    x 4 sub y x 4 add y
    /x x dx add def
    x y
  ] def

  /barsymbrite [
    /x dx 7 mul 2 div def
    x y
    /x x dx add def
    x 4 sub y x 4 add y
    /x x dx add def
    x 8 sub y   x y
    /x x dx 4 mul add def
    x y
    /x x dx add def
    x 4 sub y x 4 add y
    /x x dx add def
    x 8 sub y   x y
  ] def

  /barsymbvert [
    /x dx 2 div def
    x 4 sub y
    /x x dx 5 mul add def
    x 4 add y
    /x x dx add def
    x 4 sub y
    /x x dx 5 mul add def
    x 4 add y
  ] def

  /iconrects [
    15 13 nL 1 sub 13 mul 15 add { /y name
       /r 4 /w array def
       1 r 0 put  y r 1 put 24 r 2 put 13 r 3 put
       r
       } for
  ] def

  /iconlocs [
    /x 13 def
    27 13 nL 1 sub 13 mul 27 add { /y name
       [ x y 7 sub ] mkact
       } for
  ] def

  /reflocs [
    /x wW 3 sub 2 div 3 add def
    27 13 nL 1 sub 13 mul 27 add { /y name
       [ x y 7 sub ] mkact
       } for
  ] def

  /valuerects [
    /x wW 3 sub dup 4 div sub 1 add def
    15 13 nL 1 sub 13 mul 15 add { /y name
       /r 4 /w array def
       x r 0 put  y r 1 put wW 3 sub 4 div r 2 put 13 r 3 put
       r
       } for
  ] def

  /valuelocs [
    /x wW dup 4 div sub 4 add def
    27 13 nL 1 sub 13 mul 27 add { /y name
       [ x y 7 sub ] mkact
       } for
  ] def

  /filerects [
    /x wW 3 sub 2 div 2 add def
    15 13 nL 1 sub 13 mul 15 add { /y name
       /r 4 /w array def
       x r 0 put  y r 1 put wW 3 sub 2 div r 2 put 13 r 3 put
       r
       } for
  ] def

  /filelocs [
    /x wW 2 div 5 add def
    27 13 nL 1 sub 13 mul 27 add { /y name
       [ x y 7 sub ] mkact
       } for
  ] def

|-------------------- interface to viewed objects ----------------------
| The composite objects currently held in the left page are accessible
| through:
|
|   leftpage     - list of object descriptors (up to 100)
|   leftpageU    - current # of objects in leftpage
|   leftchecked  - -1 or index of checked object in leftpage
|
| Each class of leftpage object is described by a list of 3 with the
| following meaningful entries:
|
|  [ /VMclass                           ]
|  [ /FSclass                           ]
|  [ /dirclass   (path) (dirname)       ]
|  [ /dictclass  dict name/index        ]
|  [ /listclass  list name/index        ]
|  [ /arrayclass array name/index       ]
|
|---------------------------- some NOTABLES -------------------------------
|
| - any composite object designated by clicking into either page is first
|   described in 'theobj' list
| - an object opened in this act is described in 'theopen' list and is
|   included into the 'leftpage' list of object descriptors
| - in the case of directory objects, the object descriptor includes strings
|   which require special attention to memory management as physical copies
|   of these strings need to be mage during the activity of TheEye
| - the strings in 'theopen' are created together with 'thefilelist' and
|   'checkmarks' when the object is opened, and they vanish when a new
|   object is opened
| - the strings in 'leftpage' descriptors are parceled out from a buffer
|   that is part of TheEye; this buffer is reprimed when all leftpage
|   objects but the two root objects have been removed by shift-clicks
|   into the left page
| - if a D object is removed between successive uses of TheEye, the fact
|   is automatically recognized; for instance, a right page showing the
|   value of such an object is cleared
| - errors occurring in TheEye are indicated in the info line at the top
|   of the window; TheEye activity is stopped leaving clean stacks such that
|   an ongoing activity is not compromised
|  
|------------------------- data structures ------------------------------

|---------------- left page

/leftpage [ 100 { 3 list } repeat ] def  | leftpage object list buffer
[ /VMclass userdict /userdict ] leftpage 0 get copy pop | VM entry
[ /FSclass (/) () ] leftpage 1 get copy pop             | FS entry
/leftpageU 2 def               | current used length of object list
/leftpageT 0 def               | index of top displayed object
/leftchecked -1 def

/leftpageSB 10000 /b array def | for path and dirnames of leftpage objects
/leftpagesb leftpageSB def

|----------------- right page

/theopen 3 list def            | object open on right page
/nullclass theopen 0 put
/ritepageU 0 def               | dimension of open object
/ritepageT 0 def               | index of top element being displayed  
/showRpage { } def             | procedure to show current open object
/fromRpage { } def             | procedure to fetch object from right page

|-- miscellaneous small buffers

/strbuf 80 /b array def
/infoline 160 /b array def
/pathbuf 1024 /b array def
/theobj [ /nullclass null null ] def
/fde <l 0 0 0 0 0 0 > def

|-- file attribute templates

/TYPE 61440L def
/DIRTYPE 16384L def

|-- mouse key combos
/shift1_plain3 {
  mB 1 eq mM 1 eq and
  mB 3 eq mM 0 eq and or
} bind def

/plain1 {
  mB 1 eq mM 0 eq and
} bind def

|/shift1_plain4 {
|  mB 1 eq mM 1 eq and
|  mB 4 eq mM 0 eq and or
|} bind def

/shift1 {
  mB 1 eq mM 1 eq and
} bind def

/opt1_plain2 {
  mB 1 eq mM 8 eq and
  mB 2 eq mM 0 eq and or
} bind def

/ctrl1_plain3 {
  mB 1 eq mM 4 eq and
  mB 3 eq mM 0 eq and or
} bind def

/scrollUp {
  mB 4 eq mM 0 eq and
} bind def

/scrollDown {
  mB 5 eq mM 0 eq and
} bind def

/pageUp {
  mB 4 eq mM 4 eq and
} bind def

/pageDown {
  mB 5 eq mM 4 eq and
} bind def

|============================== front end ================================

|--------------------------------------------- resist resizing

/windowsize {
  wH ne exch wW ne or {
    { [
      wid wW wH resizewindow
    } stopped cleartomark
  } if end
} bind def

|--------------------------------------------- draw the screen
| - draws the screen layout
| - scans the environment for root objects (VM, mounted directories)
| - updates the left page, removing all objects whose roots do no longer
|   exist; removes the checkmark
| - clears the right page
| - shows the left page

/drawwindow {
{ [ {    | stop capsule + reentry prevention

|-- show structural elements
  wid woutline BLACK drawline
  wid htdivider BLACK drawline
  wid grayrect ARROWBG fillrectangle
  wid hbdivider BLACK drawline
  wid barsymbleft LEFT 14 9 drawsymbols
  wid barsymbrite RITE 13 9 drawsymbols
  wid barsymbvert  BLACK 15 9 drawsymbols
  wid vdivider BLACK drawline

|-- rebuild left page and uncheck leftpage item, show left page
  rebuildLpage pop
  /leftchecked -1 def
  showLpage
  wid inforect BG fillrectangle
  wid ritepagerect BG fillrectangle
  showRpage
} lock} stopped cleartomark
end
} bind def

|--------------------------------------- respond to mouse click
|  - dispatches control according to the clicked field:
|     - scroll field: on shift key, the right-page scrolling follows
|       absolute position, else the scroll symbols are interpreted;
|     - simple clicking into an item on either page shows the item's info
|     - control clicking opens a composite item, adding it to the left page
|       and showing its value in the right page
|     - command clicking checks one item in the left page or an unlimited
|       number of items in the right page
|     - shift clicking a left page item removes the item from the display
 
/mouseclick {
  {[ 4 1 roll { | stopped and reentry lock
      dup -16 bitshift /mB name
          255 and      /mM name
      /mY name /mX name 
      mY 14 le { wid inforect BG fillrectangle stop } if
      mY wH 15 sub ge {
        shift1_plain3 {|-- 'shift': proportional scrolling
          mX wW 3 sub 2 div 2 add ge {
            /ritepageT 2 ritepageU nL sub mul mX wW 3 sub 2 div sub mul
            wW 3 sub div def showRpage stop
          } {
            scrolls mX 12 mul wW div get exec stop
          } ifelse
        } if
        
        plain1 { |-- plain click: do appropriate scroll step
          scrolls mX 12 mul wW div get exec stop
        } if
        scrollUp {
          scrolls 2 mX wW 3 sub 2 div 1 add gt {6 add} if get exec stop
        } if
        scrollDown {
          scrolls 3 mX wW 3 sub 2 div 1 add gt {6 add} if get exec stop
        } if
        pageUp {
          scrolls 1 mX wW 3 sub 2 div 1 add gt {6 add} if get exec stop
        } if
        pageDown {
          scrolls 4 mX wW 3 sub 2 div 1 add gt {6 add} if get exec stop
        } if

        stop
      } if
    /mL mY 15 sub 13 div def
    mX wW 3 sub 2 div 1 add le { hitL } { hitR } ifelse
  } lock} stopped cleartomark
  end 
} bind def

|============================ shared machinery ===========================

|-------------------- responding to click into a scroll field

/scrolls [
  { /leftpageT 0 def showLpage }
  { nL neg scrollLpage }
  { -1 scrollLpage }
  { 1 scrollLpage }
  { nL scrollLpage }
  { leftpageU nL sub dup 0 lt { pop 0 } if /leftpageT name showLpage }

  { /ritepageT 0 def showRpage }
  { /ritepageT ritepageT nL sub def showRpage }
  { /ritepageT ritepageT 1 sub def showRpage }
  { /ritepageT ritepageT 1 add def showRpage }
  { /ritepageT ritepageT nL add def showRpage }
  { /ritepageT ritepageU nL sub def showRpage }
] def

|------------------- presenting info on (simple-) clicked object

/INFOTEXT [ NORMALFONT BLACK -1 -1 ] def

/toinfo { 
  wid inforect BG fillrectangle
  theobj 1 get class /nullclass ne {
    wid 2 12 infoline 0 infoclasses theobj 0 get get mkact exec
      0 exch getinterval
    INFOTEXT drawtext pop pop pop
  } if
} def

/Kb { * exch 999 add 1000 div * number } def

15 dict dup begin
/VMclass     { * (VM: ) text vmstatus /bused name Kb
               * ( total Kb, ) text bused Kb * ( used) text
             } def
/FSclass     { * (/ - root of Linux filesystem) text } def
/dirclass    { theobj 1 get fax theobj 2 get dup
               length 0 eq { pop } { fax (/) fax } ifelse
             } def
/fileclass   { * (file of ) text 
               thefilelist theidx get /fd name
               * fd 1 get * number 
               * (   ) text
               fd 2 get fde localtime pop
               * fde 1 get * number * (/) text
               * fde 2 get * number * (/) text
               * fde 0 get * number * (   ) text 
               * fde 3 get * number * (:) text
               * fde 4 get * number (   ) fax
               fd 3 get 256 and 0 ne { (r) } { (-) } ifelse fax
               fd 3 get 128 and 0 ne { (w) } { (-) } ifelse fax
               fd 3 get  64 and 0 ne { (x) } { (-) } ifelse fax
               fd 3 get  32 and 0 ne { (r) } { (-) } ifelse fax
               fd 3 get  16 and 0 ne { (w) } { (-) } ifelse fax
               fd 3 get   8 and 0 ne { (x) } { (-) } ifelse fax
               fd 3 get   4 and 0 ne { (r) } { (-) } ifelse fax
               fd 3 get   2 and 0 ne { (w) } { (-) } ifelse fax
               fd 3 get   1 and 0 ne { (x) } { (-) } ifelse fax
             } def
/arrayclass  { * /theobj find 1 get type text
               * ( array) text
               * ( of ) text * /theobj find 1 get length * number
               /theobj find 1 get type /B eq {
                 ( () fax
                 1 index length 1 index sub 1 sub
                   /theobj find 1 get length 2 copy gt ~exch if pop
                   /theobj find 1 get 0 3 -1 roll getinterval fax
                 (\)) fax
               } if
             } def
/listclass   { * theobj 1 get active { (proc) } { (list) } ifelse text
               * ( of ) text * theobj 1 get length * number
             } def
/dictclass   { * (dict) text
               * ( of ) text * theobj 1 get length * number
               * ( total, ) text * theobj 1 get used * number
               * ( used) text
             } def
/boxclass    { * ('save' box) text 
             } def
/numclass    { * theobj 1 get * number * theobj 1 get type mkact text
             } def
/nullclass   { } def
/opclass     { } def
/nameclass   { } def
/boolclass   { } def
end mkread /infoclasses name

|-------- deleting pre-existing rightpage buffers to create a new set

/newbuffers {
   TheEye /currentbuffers known { currentbuffers restore } if
   save /currentbuffers name
   /nullclass theopen 0 put
} def

|-------- opening file directory
/open_dir {
   pathbuf 0 theobj 1 get fax
     theobj 2 get dup length 0 eq { pop } { fax (/) fax } ifelse
     0 exch getinterval
     save /tempcbs name
   { findfiles dup length /b array
     theobj 1 get dup length /b array copy 
     theobj 2 get dup length /b array copy
   } stopped tempcbs capsave
     { tempcbs restore stop }
     { tempcbs capsave
       theopen 2 put theopen 1 put 
       /checkmarks name 0 checkmarks copy pop
       /thefilelist name
       theobj 0 get theopen 0 put
       TheEye /currentbuffers known { currentbuffers restore } if
       /currentbuffers tempcbs def
       /ritepageT 0 def /ritepageU thefilelist length def
       /showRpage /show_dir find def /fromRpage /from_dir find def
       showRpage 
     }
     ifelse
} def

|-------- opening dictionary
/open_dict {
   /ritepageT 0 def /ritepageU theobj 1 get used def
   newbuffers
   ritepageU /b array /checkmarks name
   0 checkmarks copy pop
   currentbuffers capsave
   theobj theopen copy pop
   /showRpage /show_dict find def /fromRpage /from_dict find def
   showRpage
} def

|-------- opening list/procedure
/open_list {
   /ritepageT 0 def /ritepageU theobj 1 get length def
   newbuffers
   theobj 1 get length /b array /checkmarks name
   0 checkmarks copy pop
   theobj theopen copy pop
   currentbuffers capsave
   /showRpage /show_list find def /fromRpage /from_list find def
   showRpage
} def

|-------- opening array
/open_array {
   /ritepageT 0 def /ritepageU theobj 1 get length def
   newbuffers
   theobj 1 get length /b array /checkmarks name
   0 checkmarks copy pop
   theobj theopen copy pop
   /showRpage /show_array find def /fromRpage /from_array find def
   showRpage
} def

|------------------------------ local error handling
|
| - error messages are intercepted and displayed on the info line
| - stacks are cleaned up and 'stop' is executed

/error {
  dup 3 1 roll
  wid inforect BG fillrectangle
  infoline errormessage dup length 1 sub 0 exch getinterval
  wid 2 12 4 -1 roll INFOTEXT drawtext
  208 ne {stop} {
    (Illegal stop in the eye\n) toconsole
    countdictstack 2 sub {end} repeat
    abort
  } ifelse
} bind def

|========================= left page machinery ============================

|--------- responding to click into left page:
|  simple click      - show object info |Button1
|  ctrl/click        - show object value in right page |Button3
|  cmd/click         - check/uncheck object |Button2
|  shift/click       - remove object from left page |Button4
|
| Before the click is attended to, the left page is rebuilt, eliminating
| all objects that no longer exist (in VM, or file directories whose
| path strings have been eliminated from the VM). If rebuilding eliminates
| objects, the new left page is shown, but the click is otherwise ignored.

/hitL {
 { | stopped
   leftpageT mL add dup leftpageU ge { pop stop } if /theidx name
   rebuildLpage { showLpage stop } if
   shift1 |-- 'shift': remove an object
      { /leftchecked -1 def
        mL 2 ge {
          leftpageT mL add 1 add 1 leftpageU 1 sub { /k name
              leftpage k get leftpage k 1 sub get copy pop
            } for
          /leftpageU k def
          leftpageU 2 eq { /leftpagesb leftpageSB def } if
          showLpage stop 
          } if
      } if
   opt1_plain2 |-- 'option': check/uncheck an object
      { 
        leftchecked theidx eq { -1 } { theidx } ifelse /leftchecked name
        showLpage stop
      } if
   ctrl1_plain3 |-- 'control': open the object in the right page
     { leftpage theidx get theobj copy pop
       openLclasses theobj 0 get get mkact exec
       rebuildLpage pop showLpage stop
     } if
   plain1 |-- plain click
     { leftpage theidx get theobj copy pop toinfo } if
   scrollUp {scrolls 2 get exec stop } if
   scrollDown {scrolls 3 get exec stop} if
   pageUp {scrolls 1 get exec stop} if
   pageDown {scrolls 4 get exec stop} if
 } stopped pop
} def

|----------------- rebuilding left page:
| - retains existing left page minus objects that do no longer exist
| - returns boolean indicating removal of object(s)

/rebuildLpage {
  false
  leftpageU 1 sub /leftpageU 0 def
  0 1 3 -1 roll { /k name
      leftpage k get dup 0 get keeps exch get exec
      { leftpage k get leftpage leftpageU get copy pop
        /leftpageU leftpageU 1 add def
      } { pop true } ifelse
    } for
  dup { /leftpageT 0 def } if
} bind def
  
10 dict dup begin
/VMclass  { pop true } def
/FSclass  { pop true } def
/dictclass  { 1 get class /dictclass eq } bind def
/listclass  { 1 get class /listclass eq } bind def
/arrayclass { 1 get class /arrayclass eq } bind def
/dirclass { pop true } def
end /keeps name

|-------------- showing left page

/showLpage { 
  wid leftpagerect BG fillrectangle
  /vidx 0 def /pidx leftpageT def
  { vidx nL ge pidx leftpageU ge or { exit } if
    leftpage pidx get theobj copy pop
    /textpar pidx leftchecked eq
         { LEFTCHECKED }
         { LEFTNORMAL } 
         ifelse def
    objpresenters theobj 0 get get exec
    /vidx vidx 1 add def /pidx pidx 1 add def
  } loop
} bind def

/LEFTCHECKED [ BOLDFONT RED -1 0 ] def
/LEFTNORMAL  [ NORMALFONT BLACK -1 0 ] def


|-------------- scrolling left page
|  #lines | --

/scrollLpage { 
  leftpageT add 
  dup leftpageU nL sub gt { pop leftpageU nL sub } if
  dup 0 lt { pop 0 } if
  /leftpageT name showLpage
} bind def

|------------------- presenting a left-page object
| expects 'vidx' = rowindex of selected object
 
9 dict dup begin
/VMclass     { dict_icon   (VM)  icon_text
               { * (userdict) text } show_id
             } bind def
/FSclass    { dir_icon (FS) icon_text 
               { * (/) text } show_id
             } bind def
/dirclass    { dir_icon  (DIR) icon_text
               { * theobj 2 get text } show_id
             } bind def
/arrayclass  { array_icon  (< >) icon_text
               show_nameidx
             } bind def
/listclass   { list_icon 
               theobj 1 get active { ({ }) } { ([ ]) } ifelse icon_text
               show_nameidx
             } bind def
/dictclass   { dict_icon (~|~) icon_text
               show_nameidx
             } bind def
/boxclass    { box_icon (|_|) icon_text show_nameidx
             } bind def
end mkread /objpresenters name

/dir_icon    { wid iconrects vidx get DIRCOLOR fillrectangle } bind def
/list_icon   { wid iconrects vidx get LISTCOLOR fillrectangle } bind def
/array_icon  { wid iconrects vidx get ARRAYCOLOR fillrectangle } bind def
/dict_icon   { wid iconrects vidx get DICTCOLOR fillrectangle } bind def
/box_icon    { wid iconrects vidx get BOXCOLOR fillrectangle } bind def


/ICONTEXT [ NORMALFONT <d 0 0 0 > mapcolor 0 0 ] def

/icon_text  { wid iconlocs vidx get exec 4 -1 roll 
              ICONTEXT drawtext pop pop pop
            } bind def

/show_id {
   wid iconlocs vidx get exec exch 24 add exch
   4 -1 roll
   strbuf 0 3 -1 roll exec 0 exch getinterval
   dup length nL gt { 0 nL getinterval } if
   textpar drawtext pop pop pop
} bind def

/show_nameidx {
   { * theobj 2 get dup class /nameclass eq { text } { * number } ifelse }
   show_id
} bind def

|--------------- opening leftpage object (by control/click)

6 dict dup begin
/VMclass     { open_dict } def
/FSclass     { open_dir } def
/dirclass    { open_dir } bind def
/arrayclass  { open_array } bind def
/listclass   { open_list } bind def
/dictclass   { open_dict } bind def
end mkread /openLclasses name


|=========================== right page machinery ==========================

|-------------- responding to click into right page
|  simple click      - show object info
|  ctrl/click        - open object and show contents
|  cmd/click         - check/uncheck object
|
| Before the click is attended to, the existence of the open object is
| verified (see hitL). If the object has been eliminated, a blank right
| page is shown, and the left page is rebuilt and shown; the click then
| is ignored.

/hitR { 
 { | stopped
   ritepageT mL add dup ritepageU ge { pop stop } if /theidx name
   theopen 0 get class /nullclass eq 
      { wid ritepagerect BG fillrectangle
        rebuildLpage pop showLpage
      } if
   opt1_plain2 |-- 'option': check/uncheck an object
      { 
        checkmarks theidx get 0 eq { -1 } { 0 } ifelse checkmarks theidx put
        showRpage stop
      } if
   ctrl1_plain3 |-- 'control': open object
     { fromRpage 
       openRclasses theobj 0 get get exec
       { leftpage 0 leftpageU getinterval
          { /theitem name theitem 0 get theopen 0 get eq {
                theopen 0 get dupchecks exch get exec { stop } if 
                } if        
          } forall
       } stopped not 
         { rebuildLpage pop leftpageU leftpage length lt
               { theopen 0 get /dirclass eq
                   { /theitem leftpage leftpageU get def
                     leftpagesb theopen 1 get length /b parcel
                       theopen 1 get exch copy theitem 1 put 
                     theopen 2 get length /b parcel
                       theopen 2 get exch copy theitem 2 put
                     /leftpagesb name
                     theopen 0 get theitem 0 put
                   }
                   { theopen leftpage leftpageU get copy pop
                   }
                   ifelse
                 /leftpageU leftpageU 1 add def
                 showLpage
               } if
         } if
       stop
     }
     if
   plain1 |-- plain click: show object info
     { fromRpage toinfo } if
   scrollUp {scrolls 8 get exec stop} if
   scrollDown {scrolls 9 get exec stop} if
   pageUp {scrolls 7 get exec stop} if
   pageDown {scrolls 10 get exec stop} if
 } stopped pop
} def

|-------------- clear right page

/clearRpage {
  /nullclass theopen 0 put
  /ritepageU 0 def               | dimension of open object
  /ritepageT 0 def               | index of top element being displayed  
  /showRpage { } def             | procedure to show current open object
  /fromRpage { } def             | procedure to fetch object from right page
  wid ritepagerect BG fillrectangle
} bind def

|--------------- opening rightpage object (by control/click)

11 dict dup begin
/dirclass    { open_dir } bind def
/fileclass   { stop } def
/arrayclass  { open_array } def
/listclass   { open_list } def
/dictclass   { open_dict } def
/boxclass    { stop } def 
/nullclass   { stop } def
/opclass     { stop } def
/boolclass   { stop } def
/numclass    { stop } def
/nameclass   { stop } def
end mkread /openRclasses name

|-- duplication checks (for left page items)

4 dict dup begin
/dirclass    { theitem 1 get theopen 1 get eqstr
               theitem 2 get theopen 2 get eqstr and } bind def
/arrayclass  { theitem 1 get theopen 1 get eq } bind def
/listclass   { theitem 1 get theopen 1 get eq } bind def
/dictclass   { theitem 1 get theopen 1 get eq } bind def
end mkread /dupchecks name

/eqstr { anchorsearch { pop length 0 eq } { pop false } ifelse } bind def

|------------- representing a right-page D object value
| expects 'Rvaluerect' to be established for placing value

10 dict dup begin
/nullclass   { { * (null) text theitem type /T eq {(:socket) fax} if}
                BG show_value
             } bind def
/numclass    { { * theitem dup type /D eq { 7 } { * } ifelse number }
               BG show_value
             } bind def
/opclass     { { * (..) text * /theitem find text } BG show_value
             } bind def
/nameclass   { { /theitem find tilde {* (~) text} {
                   /theitem find active not { * (/) text } if
                 } ifelse
                 * /theitem find text }
               BG show_value 
             } bind def
/boolclass   { { * (BOOL: ) text * theitem { (true) } { (false) } ifelse
                 text } BG show_value 
             } bind def
/markclass   { { * ([) text } BG show_value 
             } bind def
/arrayclass  { { * (<) text * /theitem find type text * ( > of ) text
                 * /theitem find length * number
                 /theitem find active {( active) fax} if }
               ARRAYCOLOR show_value
             } bind def
/listclass   { { * /theitem find active { ({ }) } { ([ ]) } ifelse text
                 * ( of ) text * /theitem find length * number
               } LISTCOLOR show_value
             } bind def
/dictclass   { { * (~|~ of ) text * theitem length * number
                 theitem type /O eq {(:oplib) fax} if
               } DICTCOLOR show_value
             } bind def
/boxclass    { { * (|_| of ) text * theitem length * number
                 theitem type /M eq {(:mc) fax} if
               } BOXCOLOR show_value
             } bind def
end mkread /valuepresenters name

|----------- showing a value field in the right page
| text_generator fillpar | --

/VALUETEXT [ NORMALFONT BLACK -1 0 ] def
/RITEHIGH [ BOLDFONT BLUE -1 0 ] def

/show_value { /fill name /textgen name
   wid valuerects vidx get fill fillrectangle
   wid valuelocs vidx get exec
   strbuf 0 textgen 0 exch getinterval
   VALUETEXT drawtext pop pop pop  
} def 

|------- showing dictionary value
| dict | --

/show_dict {
   wid ritepagerect BG fillrectangle
   theopen 0 get class /nullclass eq { stop } if
   ritepageT nL add ritepageU gt { /ritepageT ritepageU nL sub def } if
   ritepageT 0 lt { /ritepageT 0 def } if
   /skips ritepageT def /vidx 0 def /theidx 0 def
   theopen 1 get
    { /theitem name /thename name
      skips 0 eq
         { wid reflocs vidx get exec 
           strbuf 0 * thename text 0 exch getinterval
           checkmarks theidx get 0 ne
            { RITEHIGH } { VALUETEXT } ifelse
           drawtext pop pop pop
           valuepresenters /theitem find class get exec
           vidx 1 add dup nL ge { pop exit } if /vidx name
         }
         { /skips skips 1 sub def }
         ifelse
      /theidx theidx 1 add def
   } forall
} def

|-------- showing list/procedure value

/show_list {
   wid ritepagerect BG fillrectangle
   theopen 0 get class /nullclass eq { stop } if
   ritepageT nL add ritepageU gt { /ritepageT ritepageU nL sub def } if
   ritepageT 0 lt { /ritepageT 0 def } if
   0 1 nL 1 sub 
      { /vidx name
        ritepageT vidx add dup ritepageU ge { pop exit } if /theidx name
        theopen 1 get theidx get /theitem name
        wid reflocs vidx get exec
        strbuf 0 * theidx * number 0 exch getinterval
        checkmarks theidx get 0 ne
            { RITEHIGH } { VALUETEXT } ifelse
        drawtext pop pop pop
        valuepresenters /theitem find class get exec
      } for
} def


|-------- show array value

/show_array {
   wid ritepagerect BG fillrectangle
   theopen 0 get class /nullclass eq { stop } if
   ritepageT nL add ritepageU gt { /ritepageT ritepageU nL sub def } if
   ritepageT 0 lt { /ritepageT 0 def } if
   0 1 nL 1 sub 
      { /vidx name
        ritepageT vidx add dup ritepageU ge { pop exit } if /theidx name
        theopen 1 get theidx get /theitem name
        wid reflocs vidx get exec
        strbuf 0 * theidx * number 0 exch getinterval
        checkmarks theidx get 0 ne
            { RITEHIGH } { VALUETEXT } ifelse
        drawtext pop pop pop
        valuepresenters /numclass get exec
      } for
} def

|------- showing a file directory

/show_dir {
   wid ritepagerect BG fillrectangle
   theopen 0 get class /nullclass eq { stop } if
   ritepageU 0 gt {
     ritepageT nL add ritepageU gt { /ritepageT ritepageU nL sub def } if
     ritepageT 0 lt { /ritepageT 0 def } if
     0 1 nL 1 sub 
        { /vidx name
          ritepageT vidx add dup ritepageU ge { pop exit } if /theidx name
          thefilelist theidx get /theitem name
          wid filerects vidx get 
            theitem 3 get TYPE and DIRTYPE eq  
            { DIRCOLOR } { BG } ifelse fillrectangle
          wid filelocs vidx get exec
          theitem 0 get checkmarks theidx get 0 ne
              { RITEHIGH } { VALUETEXT } ifelse
          drawtext pop pop pop
        } for
     } if   
} def

|------- picking item from a dictionary

/from_dict {
   /k 0 def
   theopen 1 get
      { /theitem name /thename name
        k theidx eq
             { /theitem find dup class theobj 0 put theobj 1 put
               thename theobj 2 put
               exit
             }
             { /k k 1 add def }
             ifelse
      } forall
} def

|------- picking item from a list/procedure

/from_list {
   theopen 1 get theidx get dup
   class theobj 0 put theobj 1 put
   theidx theobj 2 put
} bind def

|------- picking item from an array

/from_array {
   theopen 1 get theidx get dup
   class theobj 0 put theobj 1 put
   theidx theobj 2 put
} bind def

|------- picking item from a directory
| merges thedirname of the directory into thepath and sets
| thename of the clicked element

/from_dir {
   thefilelist theidx get /theitem name
   theitem 3 get TYPE and DIRTYPE eq
   { /dirclass } { /fileclass } ifelse theobj 0 put
   pathbuf 0 theopen 1 get fax
   theopen 2 get dup length 0 eq { pop } { fax (/) fax } ifelse
     0 exch getinterval theobj 1 put
   theitem 0 get theobj 2 put
} def

|-------------------- extraction tools ---------------------------------

|--- faxLpage and faxRpage
| use:  buffer index | buffer new_index
|
| these procedures fax a string representation of a directory selected
| in the left page or of directories/files selected in the right page;
| the string format is suitable for presenting arguments to shell
| commands. If nothing is selected or other types of object are selected,
| nothing is faxed.

/faxLpage {
  TheEye begin
  { leftchecked -1 ne
    { leftpage leftchecked get 0 get /dirclass eq
       { (') fax leftpage leftchecked get 1 get fax
         leftpage leftchecked get 2 get fax (/') fax 
       } if  
    } if
  } stopped pop end
} bind def  

/faxRpage {
  TheEye begin
  { faxRclasses theopen 0 get get exec 
  } stopped pop end
} bind def 

/faxRclasses 6 dict dup begin

/VMclass { } def

/FSclass {
   0 0 1 checkmarks length 1 sub {
       checkmarks exch get 0 ne { 1 add } if
     } for /nchecked name
   /firstcheck true def
   0 1 checkmarks length 1 sub { /kR name
       checkmarks kR get 0 ne {
          firstcheck {
              nchecked 2 ge { ('/'{) } { ('/') } ifelse fax
              /firstcheck false def
            } { (,) fax } ifelse
          (') fax thefilelist kR get 0 get fax (') fax
        } if
    } for
  firstcheck not nchecked 2 ge and { (}) fax } if
} bind def

/dirclass {
   0 0 1 checkmarks length 1 sub {
       checkmarks exch get 0 ne { 1 add } if
     } for /nchecked name
   /firstcheck true def
   0 1 checkmarks length 1 sub { /kR name
       checkmarks kR get 0 ne {
          firstcheck { 
              (') fax theopen 1 get fax theopen 2 get fax
              nchecked 2 ge { (/'{) } { (/') } ifelse fax
              /firstcheck false def
            } { (,) fax } ifelse
          (') fax thefilelist kR get 0 get fax (') fax
        } if
    } for
  firstcheck not nchecked 2 ge and { (}) fax } if
} bind def

/dictclass {} def
/listclass {} def
/arrayclass {} def

end def

|--- getLpage
| use: - | object true
|        | false
|
| If a D object is selected in the left page, the object is returned.
| If a directory is selected, a string containing the path is returned.
| The returned boolean indicates whether an object is selected.

/getLpage {
  TheEye begin
  { leftchecked -1 ne
    { leftpage leftchecked get 0 get /dirclass eq
       { leftpage leftchecked get dup 1 get length exch
         2 get length add 1 add /b array 0
         leftpage leftchecked get 1 get fax
         leftpage leftchecked get 2 get fax (/) fax pop true
       } { false } ifelse  
    } if
  } stopped pop end
} bind def 

|--- getRpage
| use: - | [ D_object ...]
|        | [ (path) [(dir/filename) ...] ] 
|        | [ ]
| If no object is selected, an empty list is returned. 

/getRpage {
  [
  TheEye begin
  { getRclasses theopen 0 get get exec 
  } stopped pop end
  ]
} bind def 
 
/getRclasses 6 dict dup begin

/VMclass {
  /kR 0 def
  userdict { checkmarks kR get 0 ne
             { exch pop } { pop pop } ifelse
             /kR kR 1 add def
           } forall
} bind def

/FSclass {
  0 1 checkmarks length 1 sub { /kR name
      checkmarks kR get 0 ne
        { thefilelist kR get 0 get length 1 add /b array 0
          (/)fax thefilelist kR get 0 get fax pop
        } if
    } for
} bind def

/dirclass {
  theopen 1 get length theopen 2 get length add 1 add /b array 0
  theopen 1 get fax theopen 2 get fax (/) fax pop
  [
  0 1 checkmarks length 1 sub { /kR name
      checkmarks kR get 0 ne {
          thefilelist kR get 0 get dup length /b array copy 
       } if
    } for
  ]
} bind def

/dictclass {
  /kR 0 def
  theopen 1 get
           { checkmarks kR get 0 ne
             { exch pop } { pop pop } ifelse
             /kR kR 1 add def
           } forall
} bind def

/listclass {
  0 1 checkmarks length 1 sub { /kR name
      checkmarks kR get 0 ne { theopen 1 get kR get } if 
    } for
} bind def

/arrayclass {
  0 1 checkmarks length 1 sub { /kR name
      checkmarks kR get 0 ne { theopen 1 get kR get } if 
    } for
} bind def

end def

end userdict /TheEye put

|------------------------- fire it up --------------------------------

TheEye begin
  screensize /scrH name /scrW name
  [ [ scrW wW sub 10 sub 50 wW wH ]
    strbuf 0 (TheEye: ) fax userdict /myid get fax
      0 exch dup 30 gt {pop 30} if getinterval
    infoline 0 (=> ) fax userdict /myid get fax
      0 exch dup 12 gt {pop 12} if getinterval
    makewindow /wid name pop
  TheEye userdict debug_dict /line get 0 * (/w) text * wid * number
      0 exch getinterval mkact exec put
  [ /faxLpage /faxRpage /getLpage /getRpage ]
     { dup find userdict 3 -1 roll put } forall
  wid true mapwindow
end

| Not yet done:
| - clip excessively long fs strings



