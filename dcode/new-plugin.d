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
/NEW_PLUGINS module 1000 dict dup begin

save /new_plugins_save name
1024 /b array 0 
(Loading: ) fax getstartupdir fax (startup_common_in.d\n) fax
0 exch getinterval toconsole
/new_plugins_buf vmstatus sub 10 div /b array def
new_plugins_save capsave {
  getstartupdir (startup_common_in.d) new_plugins_buf readfile mkact exec
} stopped new_plugins_save restore {
  1024 /b array 0
  (Unable to load: ) fax
  getstartupdir fax (startup_common_in.d\n) fax
  0 exch getinterval toconsole
  stop
} if

| lower | LOWER
/toupper_ {
  save 1024 /b array 1 index capsave    | (string)/name save (string)
  0 * 5 -1 roll text 0 exch getinterval | save (string)
  dup length /b array copy exch restore
  0 1 2 index length 1 sub {/i name
    dup i get dup 97 lt 1 index 122 gt or {pop} {
      32 sub 1 index i put
    } ifelse
  } for
} bind def

| /name|(name) | (NAME)
/toupper {
  dup class /arrayclass ne {
    /NAMEBYTES get_compile /b array 0 * 4 -1 roll text 0 exch getinterval
  } if toupper_
} bind def

/make_buffer {
  /buf 1000 1024 mul /b array def
  /bufn 0 def
} bind def

/__dict 5 dict dup begin |[
  /listclass {{__ (|)__} forall bufn 1 sub /bufn name} bind def
  /nameclass {buf bufn * 4 -1 roll text /bufn name pop} bind def
  /arrayclass {buf bufn * 4 -1 roll text /bufn name pop} bind def
  /nullclass  {pop} bind def
  /numclass {buf bufn * 4 -1 roll * number /bufn name pop} bind def |]
end def

/__ {
  __dict 1 index class get exec
} bind def

/n_ {buf bufn * 4 -1 roll * number /bufn name pop} bind def

/nl {(\n)__} bind def

/makename {
  plugin_name dup /plugin_name_l name
  toupper         /plugin_name_u name
} bind def

