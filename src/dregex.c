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
#include "dm.h"

#include <sys/types.h>
#include <regex.h>
#include <stdlib.h>

#include "dregex.h"

#define REGEX_ERR(err) case REG_##err: return REGEX_##err

DM_INLINE_STATIC P int_regex_error(int e) 
{
  switch (e) {
    REGEX_ERR(BADPAT);
    REGEX_ERR(ECOLLATE);
    REGEX_ERR(ECTYPE);
    REGEX_ERR(EESCAPE);
    REGEX_ERR(ESUBREG);
    REGEX_ERR(EBRACK);
    REGEX_ERR(EPAREN);
    REGEX_ERR(EBRACE);
    REGEX_ERR(BADBR);
    REGEX_ERR(ERANGE);
    REGEX_ERR(ESPACE);
    REGEX_ERR(BADRPT);
  default:
    return REGEX_UNKNOWN;
  };
}

DM_INLINE_STATIC P int_regex(BOOLEAN case_sensitive) 
{
  char* string;
  regex_t preg;
  regmatch_t* pmatch;
  int r;
  unsigned int i;
  B* lframe;
  P retc = OK;
	
  if (o_2 < FLOORopds) return OPDS_UNF;
  if ((TAG(o_2) != (ARRAY | BYTETYPE)) ||
      (TAG(o_1) != (ARRAY | BYTETYPE)))
    return OPD_ERR;
  if (FREEvm + ARRAY_SIZE(o_1)+2 > CEILvm) return VM_OVF;
  if (CEILopds < o4) return OPDS_OVF;
  
  moveB(VALUE_PTR(o_1), FREEvm, ARRAY_SIZE(o_1));
  FREEvm[ARRAY_SIZE(o_1)] = '\0';
  
  if ((r = regcomp(&preg, (char*)FREEvm,
                   REG_EXTENDED|(case_sensitive ? 0 : REG_ICASE))))
    return int_regex_error(r);

  pmatch = (regmatch_t*) (FREEvm+FRAMEBYTES*(preg.re_nsub+1));
  string = ((char*) pmatch)+sizeof(regmatch_t)*(preg.re_nsub+1);
  if ((B*) string + ARRAY_SIZE(o_2)+2 > CEILvm) {
    retc = VM_OVF;
    goto EXIT;
  }

  moveB(VALUE_PTR(o_2), (B*)string, ARRAY_SIZE(o_2));
  string[ARRAY_SIZE(o_2)] = '\0';
  switch (r = regexec(&preg, string, preg.re_nsub+1, pmatch, 0)) {
    case 0:
      TAG(FREEvm) = LIST;
      ATTR(FREEvm) = PARENT;
      VALUE_PTR(FREEvm) = FREEvm+FRAMEBYTES;
      LIST_CEIL_PTR(FREEvm) = FREEvm+FRAMEBYTES*(preg.re_nsub+1);
      for (i = 1, lframe = FREEvm+FRAMEBYTES;
           i < preg.re_nsub+1;
           ++i, lframe += FRAMEBYTES) {
        if (pmatch[i].rm_so == -1) {
          TAG(lframe) = NULLOBJ;
          ATTR(lframe) = 0;
        }
        else {
          TAG(lframe) = ARRAY | BYTETYPE;
          VALUE_PTR(lframe) = VALUE_PTR(o_2) + pmatch[i].rm_so;
          ARRAY_SIZE(lframe) = pmatch[i].rm_eo - pmatch[i].rm_so;
          ATTR(lframe) = ATTR(o_2) & READONLY;
        }
      }
      
      TAG(o3) = BOOL;
      ATTR(o3) = 0;
      BOOL_VAL(o3) = TRUE;
      
      moveframe(FREEvm, o2);
      ATTR(o2) = 0;
			
      TAG(o1) = ARRAY | BYTETYPE;
      VALUE_PTR(o1) = VALUE_PTR(o_2);
      ARRAY_SIZE(o1) = pmatch[0].rm_so;
      ATTR(o1) = ATTR(o_2) & READONLY;
			
      TAG(o_1) = ARRAY | BYTETYPE;
      VALUE_PTR(o_1) = VALUE_PTR(o_2) + pmatch[0].rm_so;
      ARRAY_SIZE(o_1) = pmatch[0].rm_eo - pmatch[0].rm_so;
      ATTR(o_1) = ATTR(o_2) & READONLY;
			
      VALUE_PTR(o_2) += pmatch[0].rm_eo;
      ARRAY_SIZE(o_2) -= pmatch[0].rm_eo;
      ATTR(o_2) &= READONLY;
			
      FREEvm = (B*) pmatch;
      FREEopds = o4;
      break;
						
    case REG_NOMATCH:
      TAG(o_1) = BOOL;
      ATTR(o_1) = 0;
      BOOL_VAL(o_1) = FALSE;
      break;
						
    default:
      retc = int_regex_error(r);
      break;
  }

 EXIT:
  regfree(&preg);
  return retc;
}

