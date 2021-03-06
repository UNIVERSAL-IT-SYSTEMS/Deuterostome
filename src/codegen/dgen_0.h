/*

Copyright 2011 Alexander Peyser & Wolfgang Nonner

This file is part of Deuterostome.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/
/*=================== D machine Rev3.0: dvt_0.c =====================

  Include module for dvt.c: operator and error lists of the dvt.
*/

#if BOOTSTRAP_PLUGIN
/*--- LL */
P op_loadlib(void);
P op_nextlib(void);
#endif

#include "dgen-dm3.h"

B *_sysop[] =
   {
/*-- dvt specific */
      (B*)"error",          (B *)op_error,
      (B*)"errormessage",   (B *)op_errormessage,
      (B*)"abort",          (B *)op_abort,
      (B*)"quit",           (B *)op_quit,
      (B*)"toconsole",      (B *)op_toconsole,
      (B*)"fromconsole",    (B *)op_fromconsole,
/*-- operand stack */
      (B*)"pop",            (B *)op_pop,
      (B*)"exch",           (B *)op_exch,
      (B*)"dup",            (B *)op_dup,
      (B*)"copy",           (B *)op_copy,
      (B*)"index",          (B *)op_index,
      (B*)"roll",           (B *)op_roll,
      (B*)"clear",          (B *)op_clear,
      (B*)"count",          (B *)op_count,
      (B*)"cleartomark",    (B *)op_cleartomark,
      (B*)"counttomark",    (B *)op_counttomark,
/*-- dictionary, array, list */
      (B*)"currentdict",    (B *)op_currentdict,
      (B*)"]",              (B *)op_closelist, 
      (B*)"dict",           (B *)op_dict,
      (B*)"cleardict",      (B *)op_cleardict,
      (B*)"array",          (B *)op_array,
      (B*)"list",           (B *)op_list,
      (B*)"used",           (B *)op_used,
      (B*)"length",         (B *)op_length, 
      (B*)"begin",          (B *)op_begin,
      (B*)"end",            (B *)op_end,
      (B*)"def",            (B *)op_def,
      (B*)"name",           (B *)op_name,
      (B*)"find",           (B *)op_find,
      (B*)"get",            (B *)op_get,
      (B*)"put",            (B *)op_put,
      (B*)"known",          (B *)op_known,
      (B*)"getinterval",    (B *)op_getinterval,
      (B*)"countdictstack", (B *)op_countdictstack,
      (B*)"dictstack",      (B *)op_dictstack,
/*-- VM and miscellaneous */
      (B*)"save",           (B *)op_save,
      (B*)"capsave",        (B *)op_capsave,
      (B*)"restore",        (B *)op_restore,
      (B*)"vmstatus",       (B *)op_vmstatus,
      (B*)"bind",           (B *)op_bind,
      (B*)"null",           (B *)op_null,
/*-- control */
      (B*)"start",          (B *)op_start,
      (B*)"exec",           (B *)op_exec,
      (B*)"if",             (B *)op_if,
      (B*)"ifelse",         (B *)op_ifelse,
      (B*)"for",            (B *)op_for,
      (B*)"repeat",         (B *)op_repeat,
      (B*)"loop",           (B *)op_loop,
      (B*)"forall",         (B *)op_forall,
      (B*)"exit",           (B *)op_exit,
      (B*)"stop",           (B *)op_stop,
      (B*)"stopped",        (B *)op_stopped,
      (B*)"countexecstack", (B *)op_countexecstack,
      (B*)"execstack",      (B *)op_execstack,
/*-- math */
      (B*)"checkFPU",       (B *)op_checkFPU,
      (B*)"neg",            (B *)op_neg,
      (B*)"abs",            (B *)op_abs,
      (B*)"thearc",         (B *)op_thearc, 
      (B*)"add",            (B *)op_add,
      (B*)"mod",            (B *)op_mod,
      (B*)"sub",            (B *)op_sub,
      (B*)"mul",            (B *)op_mul,
      (B*)"div",            (B *)op_div,
      (B*)"sqrt",           (B *)op_sqrt,
      (B*)"exp",            (B *)op_exp,
      (B*)"ln",             (B *)op_ln,
      (B*)"lg",             (B *)op_lg,
      (B*)"pwr",            (B *)op_pwr,
      (B*)"cos",            (B *)op_cos,
      (B*)"sin",            (B *)op_sin,
      (B*)"tan",            (B *)op_tan,
      (B*)"atan",           (B *)op_atan,
      (B*)"floor",          (B *)op_floor,
      (B*)"ceil",           (B *)op_ceil,
      (B*)"asin",           (B *)op_asin,
      (B*)"acos",           (B *)op_acos,
/*-- relational, boolean, bitwise */ 
      (B*)"eq",             (B *)op_eq,
      (B*)"ne",             (B *)op_ne,
      (B*)"ge",             (B *)op_ge,
      (B*)"gt",             (B *)op_gt,
      (B*)"le",             (B *)op_le,
      (B*)"lt",             (B *)op_lt,
      (B*)"and",            (B *)op_and,
      (B*)"not",            (B *)op_not,
      (B*)"or",             (B *)op_or,
      (B*)"xor",            (B *)op_xor,
      (B*)"bitshift",       (B *)op_bitshift,
/*-- conversion, string, attribute, class ,type */
      (B*)"class",          (B *)op_class,
      (B*)"type",           (B *)op_type,
      (B*)"readonly",       (B *)op_readonly,
      (B*)"active",         (B *)op_active,
      (B*)"tilde",          (B *)op_tilde,
      (B*)"mkread",         (B *)op_mkread,
      (B*)"mkact",          (B *)op_mkact,
      (B*)"mkpass",         (B *)op_mkpass,
      (B*)"ctype",          (B *)op_ctype,
      (B*)"parcel",         (B *)op_parcel,
      (B*)"text",           (B *)op_text,
      (B*)"number",         (B *)op_number,
      (B*)"token",          (B *)op_token,
      (B*)"search",         (B *)op_search,
      (B*)"anchorsearch",   (B *)op_anchorsearch,
/*-- time/date and file access */
      (B*)"gettime",        (B *)op_gettime,
      (B*)"localtime",      (B *)op_localtime,
      (B*)"getwdir",        (B *)op_getwdir,
      (B*)"setwdir",        (B *)op_setwdir,
      (B*)"readfile",       (B *)op_readfile,
      (B*)"writefile",      (B *)op_writefile,
      (B*)"findfiles",      (B *)op_findfiles,
      (B*)"readboxfile",    (B *)op_readboxfile,
      (B*)"writeboxfile",   (B *)op_writeboxfile,
      (B*)"tosystem",       (B *)op_tosystem,
      (B*)"fromsystem",     (B *)op_fromsystem,
      (B*)"transcribe",     (B *)op_transcribe,
/*-- more ... */
      (B*)"fax",            (B *)op_fax,
      (B*)"merge",          (B *)op_merge,
      (B*)"nextobject",     (B *)op_nextobject,
      (B*)"interpolate",    (B *)op_interpolate,
      (B*)"integrateOH",    (B *)op_integrateOH,
      (B*)"extrema",        (B *)op_extrema,
      (B*)"solvetridiag",   (B *)op_solvetridiag,
      (B*)"integrateOHv",   (B *)op_integrateOHv,
      (B*)"tile",           (B *)op_tile,
      (B*)"ramp",           (B *)op_ramp,
      (B*)"extract",        (B *)op_extract,
      (B*)"dilute",         (B *)op_dilute,
      (B*)"ran1",           (B *)op_ran1,
      (B*)"solve_bandmat",  (B *)op_solve_bandmat,
      (B*)"complexFFT",     (B *)op_complexFFT,
      (B*)"realFFT",        (B *)op_realFFT,
      (B*)"sineFFT",        (B *)op_sineFFT,
      (B*)"decompLU",       (B *)op_decompLU,
      (B*)"backsubLU",      (B *)op_backsubLU,
      (B*)"integrateRS",    (B *)op_integrateRS,
      (B*)"bandLU",         (B *)op_bandLU,
      (B*)"bandBS",         (B *)op_bandBS,
      (B*)"invertLU",       (B *)op_invertLU,
      (B*)"matmul",         (B *)op_matmul,
      (B*)"mattranspose",   (B *)op_mattranspose,
      (B*)"dilute_add",     (B *)op_dilute_add,
      (B*)"matvecmul",      (B *)op_matvecmul,
      (B*)"getstartupdir",  (B *)op_getstartupdir,
      (B*)"gethomedir",     (B *)op_gethomedir,
#if BOOTSTRAP_PLUGIN
/*-- load library */
      (B*)"loadlib",       (B*) op_loadlib,
      (B*)"nextlib",       (B*) op_nextlib,
#endif
      (B*)"",               (B *)0L, 
 };

