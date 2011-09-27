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
/COMPOSE 200 {

/verbose [
  /quiet ~[
    /debug_msg ~pop
    /loud_msg ~pop
    /medium_msg ~pop
    /quiet_msg ~toconsole
  ] bind makestruct
  /medium ~[
    /debug_msg ~pop
    /loud_msg ~pop
    /medium_msg ~toconsole
    /quiet_msg ~toconsole
  ] bind makestruct
  /loud ~[
    /debug_msg ~pop
    /loud_msg ~toconsole
    /medium_msg ~toconsole
    /quiet_msg ~toconsole
  ] bind makestruct
  /debug ~[
    /debug_msg ~toconsole
    /loud_msg ~toconsole
    /medium_msg ~toconsole
    /quiet_msg ~toconsole
  ] bind makestruct
] makestruct def

/setvolume {dup /volume name verbose exch get ~def forall} bind def
/loud setvolume

/EPSbufsz 1e8 def
/includebufsz 1e6 def

|=============================== Prologue ====================================
|
| This D code has evolved from struct.ps as a tool for making structured
| documents. One original purpose of struct.ps was the typesetting of equations
| and tables. This capability has been maintained but is now delegated to
| LaTEX, which has been integrated into the toolbox. Likewise, graphs formerly
| made by tools in graf.ps are now made by integrated tools of the new system.
| Elements existing in the form of EPS files can be incorporated. This way,
| the new system provides a general toolbox for making notebooks and preparing
| figures for publication.
|
| Note: We use recursion ad nauseam. Expect that the code that you see is
|       only the tip of the iceberg.
|
|
|----------------------------------------- things to do (or not)
|
| - the labeling of scale partitions in 'gpgraf' does not cope with
|   axis ranges that are a small fraction of the offset of the range on
|   the axis (only one decimal is included). One might replace the in-line
|   code for label formatting by a named procedure so that specific
|   manipulation of the format is possible when necessary.
|
|
|============================== Front Ends ==================================
|
| - EPSfigure
| - PDFfigure
|
|
|========================= Making an EPS figure ============================
|
| To make a composite figure in EPS (encapsulated PostScript) format, use
| `EPSfigure':
|
|    EPSpath EPSfile { generator } | --
|
| `path' and `file' direct the output. The `generator' procedure builds the
| composite figure using primitives described below. Some primitives, again,
| take a generator procedure (or a list thereof) for argument, so that a
| tree of generators is formed. The tree of generators produces a hierarchy
| of graphical elements, in a hierarchy of bounding boxes. The alignment
| of the figure elements with respect to one another is handled by a
| (`placement') procedure given as an argument to each primitive.
|
| `EPSfigure' generates an EPS wrapper for the PS code and writes the PS code
| together with a prefix (defining a symbol font and some PS tools) to the
| output file.
|

/EPSfigure {
  /generator name
  /EPSfile name
  /EPSpath name
  /EPSidx 0 def
  /EPSbuf EPSbufsz /b array def
  /includebuf includebufsz /b array def
  /includeidx 0 def
  /xbox 4 /d array def
  /ybox 4 /d array def

|-- phase 1 (logical design)

  (\n) medium_msg (EPS file to write: ) medium_msg EPSfile medium_msg
  (\n) medium_msg

  (\n1) loud_msg
  {~[generator] bind /root name} COMPOSE ~indict phase1 indict

|-- phase 2 (physical design)

  /bbox * 4 /d array copy def
  (\n2) loud_msg
  ~root phase2 indict

|-- phase 3 (EPS code generation)

    |-- insert EPS wrapper, leading part

  (%!PS-Adobe-3.0 EPSF-3.0\n%%BoundingBox: ) faxPS
  {
    * bbox 0 get floor /l ctype * number ( ) fax
    * bbox 1 get floor /l ctype * number ( ) fax
    * bbox 2 get ceil  /l ctype * number ( ) fax
    * bbox 3 get ceil  /l ctype * number (\n) fax
  } genPS
  (%%HiResBoundingBox: ) faxPS
  {
    bbox {
      100 /b array {* 4 -1 roll * number} tostring
      (\(-?[0-9.]+[eE]\)\\+\([0-9]+\)) regex not ~fax {
        4 1 roll pop pop pop ~fax forall
      } ifelse
      ( ) fax
    } forall 1 sub (\n) fax
  } genPS
  (%%DocumentData: Clean7Bit\n%%LanguageLevel: 3\n) faxPS

  |-- insert PS code for setting global parameters and defining symbol font

  PSprefix faxPS
  setlinewidth
  symbolsize setsymbolsize
  ( symbolfont setfont ) faxPS
  (\nsave\n) faxPS | Why? Dunno -- but without it, the image disappears

  |-- assemble PS code of figure

  (\n3) loud_msg
  ~root phase3 indict

  |-- assemble EPS wrapper, trailing part

  (\npop\n) faxPS | See save above
  (%%EOF\n) faxPS

  |-- write EPS output file

  EPSbuf 0 EPSidx getinterval EPSpath EPSfile writefile
  (\n) loud_msg
  (EPS file written: ) medium_msg EPSfile medium_msg (\n) medium_msg
} bind def


|========================= Making an PDF figure ============================
|
| To make a composite figure in PDF (encapsulated for inclusion) format, use
| `PDFfigure':
|
|    PDFpath PDFfile { generator } | --
|
| `path' and `file' direct the output. The `generator' procedure builds the
| composite figure using primitives described below. Some primitives, again,
| take a generator procedure (or a list thereof) for argument, so that a
| tree of generators is formed. The tree of generators produces a hierarchy
| of graphical elements, in a hierarchy of bounding boxes. The alignment
| of the figure elements with respect to one another is handled by a
| (`placement') procedure given as an argument to  each primitive.
|
| `PDFfigure' generates an EPS wrapper for the PS code and writes the PS code
| together with a prefix (defining a symbol font and some PS tools) to the
| output file.  That is then converted to a PDF.
|
| Wolfgang must be doing something funky with saves -- I can't wrap this.

/PDFfigure {
  {
    /pdf_gen  name
    /pdf_file name
    /pdf_path name
    null (eps) tmpfile
    /pdf_nfile name /pdf_ndir name /pdf_fdw name /pdf_fdr name {
      (PDF file to write: ) medium_msg pdf_file medium_msg (\n) medium_msg
      pdf_fdw closefd
      (Tmp: ) loud_msg pdf_ndir loud_msg pdf_nfile loud_msg
      pdf_ndir pdf_nfile /pdf_gen find ~EPSfigure enddict
      /pdf_fdw |{
        pdf_path pdf_file ~wropen inprocess |}
      def
      openlist PROGS /EPSTOPDF get (--hires) (--filter) pdf_fdr pdf_fdw
      {STDERR sh_io_quiet} PROCESSES indict
      (\n) loud_msg
      (PDF file written: ) medium_msg pdf_file medium_msg (\n) medium_msg
    } stopped
    pdf_fdw pdf_fdr {closeifopen closeifopen} PROCESSES indict
    pdf_ndir pdf_nfile rmpath
    ~stop if
  } COMPOSE indict
} bind def

|============== Primitives for creating figure elements ====================
|
| A primitive is implemented in three phases, by procedures associated with
| the primitive's name in three phase-specific dictionaries:

[ /phase1 /phase2 /phase3 ] { 20 dict def } forall

| Phase 1 -  constructs a secondary generator tree while extending the
| original tree by child elements that are generated automatically by certain
| primitives (e.g., a self-labeling graph primitive). Since the tree of
| elements cannot be extended in phases 2 or 3, a primitive generating
| child elements must do the logical design needed to define its offspring
| in phase 1.
|
| D code other than invocations of primitives that is contained in original
| generators is executed only in phase 1 -- it is not passed on to the
| secondary generators. This limits the usage of such code to setting
| representation parameters for the element and its descendents in the
| figure tree. It is irrelevant where in the generator code these parameters
| are set. Their settings are stored in the private dictionary of the
| element that is constructed in phase 1. Phases 2 and 3 use these parameter
| values for all components of the element (including descendents).
|
| Phases 2 and 3 execute the secondary generator procedure. In turn, a
| primitive executed in these phases executes any generator given to it
| as an argument, so that the elements of the tree are executed recursively
| until the leafs have been reached.
|
| Phase 2 - determines the element metrics and lays out the physical design
| of the element. The bounding box of each figure element is determined
| by recursively determining the bounding boxes of the child elements and
| growing the parent's bounding box to comprise those of the children.
| The primitive then designs the physical layout of its own element using the
| known metrics. The map (see below) from this element to its parent is
| constructed.
|
| Phase 3 - the PS code for the graph is synthesized.
|
| The execution of the tree of primitives is traced on the console. Each phase
| starts a new line and a digit. Each step toward the periphery of the tree is
| indicated by `+', and each step in the reverse direction by `-'. Some
| primitives execute the part of the tree peripheral to their position twice;
| the second execution is traced on a new line starting with `space'.

|--------------------- General concepts of primitives ----------------------
|
| We discuss:
|
| - coordinate spaces
| - placement of elements
| - reports
|
|........................... coordinate spaces ..............................
|
| The placement of figure elements is the A and O of a composition. We follow
| the PS model here, but describe the model from scratch because its
| description in the PS reference manual is incorrect, incomplete, and
| misleading. (Don't go there before having assimilated the following!)
|
| Each element of the figure tree has its own coordinate space, so that
| elements can be designed independently of each other. At the origin of
| the tree of coordinate spaces is the coordinate space initially established
| by the PS interpreter. We call this space the `device' space. As coordinate
| spaces are constructed along the figure tree, maps relating tree element
| spaces to their precursors in the tree are constructed. These maps specify
| how corresponding coordinates in the parent space are computed from
| coordinates in the child space. Thus, all maps are pointing backwards, toward
| the root of the figure tree (ultimately, to the device space so that ink can
| be dispatched there). No forward maps are generated as they are not needed.
|
| A map <d a b c d tx ty > specifies the linear transform
|
|   x = a.x' + c.y' + tx
|   y = b.x' + d.y' + ty
|
| computing the coordinates x,y in parent space from given coordinates x',y' in
| child space.
|
| It is useful to write this transform as
|
|   r_k = M_{k+1,k} r_{k+1}
|
| where k is a node in the tree of spaces, and k+1 is a child node of k.
| M_{k+1,k} is the map relating coordinates in k+1 to coordinates in k.
|
| M_{k+1,k} M_{k,k+1} = I because going from child space to parent space and
| back to child space produces the original coordinates in child space. The
| identity map I is <d 1 0 0 1 0 0 >.
|
| Consider the path from child k+2 to a parent k+1 to a grandparent k in a tree:
|
|   r_{k+1} = M_{k+2,k+1} r_{k+2}
|   r_{k} = M_{k+1,k} r{k+1}
|
| Hence,  r_{k} = M_{k+1,k} M_{k+2,k+1} r_{k+2}
|
| Thus, a map from child to grandparent is constructed as the concatenation of
| the maps in going from child to parent, and from parent to grandparent. An
| operator `concat' performs this concatenation; its internal algebra is
| defined by working out two consecutive linear transforms of the form described
| above.
|
| The following equality is easily verified:
|
|  ... M_{k+1,k} M_{k+2,k+1}... = ( ... M_{k+1,k+2} M_{k,k+1} ... )^{-1}
|
| where the exponent `-1' indicates the inverse of the map. Note that the order
| of maps on the RHS is the reverse of that on the LHS.
|
| If one was to construct a sequence of maps leading from the root to the leafs
| of the tree of spaces, one would concatenate maps by multiplying the running
| map `on the left' by the map leading to the next child. PS describes mapping
| as if it were done this way. In truth, PS does exactly what we described
| above: it concatenates the reverse maps. The illusion is possible because
| of the equality of the above map expressions.
|
| With the illusion understood, we can as well enjoy it. For instance, build a
| map by stepwise changing the parent coordinate system into the child
| coordinate system. The following stepwise mapping operators do not require
| you to think in terms of a map per se:
|
| `translate' origin by tx, ty:
|     r_{k} = <d 1 0 0 1 tx ty > r_{k+1}
|
| 'rotate' axis system by ccw angle:
|     r_{k} = <d cos(phi) sin(phi) -sin(phi) cos(phi) 0 0 > r_{k+1}
|
| 'scale' axis units by sx, sy:
|     r_{k} = <d sx 0 0 sy 0 0 > r_{k+1}
|
| A combination of these steps can produce most maps that we need to assemble in
| COMPOSE (an exception are reflections, but you rarely make figures whose
| labels need to be read with the aid of a mirror).
|
| Usage of the map operators:
|
| `concat'            m1 m2 | m1'
| `translate'       m tx ty | m'
| `rotate'        m phi_ccw | m'
| `scale'           m sx sy | m'
|
| where the primes denote modified argument maps returned on the stack.
|

/t1 6 /d array def
/t2 6 /d array def
/t3 6 /d array def

/rads { /d ctype 90.0 div 0.0 acos mul } bind def

/translate { | < 1 0 0 1 tx ty >
  <d 1 0 0 1 0 0 > t3 copy 3 1 roll
  t3 5 put t3 4 put
  concat
} bind def

/rotate { | < cos(phi) sin(phi) -sin(phi) cos(phi) 0 0 >
  0 t3 copy exch
  rads dup sin dup t3 1 put neg t3 2 put
  cos dup t3 0 put t3 3 put
  concat
} bind def

/scale { | < sx 0 0 sy 0 0 >
  0 t3 copy 3 1 roll
  t3 3 put t3 0 put
  concat
} bind def

/concat { /m1 name /m2 name
  m2 0 get m1 0 get mul m2 2 get m1 1 get mul add t1 0 put
  m2 1 get m1 0 get mul m2 3 get m1 1 get mul add t1 1 put
  m2 0 get m1 2 get mul m2 2 get m1 3 get mul add t1 2 put
  m2 1 get m1 2 get mul m2 3 get m1 3 get mul add t1 3 put
  m2 0 get m1 4 get mul m2 2 get m1 5 get mul add m2 4 get add t1 4 put
  m2 1 get m1 4 get mul m2 3 get m1 5 get mul add m2 5 get add t1 5 put
  t1 m2 copy
} bind def

|-------- map:  x' y' map | x y
|         where x',y' are the coordinates in the child space, `map' is
|         the transform map from the child to the parent space, and x,y
|         are the coordinates in the parent space.

/map { /m name /y name /x name
  m 0 get x mul m 2 get y mul add m 4 get add
  m 1 get x mul m 3 get y mul add m 5 get add
} bind def

|............................... placement .................................
|
| Primitives require a placement procedure as argument. The procedure is
| executed in phase 2 (after the bounding box of the element has been
| determined) and generates the map for translating child into parent
| coordinates. The placement procedure is given an identity map on the
| stack in order to  prime the definition of transforms by `translate',
| `rotate', and/or `scale' (of course, you can use `concat' if you know
| your way). Describe the transform as if you are changing coordinate
| space from parent to child in steps:
|
| (1) translate origin from the origin of the parent space to the alignment
|     point in parent space
|
| (2) rotate, scale as needed to match the child space
|
| (3) you are now in `child space', with origin at the alignment
|     point of the parent. If the child's origin is the intended alignment
|     point in child space, no further action is needed (this typically
|     is true for axis systems). Otherwise translate the origin so that the
|     alignment points of child and parent become congruent.
|
| Step 3, when necessary, can often be done using one of the pre-defined
| `alignXY' operators defined below, which align with respect to locations
| on the child's bounding box (typically needed when placing LaTEX text).
|
| Placement transforms coordinate spaces. The primary aspect of placement
| is the alignment of the child with respect to the parent. The alignment
| point of child space is the origin of the child bounding box. The origin
| of the first object produced by the first primitive of the child generator
| becomes the origin of the child object. Dependent on the nature of the
| first primitive, you may or may not want to modify the child origin by
| means of the placement procedure of the first child primitive. To do this
| properly, you need to consult the description of the first primitive to
| be sure how it defines its origin. Typically, you should not modify the
| origin of an axis system (this is chosen to align axes of multi-panel
| graphs without further ado.
| 
| If you use other than the stepwise approaches to placement, recall that
| order matters (the map operations do not commute).
|
| If the primitive is the root primitive of the figure tree, the placement
| is in device space.

|------- make the inverse map (child to parent)

/makeinverse {
  <d 1 0 0 1 0 0 > 6 /d array copy placement /inverse name
} bind def

|------- adjust the parent's current bounding box so that it comprises
|        the child's bounding box (working from the child's dictionary)

/stretchpbbox {
  parent /bbox get /pbbox name
  bbox 0 get bbox 1 get inverse map ybox 0 put xbox 0 put
  bbox 0 get bbox 3 get inverse map ybox 1 put xbox 1 put
  bbox 2 get bbox 1 get inverse map ybox 2 put xbox 2 put
  bbox 2 get bbox 3 get inverse map ybox 3 put xbox 3 put

  xbox 0 get dup xbox extrema
    pbbox 0 get * eq { pbbox 2 put pbbox 0 put }
                     { pbbox 2 get 2 copy lt ~exch if pop pbbox 2 put
                       pbbox 0 get 2 copy gt ~exch if pop pbbox 0 put
                     }
                     ifelse
  ybox 0 get dup  ybox extrema
    pbbox 1 get * eq { pbbox 3 put pbbox 1 put }
                     { pbbox 3 get 2 copy lt ~exch if pop pbbox 3 put
                       pbbox 1 get 2 copy gt ~exch if pop pbbox 1 put
                     }
                     ifelse
} bind def

|--------- aligners
|
| These use the bounding box. If you want finer alignments you need write
| your own (e.g. for placing text with consideration of descenders).
|
| The capital letters define the x and y alignment coordinates (LB = left,
| bottom; CT = center, top).
|
| Usage:  map | map'
|

/alignLB {
  bbox 0 get neg bbox 1 get neg translate
} bind def

/alignLC {
  bbox 0 get neg bbox 1 get bbox 3 get add -0.5 mul translate
} bind def

/alignLT {
  bbox 0 get neg bbox 3 get neg translate
} bind def

/alignCB {
  bbox 0 get bbox 2 get add -0.5 mul bbox 1 get neg translate
} bind def

/alignCC {
  bbox 0 get bbox 2 get add -0.5 mul
  bbox 1 get bbox 3 get add -0.5 mul translate
} bind def

/alignCT {
  bbox 0 get bbox 2 get add -0.5 mul bbox 3 get neg translate
} bind def

/alignRB {
  bbox 2 get neg bbox 1 get neg translate
} bind def

/alignRC {
  bbox 2 get neg bbox 1 get bbox 3 get add -0.5 mul translate
} bind def

/alignRT {
  bbox 2 get neg bbox 3 get neg translate
} bind def

|................................ reports ...................................
|
| A report is a source of information used by primitives to generate graphs.
| The root object of a report is a dictionary.
|
| The following objects, associated with names in a report, are accepted
| by the primitive `gpgraf':
|
|  < >                 - a single array (abscissa or ordinate)
|  [ < > < > ... ]     - a list of ordinate arrays
|  [ < > < > ]         - a list containing an abscissa and an ordinate array
|
| The primitive `fcgraf' accepts
|
|  [ array array matrix map ] - a list containing the horizontal and vertical
|                               independent variables as 1D arrays and the
|                               dependent variable as mapped 2D matrix
|

|........................... graphical symbols ............................
|
| COMPOSE defines a symbolfont that is included to the PS environment in
| which the figure is rendered. Symbols are used to mark points or axis
| partitions in graphs. They are referred to in generators by the names:

/k 0 def  | '\A' and up -- centered symbols
/symbols [
  /dot                 /diamond              /fsquare
  /square              /squareb              /cross
  /times               /filledcircle         /circle
  /circleb             /asterisk             /futriangle
  /fdtriangle          /frtriangle           /fltriangle
  /vbarca              /vbarba               /vbarta
  /hbarca              /hbarla               /hbarra
  /utriangle           /dtriangle            /rtriangle
  /ltriangle
] dup 3 -1 roll name {
  1 /b array dup k 65 add exch 0 put def /k k 1 add def
} forall

/k 0 def  | '\a' and up  -- text version of symbols
/_symbols [
  /_dot                 /_diamond              /_fsquare
  /_square              /_squareb              /_cross
  /_times               /_filledcircle         /_circle
  /_circleb             /_asterisk             /_futriangle
  /_fdtriangle          /_frtriangle           /_fltriangle
  /_vbarca              /_vbarba               /_vbarta
  /_hbarca              /_hbarla               /_hbarra
  /_utriangle           /_dtriangle            /_rtriangle
  /_ltriangle
] dup 3 -1 roll name {
  1 /b array dup k 97 add exch 0 put def /k k 1 add def
} forall

| (path) (file) | --
/output_symbols {
  {
    {
      [
        [symbols {} forall _symbols {} forall] {/sym name
          [
            ~[
              256 /b array {* sym text (: ) fax} tostring
              dup 0 get (_) 0 get eq {
                256 /b array {(\\) fax 3 -1 roll fax} tostring
              } if {alignLC} ~latex
            ]
            ~[
              ~[
                ~gsave 12 0 sym mkact exec ~showsymbol ~grestore
              ] <d 0 -2 24 2> {alignLC} ~PS
            ]
          ]
        } forall
      ] 5 {} panelarray
    } EPSfigure
  } insave
} bind def

| The size of symbols is set by the parameter `symbolsize'. The stroke weight
| of open symbols is given by the `linewidth' parameter.

|--------------------- set line width
|
| (linewidth) -- | --

/setlinewidth {
  linewidth toPS ( setlinewidth\n) faxPS
} bind def

|--------------------- set symbol size
|
| symbolsize | --

/setsymbolsize {
  toPS
  ( /symbolweight exch def
    /symbolfont /Symbols findfont symbolweight scalefont def
    /symbolweight ) faxPS
  linewidth 2000 mul toPS ( symbolweight div def\n ) faxPS
} bind def

|=========================================================================
|
|                           ---  primitives ---
|
|=========================================================================
|
| COMPOSE provides three types of figure primitive:
|
|  1 - forms that themselves do not dispatch ink
|  2 - making LaTEX, EPS, and PS elements
|  3 - graphing data in axis systems
|
| The current set of primitives comprises
|
|  `panel'       (1)
|  `panelarray'  (1)
|  `latex'       (2)
|  `includeEPS'  (2)
|  `PS'          (2)
|  `gpgraf'      (3)
|  `pcgraf'      (3)
|
| The element built by a primitive is safeguarded against interference with
| other elements, but certain graphical parameters can be passed on to
| offspring of an element:
|
| (1) The PS code rendering an element is bracketed by `gsave' and `grestore'
|     so that changes made by the element's PS code to the PS machine and
|     graphics states are localized to the element itself.
|
| (2) The PS code rendering an element is automatically prefixed by PS code
|     establishing the current settings of the parameters
|      - linewidth
|      - symbolsize
|      - textsize
|
|     The element uses the parameter values defined by its own generator,
|     or if it does not define them itself uses the values defined by
|     the nearest ancestor in the element tree (this happens automatically
|     as elements leave their dictionary on the D dictionary stack when they
|     execute the generator for a child element).
|
|---------------------------- default parameters -----------------------------
|
| If you wish to use different defaults globally, redefine these parameters
| in the COMPOSE dictionary:

/linewidth 0.7 def     | general, points
/symbolsize 7 def      | for graphs, points
/textsize 10 def       | for LaTEX (and graphs), points
/letterprefix true def | linear axis label: use letter prefix
                       |   (else power of 10)

/verboxe false def      | switch: outline bounding boxes



|========================== primitive: `panel' =============================
|
| group figure elements into a panel:
|
|     { generator } { placement } | --
|
|
| the generator procedure creates the elements of the panel using as many
| primitives as needed. The origin of the panel's coordinate space will be
| that of the first element generated in the panel. The placement procedure is
| applied to the panel as a whole. A bounding box comprising all panel
| elements is constructed by expanding boundaries with respect to the fixed
| origin.
|

|-------- phase 1:
| - make secondary generator

{
  currentdict {
    /parent name
    /placement name
    (+) loud_msg ~[ exch exec ] /children name (-) loud_msg
    currentdict ~panel     | => secondary generator
  } 20 dict indict
} bind phase1 /panel put


|--------- phase 2:
| - extract metrics
| - compute backtransform and adjust parent bbox

{
  {
    /bbox <d * * * * > 4 /d array copy def
    (+) loud_msg children (-) loud_msg
    makeinverse stretchpbbox
  } exch indict
} bind phase2 /panel put

|--------- phase 3:
| - output placement instruction and children elements

{
  {
    [ ~save inverse ~concat ] { toPS } forall
    (+) loud_msg children (-) loud_msg
    verboxe { bbox toPS ~drawbbox toPS } if
    ~restore toPS
  } exch indict
} bind phase3 /panel put


|======================== primitive: `panelarray' ===========================
|
| create a two-dimensional array of panels:
|
| [ [ { generator } {...} {...} ... ] [ ... ] ... ]  spacing { placement } | --
|
| Generator procedures are organized in a two-dimensional list (by rows
| and row elements). Each generator procedure defines the elements of one
| panel that is automatically generated and placed by `panelarray'. The
| panels are aligned with respect to their origins, and are placed in the array
| space so no two elements in adjacent panels come closer than `spacing' to
| one another (in units of panel array space). The `placement' procedure is
| applied to the panel array as a whole.
|
| Please note that `panelarray' automatically creates one panel for each
| generator in the generator list. The placement of these panels is automatic,
| with no rotations or scalings. If for some reasons your generators need
| rotation or scaling, you can wrap them into a `panel' primitive whose
| placement includes the desired rotation or scaling.
|
| NOTA BENE: if you use `panelarray' to group various graphs generated by
| `gpgraph' and/or `gcgraph' into a composition, provide an empty placement
| procedure to these graph-generating primitives. This will automatically
| align the lower left corners of the axis boxes of the graphs provided
| the graphs are generated as the first element of their panels.
|

|------------------------ phase 1:

{
  currentdict {
    /parent name
    /placement name
    /spacing name
    /genlist name
    currentdict ~panelarray     | => secondary generator
    (+) loud_msg
    /nrows 0 def /ncols 0 def /rowidx 0 def
    [ genlist { /colidx 0 def
      [ exch
        { ~[ ~xaligns colidx ~get ~yaligns rowidx ~get ~translate ] panel
          /colidx colidx 1 add def
          ncols colidx le { /ncols colidx def } if
        } forall
      ]
      /rowidx rowidx 1 add def
      nrows rowidx le { /nrows rowidx def } if
    } forall
    ] /childrenlist name
    (-) loud_msg
  } 100 dict indict
} bind phase1 /panelarray put

|-------------------------- phase 2:

{
  {
    |-- determine the extents of all panel boxes relative to their origins
    /wl 0 ncols /d array copy def
    /wr 0 ncols /d array copy def
    /wb 0 nrows /d array copy def
    /wt 0 nrows /d array copy def
    (+) loud_msg
    /xaligns 0 ncols /d array copy def
    /yaligns 0 nrows /d array copy def
    /bbox 4 /d array def
    /rowidx 0 def
    childrenlist { /rowlist name
      /colidx 0 def
      0 2 rowlist length 2 sub { /childidx name
        rowlist childidx get /child name
        * bbox copy pop  | prime for each child element
        child rowlist childidx 1 add get exec
        bbox 0 get dup wl colidx get lt { wl colidx put } ~pop ifelse
        bbox 1 get dup wb rowidx get lt { wb rowidx put } ~pop ifelse
        bbox 2 get dup wr colidx get gt { wr colidx put } ~pop ifelse
        bbox 3 get dup wt rowidx get gt { wt rowidx put } ~pop ifelse
        /colidx colidx 1 add def
      } for
      /rowidx rowidx 1 add def
    } forall
    (-) loud_msg
    |-- finalize placement of the panel boxes
    0.0 0 1 ncols 1 sub { /colidx name
      wl colidx get sub dup xaligns colidx put
      wr colidx get add spacing add
    } for pop
    0.0 0 1 nrows 1 sub { /rowidx name
      wt rowidx get sub dup yaligns rowidx put
      wb rowidx get add spacing sub
    } for spacing add yaligns exch sub pop | align from top down
    |-- rerun phase2 of subtree to establish correct placements of panel
    |   elements and correct panel array bbox
    * bbox copy pop
    (\n +) loud_msg
    childrenlist { mkact exec } forall
    (-) loud_msg
    |-- establish panel array placement and parent bbox
    makeinverse stretchpbbox
  } exch indict
} bind phase2 /panelarray put


|-------------------------- phase 3:

{
  {
    [ ~save inverse ~concat ] { toPS } forall
    (+) loud_msg
    childrenlist { mkact exec } forall
    (-) loud_msg
    verboxe { bbox toPS ~drawbbox toPS } if
    ~restore toPS
  } exch indict
} bind phase3 /panelarray put



|========================= primitive: `latex' ==============================
|
| Compile and place a string of LaTEX text:
|
| (...LaTEX...) { placement } | --
|
| Typically, text elements are not scaled beyond the choices made in
| the LaTEX source code. The `normal' font size for LaTEX is set by `textsize'
| (which can be 10, 11, or 12 points). The LaTEX environmental variables
| describing the rendering of the text are set to default values that
| usually need not be updated. You can use any LaTEX commands that may appear
| between the \begin{document} and \end{document} statements of a LaTEX
| document to choose specific settings for the LaTEX environment.
|
| The metrics of the text element (bounding box, starting point of the text,
| space used above and below the latter) are defined in the text element's
| dictionary in execution phase 2. Note that the text coordinate system is
| that of a large page, with the text starting near the left edge and top
| of the page (you see that from the coordinates of the bounding box). This
| default placement is hardly ever useful as is, so that `latex' usually
| requires a non-empty placement procedure.
|
| The variable latexpreamble defines a string that is used as the preamble
| for the latex document that generates the eps string. By default, it's
| empty. It can include \usepackage, \def, and so forth. Useful for
| calling \usepackage{verbdef}\verbdef\x|...|, then using \x in the
| main string.

/latexpreamble () def

|-------- phase 1:

{
  currentdict {
    /parent name
    /placement name
    /latexstring name
    | - compile the LaTEX string and extract metrics
    latexpreamble latexstring textsize ~xeps EPS indict /epsstring name
    readDSC
    currentdict ~latex     | =\> secondary generator
  } 30 dict indict
} bind phase1 /latex put


|--------- phase 2:
| - backtransform bbox and adjust parent bbox

{
  {makeinverse stretchpbbox} exch indict
} bind phase2 /latex put

|--------- phase 3:
| - output placement instruction and PS string

{
  {
    [ ~save inverse ~concat ] ~toPS forall
    (\nBeginEPSF\n) faxPS
    DSCoff faxPS (whatever\n) faxPS
    epsstring faxPS
    verboxe { bbox toPS ~drawbbox toPS } if
    DSCon faxPS
    (EndEPSF\n) faxPS
    ~restore toPS
  } exch indict
} bind phase3 /latex put


|========================= primitive: `includeEPS' ===========================
|
| Acquire and place the contents of an EPS file as a figure element:
|
|   epspath epsfile { placement } | --
|
| The origin and bounding box of the EPS object are defined in the preamble of
| the EPS source file and are maintained unless modified by the placement
| procedure.

|-------- phase 1:
|
| - read the EPS file into the `include' buffer

{
  currentdict {
    /parent name
    /placement name
    includebuf includeidx includebuf length includeidx sub getinterval
    readfile /epsstring name
    includeidx epsstring length add COMPOSE /includeidx put
    readDSC
    currentdict ~includeEPS     | => secondary generator
  } 30 dict indict
} bind phase1 /includeEPS put

|--------- phase 2:

| - backtransform bbox and adjust parent bbox

{
  {makeinverse stretchpbbox} exch indict
} bind phase2 /includeEPS put

|--------- phase 3:

| - output placement instruction and PS string

{
  {
    (\nBeginEPSF\n) faxPS
    DSCoff faxPS (whatever\n) faxPS
    [ ~save inverse ~concat ] ~toPS forall
    epsstring faxPS
    verboxe { bbox toPS ~drawbbox toPS } if
    ~restore toPS
    DSCon faxPS
    (EndEPSF\n) faxPS
  } exch indict
} bind phase3 /includeEPS put


|============================== primitive: PS ==============================
|
| Include artwork directly encoded in PostSript:
|
|  { artwork } bbox { placement } | --
|
| The artwork is presented as a D procedure that is translated into its PS
| equivalent and, following placement, is included in the (E)PS code
| generated by phase 3. `PS' thus gives you the ultimate freedom to create
| whatever artwork your figure requires beyond the standard figure elements.
| `PS' does not itself compute a bounding box: you need to supply the
| expected bounding box of your artwork, so that it can be properly placed.
| Since you define the bounding box (and its origin) by yourself, the option
| of using addintional placement instructions is typically not used.
|
| As much as `latex' gives you the full services of the LaTEX engine, `PS'
| opens the PostScript engine for you.
|

|------------------------------- phase 1

{
  currentdict {
    /parent name
    /placement name
    /bbox name
    /postscript name
    currentdict ~PS   | =\> secondary generator
  } 100 dict indict
} bind phase1 /PS put

|------------------------------- phase 2

{
  {makeinverse stretchpbbox} exch indict
} bind phase2 /PS put

|------------------------------- phase 3

{
  {
    (\nBeginEPSF\n) faxPS
    DSCoff faxPS (whatever\n) faxPS
    [ ~save inverse ~concat ] ~toPS forall
    setlinewidth
    symbolsize setsymbolsize
    ( symbolfont setfont ) faxPS
    [ /postscript find ~exec ] ~toPS forall
    verboxe { bbox toPS ~drawbbox toPS } if
    ~restore toPS
    DSCon faxPS
    (EndEPSF\n) faxPS
  } exch indict
} bind phase3 /PS put



|============================ primitive: `gpgraf' ==========================
|
| `gpgraf' generates a `general-purpose graph' from a report:
|
|   report [ [ name(s) {..} ]..] abs ord xdim ydim  { placement } | --
|
| the list argument specifies the report data to be included. Each data set
| is selected by one or two names that refer to data objects in the `report'.
| If two names are given, the first specifies a single abscissa array, and
| the second name either a single ordinate array or a list of ordinate
| arrays that share the abscissa array. If only one name is given, it
| selects a list holding an abscissa and an ordinate array.
|
| The procedure following the array name(s) controls the representation
| of the data, using the operators:
|
| `ps'                  [.. ] | --
| 'Line'                   -- | --
| `Points'             symbol | --
|
| `ps' translates the elements of its list argument into PS analogs and
| includes them into the EPS output. The PS code usually modifies PS graphical
| settings from their standard settings. The standard settings conform
| to the default graphics state of the PS engine, which is restored prior
| to drawing each data set (thus standard settings need not be explicitly
| specified). Consult the PS manual for operators to set representation
| options like color, gray shade, dash pattern, etc.
|
| If ordinates are given as a list of arrays, the presentation procedure is
| called for each array and given the index of the array in the variable
| Yidx. You can use the index to set up shared PS graphics settings only
| once (for index 0 -- they will apply to the whole set of ordinates) and
| use the index to step through variations of the presentation as successive
| ordinate arrays are plotted (like color or gray shade of a line).
|
| `Line' interconnects the data by a line, whereas `Points' places the
| centered symbol at every data point.
|
| If you wish to combine line and symbol representations of data sets
| in the graph, specifiy all lines first (so they do not overlay symbols).
| You can include the same data set twice, plotted as line, then symbols.
|
| `xdim' and `ydim' specify the dimensions (in points) to be spanned by
| the axis system described by `abs' and `ord'. The bounding box of the graph
| will be larger than the axis box as it usually comprises the labels
| automatically added to the axis system and always an alottment of space for
| symbols that might extend beyond the axes.
|
|  `abs'  - [ scan min max type unit descr ]    - directs design of
|                                                    abscissa axis
|  `ord'  - [ scan min max type unit descr ]    - directs design of
|                                                    ordinate axis
| Axis design is directed by
|
|  scan      - boolean, enables scan for axis limits
|  min, max  - extrema (if `scan' enabled, these prime the extrema unless
|              they are specified as `undefined' value
|  type      - /lin (linear) or /log (logarithmic)  ...to be extended
|  unit      - LaTEX string, used in unit specification added to description
|  descr     - LaTEX string, description of axis
|
| A shortened axis description list, including only the first 4 elements,
| will generate an unlabelled axis (useful for multi-panel gpgraphs with
| identical axes).
|
| The axis system is plotted as a stroked box with inward pointing scale
| marks on all margins. Labels appear left of and below the box. Axis
| descriptions are complemented by '/', power of ten, and the unit (with
| the denominator in parentheses if necessary).
|
| The lower left corner of the axis box is also the origin of the physical
| coordinate space of this figure element (important if you want to add
| your own enhancements). Note that using an `alignXY' command inside
| the placement procedure of `gpgraf' will shift the origin of the gpgraf
| box.
|
| Labels are generated as LaTEX figure elements (appended to the figure
| tree). They use the text font size specified in parameter `textsize'
| as that of the `normal' LaTEX font.
|
| The graph is placed as specified by the `placement' procedure into its
| parent element.
|
| NOTA BENE: if you use `panelarray' to group various graphs generated by
| `gpgraph' and/or `gcgraph' into a composition, provide an empty placement
| procedure to these graph-generating primitives. This will automatically
| align the lower left corners of the axis boxes of the graphs provided
| the graphs are generated as the first element of their panels.
|

|------------------------------------------ gpgraf, phase 1

{
  currentdict {
    /parent name
    /placement name
    /d ctype /ydim name /d ctype /xdim name
    /ordinate name /abscissa name
    /selection name
    /report name

    currentdict ~gpgraf  | =\> secondary generator

    |-- find logical ranges  of axes

    abscissa dup 0 get /scanX name
      dup 1 get /minX name 2 get /maxX name
    ordinate dup 0 get /scanY name
      dup 1 get /minY name 2 get /maxY name
    selection { /selitem name
      report selitem 0 get get
      dup class /arrayclass eq {/X name
        report selitem 1 get get
        dup class /listclass ne { [ exch ] } if /Ys name
      } {
        dup 0 get /X name 1 get [ exch ] /Ys name
      } ifelse
      scanXYs
    } forall

    |-- design the logical axes

    gpXdesigners abscissa 3 get get exec
    gpYdesigners ordinate 3 get get exec

    |-- construct generator of label elements

    /children ~[
      abscissa length 6 eq { gpXlabels abscissa 3 get get exec } if
      ordinate length 6 eq { gpYlabels ordinate 3 get get exec } if
    ] bind def
  } 100 dict indict
} bind phase1 /gpgraf put

|--------------------------------------------- gpgraf, phase 2

{
  {
    |-- prime bounding box

    /bbox 0 4 /d array copy def
    symbolsize linewidth add 2 div dup
    neg dup bbox 0 put bbox 1 put 
    dup xdim add bbox 2 put ydim add bbox 3 put

    (+) loud_msg children (-) loud_msg
    makeinverse stretchpbbox
  } exch indict
} bind phase2 /gpgraf put

|--------------------------------------------- gpgraf, phase 3

{
  {
    [ ~save inverse ~concat ] { toPS } forall
    setlinewidth
    symbolsize setsymbolsize
    ( symbolfont setfont ) faxPS
    (+) loud_msg children (-) loud_msg

    ~save toPS gpXplotters abscissa 3 get get exec ~restore toPS
    ~save toPS gpYplotters ordinate 3 get get exec ~restore toPS

    selection { /selitem name
      selitem length 2 gt {
        report selitem 0 get get /X name
        report selitem 1 get get dup class /arrayclass eq { [ exch ] } if
          /Ys name
        selitem 2 get /pres name
      } {
        report selitem 0 get get 0 get /X name
        report selitem 0 get get 1 get [ exch ] /Ys name
        selitem 1 get /pres name
      } ifelse
      /Yidx 0 def
      ~save toPS
      Ys length { pres /Yidx Yidx 1 add def } repeat
      ~restore toPS
    } forall

    verboxe { bbox toPS ~drawbbox toPS } if
    ~restore toPS
  } exch indict
} bind phase3 /gpgraf put


|------------------------ support for gpgraf -----------------------------

|-------------- scan X, Ys
|
/scanXYs {
   scanX {
     minX * eq { /minX X 0 get def } if
     maxX * eq { /maxX X 0 get def } if
     minX maxX X extrema /maxX name /minX name
   } if
   scanY {
     minY * eq { Ys 0 get 0 get /minY name } if
     maxY * eq { Ys 0 get 0 get /maxY name } if
     Ys {minY maxY 3 -1 roll extrema /maxY name /minY name} forall
   } if
} bind def

|--------------- design gp axes

/gpXdesigners {
  /log {
    minX maxX DesignLg10Axis /Xaxis name
    { lg } { 10.0 exch exp } Xaxis 0 get  Xaxis 1 get
    0.0 xdim DefXTransform
  }

  /lin {
    minX maxX DesignLinearAxis /Xaxis name
    { } { } Xaxis 0 get  Xaxis 1 get
    0.0 xdim DefXTransform
  }
} bind makestruct def

/gpYdesigners {
  /log {
    minY maxY DesignLg10Axis /Yaxis name
    { lg } { 10.0 exch exp } Yaxis 0 get  Yaxis 1 get
    0.0 ydim DefYTransform
  }

  /lin {
    minY maxY DesignLinearAxis /Yaxis name
    { } { } Yaxis 0 get  Yaxis 1 get
    0.0 ydim DefYTransform
  }
} bind makestruct def

|--------------- construct gp abscissa labels
| (we use the expansion of the pbbox by the numerical axis labels
| to place the global axis label)

/gpXlabels {
  /lin {
    Xaxis 2 get Xaxis 3 get div labelformatter
    Xaxis 1 get Xaxis 0 get sub Xaxis 2 get div 0.5 add /l ctype
    0 1 3 -1 roll { Xaxis 2 get exch mul Xaxis 0 get add /xtick name
      10 /b array 0 ($) fax
      |-- scale by unit and round to fixed point with one decimal
      xtick Xaxis 3 get div numberlabel
      ($) fax 0 exch getinterval
      |-- center on xtick, top adjust half a line below axis
      ~[
        xtick ~X_to_x textsize -0.5 mul ~translate
        ~alignCT
      ] latex
    } for
    |-- place descr /unit axis label
    Xaxis 3 get abscissa 5 get abscissa 4 get LinAxisLabel
    ~[
      0.5 xdim mul
      ~parent /bbox ~get 1 ~get textsize 0.5 mul ~sub ~translate
      ~alignCT
    ] latex
  }

  /log {
    Xaxis 2 get { /xtick name
        |-- represent as power of 10
        10 /b array 0 ($) fax
        xtick PowerOfTen ($) fax 0 exch getinterval
        ~[ xtick X_to_x textsize -1.5 mul ~translate
           ~alignCB
         ] latex
    } forall
    |-- place descr/unit axis label
    100 /b array 0 abscissa 5 get fax
        ( / ) fax abscissa 4 get fax 0 exch getinterval
    ~[
      xdim 0.5 mul
      ~parent /bbox ~get 1 ~get textsize 0.5 mul ~sub ~translate
      ~alignCT
    ] latex
  }
} bind makestruct def

/gpYlabels {
  /lin {
    Yaxis 2 get Yaxis 3 get div labelformatter
    Yaxis 1 get Yaxis 0 get sub Yaxis 2 get div 0.5 add /l ctype
    0 1 3 -1 roll { Yaxis 2 get exch mul Yaxis 0 get add /ytick name
        10 /b array 0 ($) fax
        |-- scale by unit and round to fixed point with one decimal
        ytick Yaxis 3 get div numberlabel
          ($)fax 0 exch getinterval
        ~[
          textsize -0.5 mul ytick ~Y_to_y ~translate
          ~alignRC
         ] latex
    } for
    |-- place descr/power unit axis label
    Yaxis 3 get ordinate 5 get ordinate 4 get LinAxisLabel
    ~[
      ~parent /bbox ~get 0 ~get textsize 0.5 mul ~sub
       0.5 ydim mul ~translate
       90.0 ~rotate
       ~alignCB
    ] latex
  }

  /log {
    Yaxis 2 get { /ytick name
        |-- represent as power of 10
        10 /b array 0 ($) fax
        ytick PowerOfTen ($) fax 0 exch getinterval
        |-- 0.5 line to the left, center on ytick
        ~[ textsize -0.5 mul ytick ~Y_to_y ~translate
           ~alignRC
         ] latex
    } forall
    |-- place descr/unit axis label
    100 /b array 0 ordinate 5 get fax
        ( / ) fax ordinate 4 get fax 0 exch getinterval
    ~[ ~parent /bbox ~get 0 ~get textsize 0.5 mul ~sub
       ydim 0.5 mul ~translate
       90 ~rotate
       ~alignCB
     ] latex
  }
} bind makestruct def

|--------------- gp axis plotters

/gpXplotters {
  /log {
    symbolsize setsymbolsize
    ( gsave symbolfont setfont newpath 2 setlinecap ) faxPS
    Xaxis 0 get X_to_x toPS 0.0 toPS ~moveto toPS
    Xaxis 1 get X_to_x toPS 0.0 toPS ( lineto stroke ) faxPS
    ( newpath ) faxPS
    Xaxis 0 get X_to_x toPS ydim toPS ( moveto ) faxPS
    Xaxis 1 get X_to_x toPS ydim toPS ( lineto stroke ) faxPS
    /symbol vbarba def
    Xaxis 2 get {
        X_to_x toPS 0.0 toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
      } forall
    /symbol vbarta def
    Xaxis 2 get {
        X_to_x toPS ydim toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
      } forall

    symbolsize 0.6 mul setsymbolsize
    ( symbolfont setfont ) faxPS
    /symbol vbarba def
    Xaxis 3 get {
        X_to_x toPS 0.0 toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
      } forall
    /symbol vbarta def
    Xaxis 3 get {
        X_to_x toPS ydim toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
      } forall
    ( grestore ) faxPS
  }

  /lin {
    symbolsize setsymbolsize
    ( gsave symbolfont setfont newpath 2 setlinecap ) faxPS
    Xaxis 0 get  X_to_x toPS 0.0 toPS ~moveto toPS
    Xaxis 1 get  X_to_x toPS 0.0 toPS ( lineto stroke ) faxPS
    /symbol vbarba def
    Xaxis 0 get  Xaxis 2 get  Xaxis 1 get {
        X_to_x toPS 0.0 toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
    } for
    ( newpath ) faxPS
    Xaxis 0 get  X_to_x toPS ydim toPS ~moveto toPS
    Xaxis 1 get  X_to_x toPS ydim toPS ( lineto stroke ) faxPS
    /symbol vbarta def
    Xaxis 0 get  Xaxis 2 get  Xaxis 1 get {
        X_to_x toPS ydim toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
    } for
    ( grestore ) faxPS
  }
} bind makestruct def

/gpYplotters {
  /log {
    symbolsize setsymbolsize
    ( gsave symbolfont setfont newpath 2 setlinecap ) faxPS
    0.0 toPS Yaxis 0 get Y_to_y toPS  ( moveto ) faxPS
    0.0 toPS Yaxis 1 get Y_to_y toPS  ( lineto stroke ) faxPS
    ( newpath ) faxPS
    xdim toPS Yaxis 0 get Y_to_y toPS  ( moveto ) faxPS
    xdim toPS Yaxis 1 get Y_to_y toPS  ( lineto stroke ) faxPS
    /symbol hbarla def
    Yaxis 2 get {
        0.0 toPS Y_to_y toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
    } forall
    /symbol hbarra def
    Yaxis 2 get {
        xdim toPS Y_to_y toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
      } forall

    symbolsize 0.6 mul setsymbolsize
    ( symbolfont setfont ) faxPS
    /symbol hbarla def
    Yaxis 3 get {
        0.0 toPS Y_to_y toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
      } forall
    /symbol hbarra def
    Yaxis 3 get {
        xdim toPS Y_to_y toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
      } forall
    ( grestore ) faxPS
  }

  /lin {
    symbolsize setsymbolsize
    ( gsave symbolfont setfont newpath 2 setlinecap ) faxPS
    0.0 toPS Yaxis 0 get  Y_to_y toPS  ( moveto ) faxPS
    0.0 toPS Yaxis 1 get  Y_to_y toPS  ( lineto stroke ) faxPS
    /symbol hbarla def
    Yaxis 0 get  Yaxis 2 get  Yaxis 1 get {
      0.0 toPS Y_to_y toPS ( moveto ) faxPS
      symbol toPS ( show ) faxPS
    } for
    ( newpath ) faxPS
    xdim toPS Yaxis 0 get  Y_to_y toPS  ( moveto ) faxPS
    xdim toPS Yaxis 1 get  Y_to_y toPS  ( lineto stroke ) faxPS
    /symbol hbarra def
    Yaxis 0 get  Yaxis 2 get  Yaxis 1 get {
        xdim toPS Y_to_y toPS ( moveto ) faxPS
        symbol toPS ( show ) faxPS
    } for
    ( grestore ) faxPS
  }
} bind makestruct def

|------------------------------ presentation operators

|------------- ps:  [... ] | --

/ps {
  { toPS } forall
} bind def

|------------- Line: -- | --

/Line {
  ~gsave toPS ~newpath toPS
  0 1 X length 1 sub { /k name
      X k get X_to_x toPS Ys Yidx get k get Y_to_y toPS
      k 0 eq {~moveto} {~lineto} ifelse toPS
  } for
  ~stroke toPS
  ~grestore toPS
} bind def

|------------- Points:  symbol | --

/Points { /symbol name
  ~gsave toPS
  symbolsize setsymbolsize
  ( symbolfont setfont ) faxPS
  0 1 X length 1 sub { /k name
      X k get X_to_x toPS Ys Yidx get k get Y_to_y toPS
      symbol toPS ~showsymbol toPS
  } for
  ~grestore toPS
} bind def

|============================ primitive: `pcgraf' ==========================
|
| `pcgraf' generates a `pseudocolor graph' from a `report':
|
|   report name abs ord color xdim ydim  { placement } | --
|
| the name argument specifies the list in `report' that specifies the arrays
| of the horizontal and vertical independent variables, as well as the
| dependent variable to be represented in the pseudocolor dimension. The
| horizontal and vertical independent variable values are stored in simple
| arrays (as the abscissae and ordinates of one row and one column,
| respectively). The variable of the pseudocolor dimension is specified
| by a matrix followed by its map (outer: row; inner:column).
|
| `xdim' and `ydim' specify the dimensions (in points) to be spanned by
| the axis system described by `abs' and `ord'. The bounding box of the graph
| will be larger than the axis box as it comprises the labels automatically
| added to the axis system plus a color calibration axis plotted on the right
| hand side and outside of the xdim,ydim box.
|
|  `abs'   - [ scan min max type unit descr ]    - directs design of
|                                                    abscissa axis
|  `ord'   - [ scan min max type unit descr ]    - directs design of
|                                                    ordinate axis
|  `color' - [ scan min max type unit descr ]    - directs design of
|                                                    pseudocolor axis
| Axis design is directed by
|
|  scan      - boolean, enables scan for axis limits
|  min, max  - extrema (if `scan' enabled, these prime the extrema unless
|              they are specified as `undefined' value
|  type      - /lin (linear) or /log (logarithmic)  ...to be extended
|  unit      - LaTEX string, used in unit specification added to description
|  descr     - LaTEX string, description of axis
|
| A shortened axis description list, including only the first 4 elements,
| will generate an unlabeled axis (useful for multi-panel pcgraphs with
| identical axes). If the `color' axis is shortened, the color calibration
| bar is omitted altogether.
|
| The x,y axis system is plotted as a stroked box with inward pointing scale
| marks on all margins. Labels appear left of and below the box. Axis
| descriptions are complemented by '/', power of ten (boolean `letterprefix'
| selects between letter or numeral representation), and the unit (with the
| denominator in parentheses if necessary).
|
| The lower left corner of the axis box is also the origin of the physical
| x,y coordinate space of this figure element (important if you want to add
| your own enhancements). Note that using an `alignXY' command inside
| the placement procedure of `pcgraf' will shift the origin of the pcgraf
| box.
|
| The pseudocolors are generated automatically so that the range between
| `min' and `max' of the color axis is mapped on the spectral colors ranging
| between purple and red. A vertical color bar is shown on the right hand
| side of the x,y area together with a labeled axis.
|
| Labels are generated as LaTEX figure elements (appended to the figure
| tree). They use the text font size specified in parameter `textsize'
| as that of the `normal' LaTEX font.
|
| The graph is placed as specified by the `placement' procedure into its
| parent element.
|
| NOTA BENE: if you use `panelarray' to group various graphs generated by
| `gpgraph' and/or `gcgraph' into a composition, provide an empty placement
| procedure to these graph-generating primitives. This will automatically
| align the lower left corners of the axis boxes of the graphs provided
| the graphs are generated as the first element of their panels.
|

|------------------------------------------ pcgraf, phase 1

{
  currentdict {
    /parent name
    /placement name
    /d ctype /ydim name /d ctype /xdim name
    /color name /ordinate name /abscissa name
    /selection name
    /report name

    currentdict ~pcgraf  | =\> secondary generator

    |-- build pseudocolor space

    makepseudocolors

    |-- find logical ranges  of axes

    abscissa dup 0 get /scanX name
      dup 1 get /minX name 2 get /maxX name
    ordinate dup 0 get /scanY name
      dup 1 get /minY name 2 get /maxY name
    color dup 0 get /scanZ name
      dup 1 get /minZ name 2 get /maxZ name
    report selection get dup 0 get /X name
      dup 1 get /Y name dup 2 get /Z name 3 get /Zmap name
      Z 0 Zmap 0 get getinterval /Z name  | clip garbage
    scanX {
      minX * eq { /minX X 0 get def } if
      maxX * eq { /maxX X 0 get def } if
      minX maxX X extrema /maxX name /minX name
    } if
    scanY {
      minY * eq { Y 0 get /minY name } if
      maxY * eq { Y 0 get /maxY name } if
      minY maxY Y extrema /maxY name /minY name
    } if
    scanZ {
      minZ * eq { /minZ Z 0 get def } if
      maxZ * eq { /maxZ Z 0 get def } if
      minZ maxZ Z extrema /maxZ name /minZ name
    } if

    |-- design the logical axes

    gpXdesigners abscissa 3 get get exec
    gpYdesigners ordinate 3 get get exec
    pcZdesigners color 3 get get exec

    |-- construct generator of label elements

    /children ~[
      abscissa length 6 eq { gpXlabels abscissa 3 get get exec } if
      ordinate length 6 eq { gpYlabels ordinate 3 get get exec } if
      color length 6 eq { pcZlabels color 3 get get exec } if
    ] bind def
  } 100 dict indict
} bind phase1 /pcgraf put

|--------------------------------------------- pcgraf, phase 2
| The stretching of the graph box beyond xdim,ydim is done implicitly,
| by the label of the color calibration bar

{
  {
    |-- prime bounding box

    /bbox 0 4 /d array copy def
    symbolsize linewidth add 2 div dup
    neg dup bbox 0 put bbox 1 put 
    dup xdim add bbox 2 put ydim add bbox 3 put

    (+) loud_msg children (-) loud_msg
    makeinverse stretchpbbox
  } exch indict
} bind phase2 /pcgraf put

|--------------------------------------------- pcgraf, phase 3

{
  {
    [ ~save inverse ~concat ] { toPS } forall
    setlinewidth
    symbolsize setsymbolsize
    ( symbolfont setfont ) faxPS
    (+) loud_msg children (-) loud_msg

    /Nrows Zmap 0 get Zmap 1 get div def
    /Ncols Zmap 1 get def
    ~save toPS
    [ /CIEBasedABC colordict ] toPS ~setcolorspace toPS
    0 1 Nrows 2 sub { /krow name
      Y krow get /yb name Y krow 1 add get /yt name
      0 1 Ncols 2 sub { /kcol name
        X kcol get /xl name X kcol 1 add get /xr name
        Z Zmap krow ss pop kcol get
        Z Zmap krow 1 add ss pop kcol get add
        Z Zmap krow ss pop kcol 1 add get add
        Z Zmap krow 1 add ss pop kcol 1 add get add
        4 div C_to_c /zpix name
        renderpix
      } for
    } for
    ~restore toPS

    color length 6 eq {
        ~save toPS
        [ /CIEBasedABC colordict ] toPS ~setcolorspace toPS
        /xl xdim 1.1 mul x_to_X def  /xr xdim 1.2 mul x_to_X def
        /delz Zaxis 1 get Zaxis 0 get sub 99.0 div def
        0 1 98 { /krow name
          Zaxis 0 get delz krow mul add /zpix name
          /yb zpix Z_to_z y_to_Y def
          /yt zpix delz add Z_to_z y_to_Y def
          /zpix zpix C_to_c def
          renderpix
        } for
        ~restore toPS
      } if

    ~save toPS gpXplotters abscissa 3 get get exec ~restore toPS
    ~save toPS gpYplotters ordinate 3 get get exec ~restore toPS
    color length 6 eq {
        ~save toPS pcZplotters color 3 get get exec ~restore toPS
      } if

    verboxe { bbox toPS ~drawbbox toPS } if
    ~restore toPS
  } exch indict
} bind phase3 /pcgraf put


|--------------- design pcgraf color axis (maps z range onto color table)

/pcZdesigners {
  /log {
    minZ maxZ DesignLg10Axis /Zaxis name
    { lg } { 10.0 exch exp } Zaxis 0 get  Zaxis 1 get
    2 copy 0.0 ydim DefineTrans /z_to_Z name /Z_to_z name
    0.0 Npc 2 sub /d ctype DefineTrans /c_to_C name /C_to_c name
  }

  /lin {
    minZ maxZ DesignLinearAxis /Zaxis name
    { } { } Zaxis 0 get  Zaxis 1 get
    4 copy 0.0 ydim DefineTrans /z_to_Z name /Z_to_z name
    0.0 Npc 2 sub /d ctype DefineTrans /c_to_C name /C_to_c name
  }
} bind makestruct def

/pcZlabels {
  /lin {
    Zaxis 2 get Zaxis 3 get div labelformatter
    Zaxis 1 get Zaxis 0 get sub Zaxis 2 get div 0.5 add /l ctype
    0 1 3 -1 roll { Zaxis 2 get exch mul Zaxis 0 get add /ztick name
      10 /b array 0 ($) fax
      |-- scale by unit and round to fixed point with one decimal
      ztick Zaxis 3 get div numberlabel
      ($)fax 0 exch getinterval
      ~[
        ~xdim 1.2 ~mul textsize 0.5 mul ~add
        ztick ~Z_to_z ~translate
        ~alignLC
      ] latex
    } for
    |-- place descr/power unit axis label
    Zaxis 3 get color 5 get color 4 get LinAxisLabel
    ~[
      ~parent /bbox ~get 2 ~get textsize 0.5 mul ~add
      0.5 ydim mul ~translate
      90.0 ~rotate
      ~alignCT
    ] latex
  }

  /log {
    Zaxis 2 get { /ztick name
      |-- represent as power of 10
      10 /b array 0 ($) fax
      ztick PowerOfTen ($) fax 0 exch getinterval
      |-- 0.5 line to the left, center on ytick
      ~[ textsize -0.5 mul ztick ~Z_to_z ~translate
        ~alignLC
      ] latex
    } forall
    |-- place descr/unit axis label
    100 /b array 0 color 5 get fax
    ( / ) fax color 4 get fax 0 exch getinterval
    ~[ ~parent /bbox ~get 0 ~get textsize 0.5 mul ~sub
      ydim 0.5 mul ~translate
      90 ~rotate
      ~alignCT
    ] latex
  }
} bind makestruct def

|------------------------------------- render pseudocolor pixel
| (xl,xr,yb,yt,zpix} -- | --
| Coordinates are in logical units, except zpix, which is in physical
| units.

/renderpix {
  ~newpath toPS
  xl X_to_x toPS yb Y_to_y toPS ~moveto toPS
  xl X_to_x toPS yt Y_to_y toPS ~lineto toPS
  xr X_to_x toPS yt Y_to_y toPS ~lineto toPS
  xr X_to_x toPS yb Y_to_y toPS ~lineto toPS
  ~closepath toPS
  /zpix zpix 1 add def | shift  in color table for interpolations
  pcX zpix ceil get pcX zpix floor get sub
      zpix dup floor sub mul pcX zpix floor get add toPS
  pcY zpix ceil get pcY zpix floor get sub
      zpix dup floor sub mul pcY zpix floor get add toPS
  pcZ zpix ceil get pcZ zpix floor get sub
      zpix dup floor sub mul pcZ zpix floor get add toPS
  ~setcolor toPS
  ~fill toPS
} bind def

/pcZplotters {
  /log {
    symbolsize setsymbolsize
    ( gsave symbolfont setfont newpath 2 setlinecap ) faxPS
    xdim 1.2 mul toPS Zaxis 0 get Z_toz toPS  ( moveto ) faxPS
    xdim 1.2 mul toPS Zaxis 1 get Z_to_z toPS  ( lineto stroke ) faxPS
    /symbol hbarra def
    Zaxis 2 get {
      xdim 1.2 mul toPS Z_to_z toPS ( moveto ) faxPS
      symbol toPS ( show ) faxPS
    } forall
    symbolsize 0.6 mul setsymbolsize
    ( symbolfont setfont ) faxPS
    /symbol hbarra def
    Yaxis 3 get {
      xdim 1.2 mul toPS Z_to_z toPS ( moveto ) faxPS
      symbol toPS ( show ) faxPS
    } forall
    ( grestore ) faxPS
  }

  /lin {
    symbolsize setsymbolsize
    ( gsave symbolfont setfont newpath 2 setlinecap ) faxPS
    xdim 1.2 mul toPS Zaxis 0 get  Z_to_z toPS  ( moveto ) faxPS
    xdim 1.2 mul toPS Zaxis 1 get  Z_to_z toPS  ( lineto stroke ) faxPS
    /symbol hbarra def
    Zaxis 0 get  Zaxis 2 get  Zaxis 1 get {
      xdim 1.2 mul toPS Z_to_z toPS ( moveto ) faxPS
      symbol toPS ( show ) faxPS
    } for
    ( grestore ) faxPS
  }
} bind makestruct def

|---------------------------------------- pseudocolors
| We use the CIE31 color model. Spectral color weights  are produced by
| sampling the x_bar, y_bar, and z_bar functions tabulated below.
| Using no interpolation, we have 95 discrete spectral colors
| (from purple to red) upon which we map the Z range of the data. We
| actually use only a subset so that the physical rendering is not
| challenged beyond its gamut (old start: 48).

/makepseudocolors {
  /Npc 200 4 div def
  /pcX Npc /d array def
  /pcY Npc /d array def
  /pcZ Npc /d array def
  CIEfunctions 60 200 getinterval 1 4 pcX extract pop
  CIEfunctions 60 200 getinterval 2 4 pcY extract pop
  CIEfunctions 60 200  getinterval 3 4 pcZ extract pop
  /XYZrange [ 0.0 0.0 pcX extrema 0.0 0.0 pcY extrema 0.0 0.0 pcZ extrema ] def
  /colordict 10 dict {
    /RangeABC XYZrange def
    /RangeLMN XYZrange def
    /WhitePoint [ 1 1 1 ] def
  } 1 index indict def
} bind def

/CIEfunctions <d
       360 0.0001299 3.917E-06 0.0006061
       365 0.0002321 6.965E-06  0.001086
       370 0.0004149 0.00001239  0.001946
       375 0.0007416 0.00002202  0.003486
       380  0.001368  0.000039   0.00645
       385  0.002236  0.000064 0.01054999
       390  0.004243   0.00012 0.02005001
       395   0.00765  0.000217   0.03621
       400   0.01431  0.000396 0.06785001
       405   0.02319   0.00064    0.1102
       410   0.04351   0.00121    0.2074
       415   0.07763   0.00218    0.3713
       420   0.13438     0.004    0.6456
       425   0.21477    0.0073 1.0390501
       430    0.2839    0.0116    1.3856
       435    0.3285   0.01684   1.62296
       440   0.34828     0.023   1.74706
       445   0.34806    0.0298    1.7826
       450    0.3362     0.038   1.77211
       455    0.3187     0.048    1.7441
       460    0.2908      0.06    1.6692
       465    0.2511    0.0739    1.5281
       470   0.19536   0.09098   1.28764
       475    0.1421    0.1126    1.0419
       480   0.09564   0.13902 0.8129501
       485 0.05795001    0.1693    0.6162
       490   0.03201   0.20802   0.46518
       495    0.0147    0.2586    0.3533
       500    0.0049     0.323     0.272
       505    0.0024    0.4073    0.2123
       510    0.0093     0.503    0.1582
       515    0.0291    0.6082    0.1117
       520   0.06327      0.71 0.07824999
       525    0.1096    0.7932 0.05725001
       530    0.1655     0.862   0.04216
       535 0.2257499 0.9148501   0.02984
       540    0.2904     0.954    0.0203
       545    0.3597    0.9803    0.0134
       550 0.4334499 0.9949501   0.00875
       555 0.5120501         1   0.00575
       560    0.5945     0.995    0.0039
       565    0.6784    0.9786   0.00275
       570    0.7621     0.952    0.0021
       575    0.8425    0.9154    0.0018
       580    0.9163      0.87   0.00165
       585    0.9786    0.8163    0.0014
       590    1.0263     0.757    0.0011
       595    1.0567    0.6949     0.001
       600    1.0622     0.631    0.0008
       605    1.0456    0.5668    0.0006
       610    1.0026     0.503   0.00034
       615    0.9384    0.4412   0.00024
       620 0.8544499     0.381   0.00019
       625    0.7514     0.321    0.0001
       630    0.6424     0.265     5E-05
       635    0.5419     0.217   0.00003
       640    0.4479     0.175   0.00002
       645    0.3608    0.1382   0.00001
       650    0.2835     0.107         0
       655    0.2187    0.0816         0
       660    0.1649     0.061         0
       665    0.1212   0.04458         0
       670    0.0874     0.032         0
       675    0.0636    0.0232         0
       680   0.04677     0.017         0
       685    0.0329   0.01192         0
       690    0.0227   0.00821         0
       695   0.01584  0.005723         0
       700 0.01135916  0.004102         0
       705 0.00811092  0.002929         0
       710 0.00579035  0.002091         0
       715 0.00410946  0.001484         0
       720 0.00289933  0.001047         0
       725 0.00204919   0.00074         0
       730 0.00143997   0.00052         0
       735 0.00099995 0.0003611         0
       740 0.00069008 0.0002492         0
       745 0.00047602 0.0001719         0
       750 0.0003323   0.00012         0
       755 0.00023483 0.0000848         0
       760 0.00016615   0.00006         0
       765 0.00011741 0.0000424         0
       770 8.3075E-05   0.00003         0
       775 5.8707E-05 0.0000212         0
       780 4.151E-05 0.00001499         0
       785 2.9353E-05 0.0000106         0
       790 2.0674E-05 7.4657E-06         0
       795 1.456E-05 5.2578E-06         0
       800 1.0254E-05 3.7029E-06         0
       805 7.2215E-06 2.6078E-06         0
       810 5.0859E-06 1.8366E-06         0
       815 3.5817E-06 1.2934E-06         0
       820 2.5225E-06 9.1093E-07         0
       825 1.7765E-06 6.4153E-07         0
       830 1.2511E-06 4.5181E-07         0
> def


|||||||||||||||||||||||||||||| last primitive ||||||||||||||||||||||||||||||||
|         -------------- make primitives readonly ----------------

phase1 mkread /phase1 name
phase2 mkread /phase2 name
phase3 mkread /phase3 name



|======================= Internal Tools of COMPOSE ===========================

|------------------------------ (E)PS accumulation ---------------------------

|
| toPS:      object | --
| faxPS:     string | --
| genPS:  generator | --
|

/toPS {
  {EPSbuf EPSidx 3 -1 roll pstext /EPSidx name pop} COMPOSE indict
} bind def

/faxPS {
  {EPSbuf EPSidx 3 -1 roll fax /EPSidx name pop} COMPOSE indict
} bind def

/genPS {
  {EPSbuf EPSidx} COMPOSE indict
  3 -1 roll exec
  COMPOSE /EPSidx put pop
} bind def

|------------------------ PS prefix: symbol font etc --------------------------
|
| The symbols serve to represent data points in graphs and are encoded by
| capital letters. A text version to be used in labels or legends is
| provided under the corresponding small letters.

/PSprefix (
  /BeginEPSF {
    /b4_Inc_state save def            % Save state for cleanup
    /dict_count countdictstack def    % Count objects on dict stack
    /op_count count 1 sub def         % Count objects on operand stack
    userdict begin                    % Push userdict on dict stack
    /showpage { } def                 % Redefine showpage, { } = null proc
    0 setgray 0 setlinecap            % Prepare graphics state
    1 setlinewidth 0 setlinejoin
    10 setmiterlimit [ ] 0 setdash newpath
    /languagelevel where {            % If level not equal to 1 then
      pop languagelevel               % set strokeadjust and
      1 ne {                          % overprint to their defaults.
        false setstrokeadjust false setoverprint
      } if
    } if
  } bind def

  /EndEPSF { %def
    count op_count sub {pop} repeat       % Clean up stacks
    countdictstack dict_count sub {end} repeat
    b4_Inc_state restore
  } bind def

  /Symbols 100 dict dup begin

  /FontType 3 def
  /FontMatrix [0.0005 0 0 0.0005 0 0] def
  /FontBBox [-1000 -1000 1000 1000] def
  /Encoding 256 array def
  0 1 255 {Encoding exch /.notdef put} for
  Encoding 65 /symbol_1 put        % A  dot
  Encoding 66 /symbol_2 put        % B  diamond
  Encoding 67 /symbol_3 put        % C  square, filled
  Encoding 68 /symbol_4 put        % D  square, stroked
  Encoding 69 /symbol_5 put        % E  square/horizontal
  Encoding 70 /symbol_6 put        % F  +
  Encoding 71 /symbol_7 put        % G  X
  Encoding 72 /symbol_8 put        % H  circle, filled
  Encoding 73 /symbol_9 put        % I  circle, stroked
  Encoding 74 /symbol_10 put       % J  circle/horizontal
  Encoding 75 /symbol_11 put       % K  *
  Encoding 76 /symbol_12 put       % L  up triangle, filled
  Encoding 77 /symbol_13 put       % M  down triangle, filled
  Encoding 78 /symbol_14 put       % N  right triangle, filled
  Encoding 79 /symbol_15 put       % O  left triangle, filled
  Encoding 80 /symbol_16 put       % P  vertical bar, centered
  Encoding 81 /symbol_17 put       % Q  vertical bar, bottom adjusted
  Encoding 82 /symbol_18 put       % R  vertical bar, top adjusted
  Encoding 83 /symbol_19 put       % S  horizontal bar, centered
  Encoding 84 /symbol_20 put       % T  horizontal bar, left adjusted
  Encoding 85 /symbol_21 put       % U  horizontal bar, right adjusted
  Encoding 86 /symbol_22 put       % V  up triangle, stroked
  Encoding 87 /symbol_23 put       % W  down triangle, stroked
  Encoding 88 /symbol_24 put       % X  right triangle, stroked
  Encoding 89 /symbol_25 put       % Y  left triangle, stroked

  Encoding  97 /symbol_1c put        % a  dot
  Encoding  98 /symbol_2c put        % b  diamond
  Encoding  99 /symbol_3c put        % c  square, filled
  Encoding 100 /symbol_4c put        % d  square, stroked
  Encoding 101 /symbol_5c put        % e  square/horizontal
  Encoding 102 /symbol_6c put        % f  +
  Encoding 103 /symbol_7c put        % g  X
  Encoding 104 /symbol_8c put        % h  circle, filled
  Encoding 105 /symbol_9c put        % i  circle, stroked
  Encoding 106 /symbol_10c put       % j  circle/horizontal
  Encoding 107 /symbol_11c put       % k  *
  Encoding 108 /symbol_12c put       % l  up triangle, filled
  Encoding 109 /symbol_13c put       % m  down triangle, filled
  Encoding 110 /symbol_14c put       % n  right triangle, filled
  Encoding 111 /symbol_15c put       % o  left triangle, filled
  Encoding 112 /symbol_16c put       % p  vertical bar, centered
  Encoding 113 /symbol_17c put       % q  vertical bar, bottom adjusted
  Encoding 114 /symbol_18c put       % r  vertical bar, top adjusted
  Encoding 115 /symbol_19c put       % s  horizontal bar, centered
  Encoding 116 /symbol_20c put       % t  horizontal bar, left adjusted
  Encoding 117 /symbol_21c put       % u  horizontal bar, right adjusted
  Encoding 118 /symbol_22c put       % v  up triangle, stroked
  Encoding 119 /symbol_23c put       % w  down triangle, stroked
  Encoding 120 /symbol_24c put       % x  right triangle, stroked
  Encoding 121 /symbol_25c put       % y  left triangle, stroked

  /CharProcs 60 dict def
  CharProcs begin
    /.notdef {} def
    /symbol_1  { -150 -150 moveto 150 -150 lineto 150 150 lineto
                 -150 150 lineto closepath fill } def
    /symbol_2  { 0 -1000 moveto 1000 0 lineto 0 1000 lineto
                 -1000 0 lineto closepath fill } def
    /symbol_3  { -700 -700 moveto 700 -700 lineto 700 700 lineto
                 -700 700 lineto closepath fill } def
    /symbol_4  { symbolweight setlinewidth
                 -700 -700 moveto 700 -700 lineto 700 700 lineto
                 -700 700 lineto closepath stroke } def
    /symbol_5  { -700 -700 moveto 700 -700 lineto 700 0 lineto
                 -700 0 lineto closepath fill
                 -700 -700 moveto -700 700 lineto 700 700 lineto
                 700 -700 lineto closepath stroke } def
    /symbol_6  { symbolweight setlinewidth
                 -1000 0 moveto 1000 0 lineto stroke
                 0 -1000 moveto 0 1000 lineto stroke } def
    /symbol_7  { symbolweight setlinewidth
                 -707 -707 moveto 707 707 lineto stroke
                 -707 707 moveto 707 -707 lineto stroke } def
    /symbol_8  { 798 0 moveto 0 0 798 0 360 arc fill } def
    /symbol_9  { symbolweight setlinewidth
                 798 0 moveto 0 0 798 0 360 arc stroke } def
    /symbol_10  { symbolweight setlinewidth
                  798 0 moveto 0 0 798 180 360 arc fill
                  798 0 moveto 0 0 798 0 360 arc stroke } def
    /symbol_11  { symbolweight setlinewidth
                  -1000 0 moveto 1000 0 lineto stroke
                  0 -1000 moveto 0 1000 lineto stroke
                  -707 -707 moveto 707 707 lineto stroke
                  -707 707 moveto 707 -707 lineto stroke } def
    /symbol_12  { 0 1000 moveto 866 -500 lineto -866 -500 lineto
                  closepath fill } def
    /symbol_13  { 0 -1000 moveto -866 500 lineto 866 500 lineto
                  closepath fill } def
    /symbol_14  { 1000 0 moveto -500 866 lineto -500 -866 lineto
                  closepath fill } def
    /symbol_15  { -1000 0 moveto 500 866 lineto 500 -866 lineto
                  closepath fill } def
    /symbol_16  { symbolweight setlinewidth
                  0 -1000 moveto 0 1000 lineto stroke } def
    /symbol_17  { symbolweight setlinewidth
                  0 0 moveto 0 2000 lineto stroke } def
    /symbol_18  { symbolweight setlinewidth
                  0 0 moveto 0 -2000 lineto stroke } def
    /symbol_19  { symbolweight setlinewidth
                  -1000 0 moveto 1000 0 lineto stroke } def
    /symbol_20  { symbolweight setlinewidth
                  0 0 moveto 2000 0 lineto stroke } def
    /symbol_21  { symbolweight setlinewidth
                  -2000 0 moveto 0 0 lineto stroke } def
    /symbol_22  { symbolweight setlinewidth
                  0 1000 moveto 866 -500 lineto -866 -500 lineto
                  closepath stroke } def
    /symbol_23  { symbolweight setlinewidth
                  0 -1000 moveto -866 500 lineto 866 500 lineto
                  closepath stroke } def
    /symbol_24  { symbolweight setlinewidth
                  1000 0 moveto -500 866 lineto -500 -866 lineto
                  closepath stroke } def
    /symbol_25  { symbolweight setlinewidth
                  -1000 0 moveto 500 866 lineto 500 -866 lineto
                  closepath stroke } def

    /fake { [ 1000 1000 /translate cvx 5 -1 roll load aload pop ] cvx } def

    /symbol_1c /symbol_1 fake def
    /symbol_2c /symbol_2 fake def
    /symbol_3c /symbol_3 fake def
    /symbol_4c /symbol_4 fake def
    /symbol_5c /symbol_5 fake def
    /symbol_6c /symbol_6 fake def
    /symbol_7c /symbol_7 fake def
    /symbol_8c /symbol_8 fake def
    /symbol_9c /symbol_9 fake def
    /symbol_10c /symbol_10 fake def
    /symbol_11c /symbol_11 fake def
    /symbol_12c /symbol_12 fake def
    /symbol_13c /symbol_13 fake def
    /symbol_14c /symbol_14 fake def
    /symbol_15c /symbol_15 fake def
    /symbol_16c /symbol_16 fake def
    /symbol_17c /symbol_17 fake def
    /symbol_18c /symbol_18 fake def
    /symbol_19c /symbol_19 fake def
    /symbol_20c /symbol_20 fake def
    /symbol_21c /symbol_21 fake def
    /symbol_22c /symbol_22 fake def
    /symbol_23c /symbol_23 fake def
    /symbol_24c /symbol_24 fake def
    /symbol_25c /symbol_25 fake  def
  end

  /BuildChar  {
    2000 0
    -2000 -2000 2000 2000
    setcachedevice
    exch begin
      Encoding exch get
      CharProcs exch get
      end
    exec
    } def
end definefont pop   % Symbols font

%-------------------- draw element bounding box
%
% bbox | --

/drawbbox { /bbox exch def
  gsave newpath
  0 setgray
  0.1 setlinewidth
  bbox 0 get bbox 1 get moveto
  bbox 0 get bbox 3 get lineto
  bbox 2 get bbox 3 get lineto
  bbox 2 get bbox 1 get lineto
  closepath stroke
  grestore
} bind def

/showpage { } def

% x y symbol | --

/showsymbol { /symbol exch def
  moveto
  gsave
  symbol false charpath 1 setgray fill
  grestore
  symbol show
} bind def

) def


|---------------------------- cook EPS string - ----------------------------
| -- determines the bounding box etc of an EPS object
| -- also extracts data for text alignment
|
| (epsstring) -- | -- (bbox, and more, see below)

/endcomments (\n\(%%EndComments[^\n]*|%\([ \011][^\n]*\)?\)\n) def

/readDSC {

   |-- carve out DSC prefix and postfix

   epsstring (\(^%[^%][^\n]*\n\)+) regex not {
     (\nEPS: missing shebang comment\n) quiet_msg
     epsstring debug_msg
     pop stop
   } if
   pop pop pop
   endcomments regex not {
     (\nEPS: missing explicit or implicit %%EndComments\n) quiet_msg
     epsstring debug_msg
     pop stop
   } if
   pop /DSCprefix name pop
   DSCoff search {pop pop {DSCon search not ~exit if} loop} if
   (\n%%Trailer) search not {
     (\nEPS: missing %%Trailer\n) quiet_msg
     epsstring debug_msg
     pop stop
   } if pop pop
   /DSCpostfix name | excludes %%Trailer

   |-- distill box info

   DSCprefix (\n%%HiResBoundingBox:) search not {
     (\n%%BoundingBox:) search not {
       (\nEPS: Missing prologue HiResBoundingBox and BoundingBox\n) quiet_msg
       epsstring debug_msg
       pop stop
     } if
   } if pop pop
   (\n) search {3 1 roll pop pop} if
   mkact exec    | try to extract box coordinates
   dup class /arrayclass eq {
       |-- (atend)!
       pop
       DSCpostfix (\n%%HiResBoundingBox:) search not {
         (\n%%BoundingBox:) search not {
           (EPS: Missing Trailer HiResBoundingBox and BoundingBox\n) quiet_msg
           epsstring debug_msg
           pop stop
         } if
       } if pop pop
     (\n) search {3 1 roll pop pop} if
     mkact exec | try again
   } if
   /bbox 4 /d array def
   bbox 3 put bbox 2 put bbox 1 put bbox 0 put

   |-- distill detailed text metrics from postfix (LaTEX only)

   /LatexW * def /LatexH * def /LatexD * def
   DSCpostfix (\n%%LatexWidth:) search
       {  pop pop (\n) search { 3 1 roll pop pop } if
          mkact exec /LatexW name
       } { pop } ifelse
   DSCpostfix (\n%%LatexHeight:) search
       {  pop pop (\n) search { 3 1 roll pop pop } if
          mkact exec /LatexH name
       } { pop } ifelse
   DSCpostfix (\n%%LatexDepth:) search
       {  pop pop (\n) search { 3 1 roll pop pop } if
          mkact exec /LatexD name
       } { pop } ifelse
}  bind def

|-- protective wrapper for included EPS files (to prevent a DSC
|   scanner from looking inside and getting irrelevant DSC materials)

/DSCoff (\n%%BeginDocument: ) def
/DSCon (\n%%EndDocument\n) def


|---------------------------------------------------------------------------
|
|                  General Tools for graph generators
|
|----------------------------------------------------------------------------
|
|  - DefXTransform
|  - DefYTransform
|  - X_to_x, Y_to_y, x_to_X, y_to_Y
|  - DesignLinearAxis
|  - DesignLg10Axis
|  - LinAxisLabel
|  - AxisUnit
|  - roundup, almost, name, text, numeral
|
|----------------------- Logical coordinates ---------------------------
|
| Graph data are defined in a logical coordinate space (LCS). Mapping
| procedures for translating logical coordinates into physical coordinates
| and vice versa are defined by the procedures DefXTransform and
| DefYTransform. Their usage is:
|
|   { logical_to_physical } { physical_to_logical } P1 P2 p1 p2  | --
|
| The procedure arguments translate (non-linear) logical cordinates into
| the physical coordinates, and vice versa. The P and p parameters give
| the coordinates of two points in logical space (P1, P2) that correspond
| to two given points in physical space (p1, p2). For instance,
|
|  { ln 10.0 ln div } { 10.0 exch pwr }
|     0.01 10.0 0 xdim DefXTransform
|
| maps a logarithmic logical abscissa ranging from 0.01 to 10 onto the
| horizontal physical extent of a graph.
|
| Once defined, forward and reverse transforms of individual coordinates
| are made by:
|
|          X     X_to_x     x      (logical to physical)
|          Y     Y_to_y     y
|          x     x_to_X     X      (physical to logical)
|          y     y_to_Y     Y
|

/DefXTransform { DefineTrans /x_to_X name /X_to_x name } def
/DefYTransform { DefineTrans /y_to_Y name /Y_to_y name } def

/DefineTrans {
   /p2 name /p1 name /P2 name  /P1 name
   /rtrans name /trans name
   /pi2 P2 trans def  /pi1 P1 trans def
   ~[ /trans find { } forall
      /a p2 p1 sub pi2 pi1 sub div def
      /b a pi1 mul neg p1 add def
      a ~mul b ~add
   ] bind
   ~[ /a pi2 pi1 sub p2 p1 sub div def
      /b a p1 mul neg pi1 add def
      a ~mul b ~add
     /rtrans find { } forall
   ] bind
} def



|----------------------- designing a linear axis --------------------------
| use: min max | [ min max step unit ]
|      - chooses 5-10 partitions to comprise given min | max range
|        (origin is included dependend on max/min ratio)
|      - returns: rounded min, max
|                 logical scale partition in step
|                 unit is power of 10 that divided into the axis range
|                 gives a number between 0.1 and 999.

/DesignLinearAxis {/d ctype /max name /d ctype /min name
  max min eq {
    max 0 eq { -1e-6 1e-6 } {
      max 0 gt {
        min 0.9 mul max 1.1 mul
      } {
        min 1.1 mul max 0.9 mul
      } ifelse
    } ifelse /max name /min name
  } if
  min 0 gt { max min div 5 gt { /min 0.0 def } if } if
  max 0 lt { min max div 5 gt { /max 0.0 def } if } if
  max min sub abs lg dup floor dup /exp10 name sub /mant name
  0.2 mant 0.1 ge { pop 0.5 } if mant 0.5 ge { pop 1.0 } if
  10.0 exp10 pwr mul /step name
  /min min step div floor step mul def
  /max max step div ceil step mul def
  /unit |[
    min abs max abs 2 copy lt ~exch if pop
    lg 3 div floor 3 mul
    10.0 exch pwr |]
  def
  [min max step unit]
} bind def

|-------------------------- make label of linear axis ----------------------
| (letterprefix)  poweroften axdesc axunit | label
|
| A string buffer is made and the description string is appended. A decision
| is made whether a unit string is to be appended. If so, dependent on
| boolean `letterprefix', either is the unit with a letter prefix indicating
| the order of magnitude appended (provided the order of magnitude is in range
| and the unit string is not blank), or a power of 10 is appended as number,
| followed by whatever the unit string provides. Other typographical details
| are also observed in the formatting.

/LinAxisLabel { /unit name /axdesc name /poweroften name

  100 /b array 0 axdesc fax

  letterprefix
  poweroften 1e-15 ge and
  poweroften 1e9 le and
  unit length 0 gt and
     { ( / ) fax
       letterlist poweroften lg 15 add 3 div 0.8999999999999999 add get fax
       unit fax
     }
     { poweroften 1 eq not
         { unit length 0 ne {( / \($10^{)} {( / $10^{)}  ifelse fax
           * poweroften lg roundup /l ctype -1 number
           (}$ ) fax unit fax
           unit length 0 ne { (\)) fax } if
         }
         { unit length 0 ne { ( / ) fax unit fax } if
         }
         ifelse
     }
     ifelse
  0 exch getinterval
} bind def

/letterlist [ (f) (p) (n) ($\mu$) (m) () (K) (M) (G) ] def

|------------------------ designing a log10 axis ---------------------------
| use: min max | [ min max [ decades ] [ subdecades ] ]
|
| - a subdecade step (factor corresponding to scale subpartition) is
|   chosen dependent on the # of decades in original min | max range and
|   is either 1, 2, 5, or 10
| - the full-decade partitions and decade subpartitions are returned in
|   separate arrays
| - the returned min, max are adjusted to the actual spanned range and span
|   at least one decade

/DesignLg10Axis {/d ctype /max name /d ctype /min name
   max min div /range name
   1.0 range 1e2 gt { pop 2.0 } if
     range 1e5 gt { pop 5.0 } if /step name
   /min min pwr_mant step div floor dup 0 eq
      { pop 1.0 } { step mul } ifelse mul def
   /max max pwr_mant step div ceil step mul mul def
   max min div 10.0 lt { /min 10.0 min lg floor pwr def } if
   max min div 10.0 lt { /max 10.0 max lg ceil pwr def } if
   [ min max
     [ min almost lg ceil 1.0 max lg floor { 10.0 exch pwr } for ]
     [ /lgstep 10.0 min lg floor min a_decade { 1 sub } if pwr step mul def
       min { /part name part almost max gt { exit } if
             part a_decade
                { /lgstep lgstep 10.0 mul def
                  step 1.0 eq { part lgstep add } { lgstep } ifelse
                }
                { part dup lgstep add }
                ifelse
         } loop
     ]
   ]
} bind def

/pwr_mant { | use: real | power_of_10_mantissa
   dup lg floor 10.0 exch pwr dup 3 1 roll div
} bind def

/a_decade { | use: real | bool  (tests if 'real' is a power of ten)
   lg dup round sub abs 1e-12 le
} bind def

|---------------------- deposit a power of 10
| use: textbuf textindex power | textbuf textindex
|
| appends to a running text a string formatted as a power of ten.

/PowerOfTen { /unit name
   unit 1 ne {
     * (10^{) text
     * unit lg roundup /l ctype -1 number
     * (}) text
   } {
     * (1) text
   } ifelse
} bind def

|------------------------ specific roundings

|-- round to nearest integer
/round {dup 0 ge {0.5 exch add floor}{-0.5 exch add ceil} ifelse} bind def

|-- round up to next higher power of ten
/roundup {dup 0 ge ~ceil ~floor ifelse} bind def

|-- reduce the value of a number by a tiny amount
/almost ~[1.0 1e-14 sub ~exch ~mul] bind def

|-- logarithm base 10
/lg ~[/d ~ctype ~ln 10.0 ln -1 pwr ~mul] bind def

|-- number formatter for labels
| number | (proc `numberlabel')
|
| Makes the procedure `numberlabel' that extends the `number' operator to
| automatically format axis labels (integer if `number' is greater than 1;
| fixed point, one decimal otherwise).

/labelformatter {
  1 ge  { { round /l ctype * exch * number } }
       { { * exch -1 number } }
       ifelse
  /numberlabel name
} bind def


} moduledef

userdict /EPS known not {getstartupdir (eps.d) fromfiles} if
