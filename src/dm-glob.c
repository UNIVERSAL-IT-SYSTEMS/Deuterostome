#include "dm.h"

#include <glob.h> // after, to get all glob features
#include "dm-glob.h"
#include <string.h>
#include <errno.h>

// (pattern) | [ (path)...]
P op_glob(void) {
  glob_t gl;
  B* oldfreevm = FREEvm;
  size_t i;

  if (o_1 < FLOORopds) return OPDS_UNF;
  if (TAG(o_1) != (ARRAY|BYTETYPE)) return OPD_CLA;
  if (FREEvm + ARRAY_SIZE(o_1) + 1 >= CEILvm) 
    return VM_OVF;
  moveB(VALUE_PTR(o_1), FREEvm, ARRAY_SIZE(o_1));
  FREEvm[ARRAY_SIZE(o_1)] = '\0';
  
  switch (glob((char*) FREEvm, 
	       GLOB_BRACE|GLOB_TILDE, 
	       NULL, &gl)) {
    case GLOB_NOMATCH:
      if (FREEvm + FRAMEBYTES >= CEILvm) return VM_OVF;
      TAG(FREEvm) = LIST;
      ATTR(FREEvm) = PARENT;
      FREEvm 
	= VALUE_PTR(FREEvm) 
	= LIST_CEIL_PTR(FREEvm) 
	= FREEvm + FRAMEBYTES;
      moveframe(FREEvm, o_1);
      //ATTR(o_1) &= ~PARENT;
      return OK;

    case GLOB_NOSPACE: return MEM_OVF;
    case GLOB_ABORTED: return errno ? -errno : READ_ERROR;
    default:           return UNKNOWN_ERR;
    case 0:            break;
  };

  if (FREEvm + FRAMEBYTES * (1 + gl.gl_pathc) >= CEILvm) 
    goto vm_ovf;

  TAG(FREEvm) = LIST;
  ATTR(FREEvm) = PARENT;
  VALUE_PTR(FREEvm) = FREEvm + FRAMEBYTES;
  FREEvm 
    = LIST_CEIL_PTR(FREEvm) 
    = FREEvm + FRAMEBYTES * (1 + gl.gl_pathc);

  for (i = 0; i < gl.gl_pathc; ++i) {
    size_t len = strlen(gl.gl_pathv[i]);
    if (FREEvm + FRAMEBYTES + DALIGN(len) >= CEILvm) 
      goto vm_ovf;

    TAG(FREEvm) = (ARRAY|BYTETYPE);
    ATTR(FREEvm) = PARENT;
    VALUE_PTR(FREEvm) = FREEvm + FRAMEBYTES;
    ARRAY_SIZE(FREEvm) = len;
    moveB((B*) gl.gl_pathv[i], FREEvm + FRAMEBYTES, len);
    moveframe(FREEvm, oldfreevm + FRAMEBYTES*(1+i));
    //ATTR(oldfreevm + FRAMEBYTES*(1+i)) &= ~PARENT;
    FREEvm += FRAMEBYTES + DALIGN(len);
  }

  globfree(&gl);
  moveframe(oldfreevm, o_1);
  //ATTR(o_1) &= ~PARENT;
  return OK;

 vm_ovf:
  globfree(&gl);
  FREEvm = oldfreevm;
  return VM_OVF;
}