/*========================== Error Table =================================*/


P _syserrc[] = {
  TIMER,CORR_OBJ,LOST_CONN,
  VM_OVF, OPDS_OVF, EXECS_OVF, DICTS_OVF, 
  OPDS_UNF, EXECS_UNF, DICTS_UNF, 
  INV_EXT, INV_STOP, INV_EXITTO, EXECS_COR, INV_REST, 
  BAD_TOK, BAD_ASC, ARR_CLO, CLA_ARR, PRO_CLO,
  OPD_CLA, OPD_TYP, OPD_ERR, RNG_CHK, OPD_ATR, UNDF, DICT_ATR,
  DICT_OVF, DICT_USED, UNDF_VAL, DIR_NOSUCH,
  BADBOX, BAD_MSG, NOSYSTEM, INV_MSG, BAD_FMT,
  LIB_LOAD, LIB_EXPORT, LIB_LINK, LIB_ADD, LIB_LOADED, LIB_OVF,
  NO_XWINDOWS, X_ERR, X_BADFONT, X_BADHOST, MEM_OVF, BAD_ARR,
  LIB_LOAD, LIB_EXPORT, LIB_LINK, LIB_ADD, LIB_LOADED, LIB_OVF, LIB_MERGE,
  LIB_INIT,
  CLOCK_ERR, LONG_OVF, SOCK_STATE,
  NEED_SSL,
  0L,
};