/makeheader {
  make_buffer
  (#ifndef DM_)__ plugin_name_u __ (_H)__ nl
  (#define DM_)__ plugin_name_u __ (_H)__ nl nl

  (#define PLUGIN_NAME )__ plugin_name_l __ nl nl
  (#include )__ islocal {("../src/plugin.h")} {(<dm/plugin.h>)} ifelse __ nl nl
  
  plugin_types {/type_dict name /type_name name
    /type_name_u type_name toupper def
    /member_dict type_dict /members get def
    member_dict {
      {} forall /mem_attr name /mem_type name /mem_tag name /mem_name name
      /mem_name_u mem_name toupper def
      (#define )__ plugin_name_u __ (_)__ type_name_u __ (_)__ 
                   mem_name_u __ (_FRAME\(dframe\))__
      ( OPAQUE_MEM\(dframe, )__ type_name_u __ (_)__ mem_name_u __ 
      (_frame\))__ nl nl

      (#define )__ plugin_name_u __ (_)__ type_name_u __ (_)__ 
                   mem_name_u __ (\(dframe\))__
      ( \() __ mem_type __ 
      (\()__ plugin_name_u __ (_)__ type_name_u __ (_)__ mem_name_u __ 
      (_FRAME\(dframe\)\)\))__ nl nl
      
      (#define )__ plugin_name_u __ (_)__ type_name_u __ (_)__ mem_name_u __ 
      (_INIT\(dframe\))__
      (do { \\)__ nl 
      (  B frame[FRAMEBYTES]; \\)__ nl
      (  TAG\(frame\) = \()__ mem_tag __ (\); \\)__ nl
      (  ATTR\(frame\) = )__ mem_attr __ (; \\)__ nl
      (  OPAQUE_MEM_SET\(dframe, )__  type_name_u __ (_)__ 
                                      mem_name_u __ (_frame, frame\); \\)__ nl
      (} while \(0\))__ nl nl
    } forall

    (#define MAKE_)__ plugin_name_u __ (_)__ type_name_u __ (\(frame)__
    type_dict /opaque known {
      type_dict /opaque get
    } {null} ifelse dup null eq {(, size)} {()} ifelse __ (\) )__

    (do { \\)__ nl
    (  if \(! \(frame = make_opaque_frame\()__ 
    dup null eq {pop (size)} if __ (, )__
    plugin_name_u __ (_)__ type_name_u __ (_frame, )__

    member_dict {pop /mem_name name
      /mem_name_u mem_name toupper def
      type_name_u __ (_)__ mem_name_u __ (_frame, )__
    } forall
    (NULL\)\)\) \\)__ nl
    (    return VM_OVF; \\)__ nl
    member_dict {pop /mem_name name
      /mem_name_u mem_name toupper def
      (  )__ plugin_name_u __ (_)__ type_name_u __ (_)__ mem_name_u __ 
      (_INIT\(frame\); \\)__ nl
    } forall
    (} while \(0\))__ nl nl

    (#define TEST)__ (_)__ plugin_name_u __ (_)__ type_name_u __ (\(frame\) )__
    (do { \\)__ nl
    (  if \(TAG\(frame\) != \(DICT|OPAQUETYPE\)\) return OPD_TYP;\\)__ nl
    (  if \(! check_opaque_name\()__
       plugin_name_u __ (_)__ type_name_u __ (_frame, VALUE_PTR\(frame\)\)\) )__
       (return ILL_OPAQUE; \\)__ nl
    (} while \(0\))__ nl nl
  } forall

  /en 1 def
  plugin_errs {pop /err_name name
    (#define )__ plugin_name_u __ (_)__ err_name toupper __ 
    ( \()__ en n_ (L\))__ nl
    /en en 1 add def
  } forall nl

  plugin_ops {pop /op_name name
    op_name /init_ eq op_name /fini_ eq or not {
      (#define )__ (op_)__ op_name __ ( EXPORTNAME\(op_)__ op_name __ (\))__ nl
      (P op_)__ op_name __ (\(void\);)__ nl nl
    } if
  } forall

  plugin_types {/type_dict name /type_name name
    /type_name_u type_name toupper def
    (static B )__ plugin_name_u __ (_)__ type_name_u __  
    (_frame[FRAMEBYTES];)__ nl
    (static B* )__ plugin_name_u __ (_)__ type_name_u __
    (_string = \(B*\) ")__ plugin_name_u __ (_)__ type_name_u __ (";)__ nl
    /member_dict type_dict /members get def
    member_dict {pop /mem_name name
      /mem_name_u mem_name toupper def
      (static B )__ type_name_u __ (_)__ mem_name_u __ 
      (_frame[FRAMEBYTES];)__ nl
      (static B* )__ type_name_u __ (_)__ mem_name_u __
      (_string = \(B*\) ")__ type_name_u __ (_)__ mem_name_u __ (";)__ nl
    } forall
  } forall

  (#endif //DM_)__ plugin_name_u __ (_H)__ nl nl

  buf bufn 0 exch getinterval path file writefile
} bind def

/makebody {
  make_buffer
  (#include "dm-)__ plugin_name_l __ (-header.h")__ nl nl

  (PLUGIN_INTRO\()__ plugin_version n_ (, )__ plugin_name_l (\);)__ nl nl

  (P ll_errc[] = { )__ nl
  plugin_errs {pop /err_name name
    (  )__ plugin_name_u __ (_)__ err_name toupper __ (, )__ nl
  } forall
  (  0L)__ nl
  (};)__ nl nl

  (B* ll_errm[] = { )__ nl
  plugin_errs {/err_string name pop
    (  \(B*\)"** )__ plugin_name_l __ (: )__ err_string __ (", )__ nl
  } forall
  (  NULL)__ nl
  (};)__ nl nl
  
  (B* ll_export[] = { )__ nl
  (  PLUGIN_OPS,)__ nl
  plugin_ops {pop /op_name name
    op_name /init_ ne {
      op_name /fini_ eq {/FINI_ /op_name name} if
      (  PLUGIN_OP\()__ op_name __ (\),)__ nl
    } if
  } forall
  plugin_ops /init_ known plugin_types used 0 ne or {
    (  PLUGIN_OP\(INIT_\),)__ nl
  } if
  (  \(B*\)"", NULL)__ nl
  (};)__ nl nl

  plugin_ops /init_ known plugin_types used 0 ne or {
    (P op_INIT_\(void\) {)__ nl
    plugin_types {/type_dict name /type_name name
      /type_name_u type_name toupper def
      (  makename\()__ plugin_name_u __ (_) __ type_name_u __ 
        (_string, )__ plugin_name_u __ (_)__ type_name_u __ (_frame\);)__ nl
      /member_dict type_dict /members get def
      member_dict {pop /mem_name name
        /mem_name_u mem_name toupper def
        (  makename\()__ type_name_u __ (_)__ mem_name_u __ (_string, )__
                         type_name_u __ (_)__ mem_name_u __ (_frame\);)__ nl
      } forall
    } forall

    plugin_ops /init_ known {
      (  return init_\(\);)
    } {
      (  return OK;)
    } ifelse
    __ nl (})__ nl nl
  } if

  plugin_ops /fini_ known {
    (P op_FINI_\(void\) {return fini_\(\);})__ nl nl
  } if

  plugin_ops {pop /op_name name
    op_name /init_ ne op_name /fini_ ne and {
      (P op_)__ op_name __ (\(void\) {return )__ op_name __ (\(\);})__ nl nl
    } if
  } forall

  buf bufn 0 exch getinterval path file writefile
} bind def

/all {
  /islocal name /isbody name /file name /path name

  currentdict end currentdict exch begin
  {/plugin_errs /plugin_types} {
    2 copy known not {0 dict def} {pop} ifelse
  } forall
  dup /plugin_version known not {/plugin_version 0          def} if
  dup /plugin_name    known not {/plugin_name    dictinname def} if
  pop

  makename
  isbody ~makebody ~makeheader ifelse
} bind def

end _module