DM_INLINE_STATIC P int_regexs(BOOLEAN case_sensitive) 
{
  regex_t preg;
  regmatch_t pmatch;
  int r;
  P retc = OK;
	
  if (o_2 < FLOORopds) return OPDS_UNF;
  if ((TAG(o_2) != (ARRAY | BYTETYPE)) ||
      (TAG(o_1) != (ARRAY | BYTETYPE)))
    return OPD_ERR;
  if (FREEvm + ARRAY_SIZE(o_1) + 1 >= CEILvm) return VM_OVF;
  if (FREEvm + ARRAY_SIZE(o_2) + 1 >= CEILvm) return VM_OVF;
  if (CEILopds < o3) return OPDS_OVF;
  
  moveB(VALUE_PTR(o_1), FREEvm, ARRAY_SIZE(o_1));
  FREEvm[ARRAY_SIZE(o_1)] = '\0';
  
  if ((r = regcomp(&preg, (char*)FREEvm,
                   REG_EXTENDED|(case_sensitive ? 0 : REG_ICASE))))
    return int_regex_error(r);

  moveB(VALUE_PTR(o_2), FREEvm, ARRAY_SIZE(o_2));
  FREEvm[ARRAY_SIZE(o_2)] = '\0';

  switch (r = regexec(&preg, (char*) FREEvm, 1, &pmatch, 0)) {
    case 0:      
      TAG(o2) = BOOL;
      ATTR(o2) = 0;
      BOOL_VAL(o2) = TRUE;
      
      moveframe(o_2, o1);
      ARRAY_SIZE(o1) = pmatch.rm_so;
			
      moveframe(o_2, o_1);
      VALUE_PTR(o_1) += pmatch.rm_so;
      ARRAY_SIZE(o_1) = pmatch.rm_eo - pmatch.rm_so;
			
      VALUE_PTR(o_2) += pmatch.rm_eo;
      ARRAY_SIZE(o_2) -= pmatch.rm_eo;

      FREEopds = o3;
      break;
						
    case REG_NOMATCH:
      TAG(o_1) = BOOL;
      ATTR(o_1) = 0;
      BOOL_VAL(o_1) = FALSE;
      break;
						
    default:
      retc = int_regex_error(r);
      break;
  }

  regfree(&preg);
  return retc;
}

/*------------------------------ op_regex
 * (string) (pattern) |
 * if found: (post) (match) (pre) [(submatch)...] true
 * else:                                 (string) false
 */

P op_regex(void) 
{
  return int_regex(TRUE);
}

/*------------------------------ op_regexi
 * (string) (pattern) |
 * if found: (post) (match) (pre) [(submatch)...] true
 * else:                                 (string) false
 * Done case-insensitively
 */

P op_regexi(void) 
{
  return int_regex(FALSE);
}

/*------------------------------ op_regexs
 * (string) (pattern) |
 * if found: (post) (match) (pre) true
 * else:                 (string) false
 */

P op_regexs(void) 
{
  return int_regexs(TRUE);
}

/*------------------------------ op_regexsi
 * (string) (pattern) |
 * if found: (post) (match) (pre) true
 * else:                 (string) false
 * Done case-insensitively
 */

P op_regexsi(void) 
{
  return int_regexs(FALSE);
}
