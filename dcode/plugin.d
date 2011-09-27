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
/PLUGINS module 1000 dict dup begin

/buf 1000 1024 mul /b array def

/header_handle {
  (OPAQUE_MEM\(frame, ) package (_) h (_N\))
} bind def

/header_handle_ind {textit /h__ name
  (OPAQUE_MEM\(frame, ) package (_) h__ (_N\))
} bind def

/body_handle {exch
  package (_) 3 -1 roll textit (\() 5 -1 roll textit (\))
} bind def

/body_name {
  package (_) 3 -1 roll textit (_N)
} bind def

/null_handle {/settee name /settyp name /frame name /hname name
  (if \(TAG\(OPAQUE_MEM\() frame textit (, ) package (_) hname textit (_N\)\)
       != NULLOBJ\)
  ) settee textit ( = \() settyp textit (\) ) hname textit frame textit
  body_handle textit
} bind def

/error_ {
  (RETURN_ERROR\() package (_) 4 -1 roll textit (\))
} bind def

/errorconst {
  package (_) 3 -1 roll textit
} bind def

/get_op_ptr {
  dup null ne {
    4 opslist {
      0 get 2 index eq ~exit if
      1 add
    } forall
    exch pop
    (\(B*\) &ll_export[) exch 2 mul textit (])
  } if
} bind def

/getbufferframe {(OPAQUE_MEM\(procframe, buffernameframe\))} def
/getbufferfrom  {(OPAQUE_MEM\() exch (, buffernameframe\))} def

/build_handle {/dest name /destroyer name /size name /x name
  /handle (\(initframe\)) def
(
   {
      B initframe[FRAMEBYTES];
      B* procframe = make_opaque_frame\() size textit
       (, ) destroyer get_op_ptr textit
       (, opaquename, \n)
       handledict null ne {
         handledict {pop textit /h name
           package (_) h (_N,\n)
         } forall
       } if
       (NULL\);
     if \(! procframe\) return VM_OVF;
)
  x (
     moveframe\(procframe, ) dest textit (\);
   }
)
  /handle ~body_handle def
} bind def
     
/make_handle {textit /n name
  (OPAQUE_MEM_SET\(procframe, ) package (_) n (_N, initframe\))
} bind def

/textname_ 100 /b array def