B *_syserrm[] = {
  (B*)"** Timeout",
  (B*)"** Corrupted object",
  (B*)"** Lost connection",
  (B*)"** VM overflow",
  (B*)"** Operand stack overflow",
  (B*)"** Execution stack overflow",
  (B*)"** Dictionary stack overflow",
  (B*)"** Operand stack underflow",
  (B*)"** Execution stack underflow",
  (B*)"** Dictionary stack underflow",
  (B*)"** Invalid exit",
  (B*)"** Invalid stop",
  (B*)"** Invalid exitto",
  (B*)"** Execution stack corrupted",
  (B*)"** Execution stack holds discardable object",
  (B*)"** Bad token",
  (B*)"** Bad ASCII character",
  (B*)"** Unmatched array closure",
  (B*)"** Illegal class in array",
  (B*)"** Unmatched procedure closure",
  (B*)"** Operand class",
  (B*)"** Operand type in ",
  (B*)"** Operand class or type",
  (B*)"** Range check",
  (B*)"** Operand attribute",
  (B*)"** Undefined name",
  (B*)"** Dictionary attribute",
  (B*)"** Dictionary overflow",
  (B*)"** Dictionary used",
  (B*)"** Undefined value",
  (B*)"** No such directory/volume",
  (B*)"** File does not contain a box object",
  (B*)"** Bad message received on network",
  (B*)"** 'System' call to Linux failed",
  (B*)"** Invalid message format",
  (B*)"** Box not in native format",
  (B*)"** Unable to load operator library",
  (B*)"** Cannot find operator in library",
  (B*)"** Library has not been loaded",
  (B*)"** Cannot add operator to library dictionary",
  (B*)"** Library exists already",
  (B*)"** Insufficient memory for library",
  (B*)"** X windows unavailable",
  (B*)"** Error in X windows",
  (B*)"** Bad X windows font",
  (B*)"** Cannot connect to X server",
  (B*)"** Memory exhausted",
  (B*)"** dmnuminc debug error",
  (B*)"** Unable to load dynamically linked shared library",
  (B*)"** Unable to find object in shared library",
  (B*)"** Library has not been loaded",
  (B*)"** Unable to add operation to library dictionary",
  (B*)"** Library already loaded",
  (B*)"** Overflow in malloc while loading library",
  (B*)"** Unable to merge library into sysdict",
  (B*)"** Unable to initialize loaded library",
  (B*)"** Error accessing clock",
  (B*)"** Error loading 64 bit integer into 32 bit machine",
  (B*)"** Attempt to change file descriptor state",
  (B*)"** Need ssl to read sha1 stampted box"
};
