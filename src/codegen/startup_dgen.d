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

(Using startup_dgen from codegen\n) toconsole

| Contains procedures for:
|  - inspection of objects
|  - object/text interconversion
|  - transcription of objects
|  - file <=> VM interchange
|  - module support


|============================= userdict =================================

/false 0 1 eq def                             | boolean prototypes
/true  0 0 eq def

/dm_type /dgen def

2 list dictstack dup 0 get /systemdict name   | name the roots
                     1 get /userdict name

/lock   ~exec bind def    |
/unlock ~exec bind def

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

/a__ { debug_dict begin              | show entire opd stack
   count 1 sub 0 1 3 -1 roll { index _ pop } for
   dup class /arrayclass eq {
       (top:\n) toconsole
       dup type /B eq {dup s_} {dup v_} ifelse
   } {
       dup class /listclass eq {(top:\n) toconsole dup v_} if
   } ifelse
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
/d_blit_dict 6 dict dup begin
   /B /_stringclass def
   /W /_arrayclass def
   /L /_arrayclass def
   /X /_arrayclass def
   /S /_arrayclass def
   /D /_arrayclass def
end mkread def

/ps_blit { mkpass dup 
           type mkact ps_blit_dict begin exec end mkact exec } bind def
/ps_blit_dict 6 dict dup begin
   /B /_stringclass def
   /W /listclass def
   /L /listclass def
   /X /listclass def
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
/X { objstr 0 21 4 -1 roll * number 0 exch getinterval ftext } bind def
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

|----------------------------- start the dvt ------------------------------
| A 'save' representing a clean dvt is associated with the name cleanDVT in
| userdict.

(dgen) userdict /myid put

(End of startup\n) toconsole