/textit_ 10 dict dup begin
  /nullclass {pop (NULL)} bind def
  /numclass {
    textname_ 0 * 4 -1 roll * number 0 exch getinterval
    dup length /b array copy
  } bind def
  /nameclass {
    textname_ 0 * 4 -1 roll mkact text 0 exch getinterval
    dup length /b array copy
  } bind def
  /opclass {
    textname_ 0 * 4 -1 roll text 0 exch getinterval
  } bind def
  /arrayclass {
    dup type /B ne {
      textname_ 0 ({) fax
      3 -1 roll {
        * exch * number (,) fax
      } forall
      (}) fax 0 exch getinterval
      dup length /b array copy
    } if
  } bind def
  /listclass {
    textname_ 0 ({) fax
    3 -1 roll {
      dup class textit_ exch get exec fax (,) fax
    } forall
    0 exch getinterval
    dup length /b array copy
  } bind def
  /dictclass {
    textname_ 0 ({) fax
    3 -1 roll {/obj name /nm name
      nm /nameclass get exec fax (,) fax
      obj textit_ obj class get exec fax (,) fax
    } forall
    0 exch getinterval
    dup length /b array copy
  } bind def
  /markclass {pop ([)} bind def
  /boolclass {{(TRUE)} {(FALSE)} ifelse} bind def
end def
/textit {dup class textit_ exch get exec} bind def

/makehandles {[]} bind def
/makehandles_ind {[]} bind def
/nameslist [] bind def
/bodyheaders () bind def
/errsdict null def
/makebodycode null def
/headercode () def
/bodycode () def
/inicode () def
/finicode () def

/toupper {
  dup length /b array copy
  0 1 2 index length 1 sub {/i name
    dup i get dup 97 lt 1 index 122 gt or {pop} {
      32 sub 1 index i put
    } ifelse
  } for
} bind def

/all {
  end currentdict end PLUGINS begin begin
  /islocal name /isbody name /file name /path name

  file 0 file length 2 sub getinterval toupper /package name
  file 0 file length 2 sub getinterval /package_ name
  
  makeops /opslist name
  makehandles dup length dup 0 eq {pop pop null} {
    dict dup begin exch {
      {} forall def
    } forall end
  } ifelse /handledict name
  makehandles_ind dup length dup 0 eq {pop pop null} {
    dict dup begin exch {
      {} forall def
    } forall end
  } ifelse /handledict_ind name

  isbody {dobody} {doheader} ifelse
  
} bind def

/dobody {
  buf 0
  bodyheaders fax (
#include ") fax package_ fax (.h"

UP ll_type = 0;
P op_hi\(void\) {return wrap_hi\(\(B*\)") fax
  package_ fax ( V) fax * version * number ("\);}
P op_libnum\(void\) {return wrap_libnum\(ll_type\);}
P ll_errc[] = {
) fax

  errsdict null ne {
    errsdict {pop textit /e name
      package fax (_) fax e fax (,\n) fax
    } forall
  } if
(  0L
};

B* ll_errm[] = {
) fax
  errsdict null ne {
    errsdict {exch pop /e name
      (\(B*\)"** ) fax package_ fax (: ) fax e fax (",\n) fax
    } forall
  } if

(  NULL
};

B* ll_export[] = {
  \(B*\)"hi", \(B*\) op_hi,
  \(B*\)"libnum", \(B*\) op_libnum,
  \(B*\)"INIT_", \(B*\) op_INIT_,
  \(B*\)"FINI_", \(B*\) op_FINI_,
) fax

  opslist {0 get textit /op name
    (\(B*\)") fax op fax (", \(B*\) op_) fax op fax (,\n) fax
  } forall
(  \(B*\)"", NULL
};

B opaquename[FRAMEBYTES];
) fax

  handledict null ne {
    handledict {pop textit /h name
      (static B ) fax package fax (_) fax h fax (_N[FRAMEBYTES];\n) fax
    } forall
    (\n) fax
  } if

  nameslist {textit /n name
    (static B ) fax package fax (_) fax n fax (_N[FRAMEBYTES];\n) fax
  } forall
  (\n) fax
  
  [bodycode] ~fax forall
(
P op_INIT_\(void\) {
) fax

  handledict null ne {
    (makename\(\(B*\)") fax package fax (_HANDLE", opaquename\);\n) fax
    handledict {pop textit /h name
      (makename\(\(B*\)") fax h fax (", ) fax
      package fax (_) fax h fax (_N\);\n) fax
    } forall
  } if
  
  nameslist {textit /n name
    (makename\(\(B*\)") fax n fax (", ) fax
    package fax (_) fax n fax (_N\);\n) fax
  } forall

  inicode fax (
  return OK;
}

P op_FINI_\(void\) {
) fax
  finicode fax (
  return OK;
}

) fax

  /handle ~body_handle def
  /nameit ~body_name def
  opslist {dup 0 get textit /op name 1 get /opb name
(P op_) fax op fax (\(void\) {
) fax
    [opb] {fax} forall (
}

) fax
  } forall (
) fax 0 exch getinterval path file writefile
} bind def
    

/doheader {
  buf 0 (\
#ifndef ) fax package fax (_H
#define ) fax package fax (_H

#define PLUGIN_NAME ) fax package_ fax (
#include ) fax islocal {("../src/plugin.h")} {(<dm/plugin.h>)} ifelse fax (

) fax

  /handle ~header_handle def
  handledict null ne {
    handledict {/h_ name textit /h name
      /h_ [h_] def
      (#define ) fax package fax (_) fax h fax (\(frame\) \() fax
      h_ {fax} forall
      (\)\n) fax
    } forall
  } if

  /handle ~header_handle_ind def
  handledict_ind null ne {
    handledict_ind {/h_ name textit /h name
      /h_ [h_] def
      (#define ) fax package fax (_) fax h fax (\(frame\) \() fax
      h_ {fax} forall
      (\)\n) fax
    } forall
  } if

  (\n) fax headercode fax (\n) fax

  /errn 1L def
  errsdict null ne {
    errsdict {exch textit /e name /e_ name
      (#define ) fax package fax (_) fax e fax
      ( \() fax * errn * number (L\)) fax (\n) fax
      /errn errn 1 add def
    } forall
  } if

  opslist {0 get textit /op name
    (\n#define op_) fax op fax ( EXPORTNAME\(op_) fax op fax (\)\n) fax
    (P op_) fax op fax (\(void\);\n) fax
  } forall

(
#endif
) fax
  0 exch getinterval path file writefile
} bind def

end _module
