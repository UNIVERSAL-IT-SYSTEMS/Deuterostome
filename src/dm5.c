/*====================== D machine Rev3.0 (dm5.c) ======================

       -  operators:
          - exec
          - if
          - ifelse
          - for
          - repeat
          - loop
          - forall
          - exit
          - stop
          - stopped
          - countexecstack
          - execstack
          - quit
          - eq
          - ne
          - ge
          - gt
          - le
          - lt
          - and
          - not
          - or
          - xor
          - bitshift
*/

#include "dm.h"
#include <stdio.h>

/*----------------------------------------------- start
   any_active | --

   drops the currently executing object from the execution stack and
   pushes any_active on the execution stack.
*/

L op_start(void)
{

if (o_1 < FLOORopds) return(OPDS_UNF);
if ((ATTR(o_1) & ACTIVE) == 0) return(OPD_ATR);
moveframes(o_1,FREEexecs-FRAMEBYTES,1L);
FREEopds = o_1;
return(OK);
}

/*----------------------------------------------- exec
   any_active | --

   pushes any_active on the execution stack
*/

L op_exec(void)
{
if (o_1 < FLOORopds) return(OPDS_UNF);
if ((ATTR(o_1) & ACTIVE) == 0) return(OPD_ATR);
if (x1 >= CEILexecs) return(EXECS_OVF);
moveframe(o_1,x1);
FREEopds = o_1; FREEexecs = x2;
return(OK);
}

/*----------------------------------------------- if
   bool proc | ---
*/

L op_if(void)
{
if (o_2 < FLOORopds) return(OPDS_UNF);
if ((CLASS(o_2) != BOOL)) return(OPD_CLA);
if ((ATTR(o_1) & ACTIVE) == 0) return(OPD_ATR);
if (BOOL_VAL(o_2))
   { if (x1 >= CEILexecs) return(EXECS_OVF);
     moveframes(o_1, x1, 1L); FREEexecs = x2;
   } 
FREEopds = o_2;
return(OK);
}

/*----------------------------------------------- ifelse
   bool proc1 proc2 | ---
*/

L op_ifelse(void)
{
if (o_3 < FLOORopds) return(OPDS_UNF);
if (CLASS(o_3) != BOOL) return(OPD_CLA);
if (((ATTR(o_2) & ACTIVE) == 0) || ((ATTR(o_1) & ACTIVE) == 0))
   return(OPD_ATR);
if (x1 >= CEILexecs) return(EXECS_OVF);
if (BOOL_VAL(o_3)) moveframes(o_2, x1,1L); else moveframes(o_1, x1,1L);
FREEexecs = x2; FREEopds = o_3;
return(OK);
}

/*----------------------------------------------- for
   first step limit proc | ---

                              proc
     x_for                    x_for
     proc                     proc
     limit                    limit
     step                     step
   * first                  * current      (* = exit mark)

*/
static L x_op_for(void)
{
if (COMPARE(x_4,x_2) == TEST(x_3)) /* i.e. GT/GT, LT/LT, EQ/EQ */
   FREEexecs = x_4;
   else
   { if (o1 >= CEILopds) return(OPDS_OVF);
     moveframes(x_4, o1, 1L);
     FREEopds = o2;
     moveframes(x_1,x2,1L);
     ADD(x_4,x_3);
     FREEexecs = x3; 
   }
return(OK);
}

/*----------------------------------------- replace_active_name
   replaces a frame of an active name, with the object to which
   it points if that object is active (otherwise, null op)
*/
void replace_active_name(B* frame)
{
    B* dict = FREEdicts;
    B* newframe;
    while((dict -= FRAMEBYTES) > FLOORdicts)
        if ((newframe = lookup(frame, VALUE_PTR(dict))) != 0L)
        {
            if ((ATTR(newframe) & ACTIVE) == 0) return;
            moveframe(newframe, frame);
            return;
        }
}

L op_for(void)
{
if (o_4 < FLOORopds) return(OPDS_UNF);
if ((CLASS(o_4) != NUM) || (CLASS(o_3) != NUM) ||
    (CLASS(o_2) != NUM)) return(OPD_CLA);
if ((ATTR(o_1) & ACTIVE) == 0) return(OPD_ATR);
if ((TEST(o_4) == UN) || (TEST(o_3) == UN) ||
    (TEST(o_2) == UN)) return(UNDF_VAL); 
if (x6 >= CEILexecs) return(EXECS_OVF);

if (CLASS(o_1) == NAME) replace_active_name(o_1);
 
ATTR(o_4) |= EXITMARK;
moveframes(o_4,x1,4L);
TAG(x5) = OP; ATTR(x5) = ACTIVE;
OP_NAME(x5) = (L)"x_for"; OP_CODE(x5) = (L)x_op_for;
FREEexecs = x6; FREEopds = o_4;
return(OK);
}

/*--------------------------------------------- repeat
    count proc | --

                    proc
     x_repeat       x_repeat
     proc           proc
   * count        * count          (exitmark)

*/

static L x_op_repeat(void)
{
W t;

t = TEST(x_2);
if ((t == LT) || (t == EQ)) { FREEexecs = x_2; return(OK); }
DECREMENT(x_2);
moveframes(x_1, x2, 1L);
FREEexecs = x3;
return(OK);
}

L op_repeat(void)
{
if (o_2 < FLOORopds) return(OPDS_UNF);
if ((CLASS(o_2) != NUM)) return(OPD_CLA);
if ((ATTR(o_1) & ACTIVE) == 0) return(OPD_ATR);
if (TEST(o_2) == UN) return(UNDF_VAL);
if (x4 >= CEILexecs) return(EXECS_OVF);
if (CLASS(o_1) == NAME) replace_active_name(o_1); 
ATTR(o_2) |= EXITMARK;
moveframes(o_2, x1, 2L);
TAG(x3) = OP; ATTR(x3) = ACTIVE;
OP_NAME(x3) = (L)"x_repeat"; OP_CODE(x3) = (L)x_op_repeat;
FREEopds = o_2; FREEexecs = x4;
return(OK);
}

/*------------------------------------------------ loop
   proc | --

                    proc
     x_loop         x_loop
   * proc         * proc           (exitmark)
*/

static L x_op_loop(void)
{
moveframes(x_1,x2, 1L);
ATTR(x2) &= (~XMARK);          /* no replication of exitmark! */
FREEexecs = x3;
return(OK);
}

L op_loop(void)
{
if (o_1 < FLOORopds) return(OPDS_UNF);
if ((ATTR(o_1) & ACTIVE) == 0) return(OPD_ATR);
if (x4 >= CEILexecs) return(EXECS_OVF);
if (CLASS(o_1) == NAME) replace_active_name(o_1); 
ATTR(o_1) |= EXITMARK; moveframes(o_1, x1, 1L);
TAG(x2) = OP; ATTR(x2) = ACTIVE;
OP_NAME(x2) = (L)"x_loop"; OP_CODE(x2) = (L)x_op_loop;
FREEexecs = x3; FREEopds = o_1;
return(OK);
}

/*---------------------------------------------- forall
     array proc | ---
      list proc | ---
      dict proc | ---

                                proc
      x_forall                  x_forall
      proc                      proc
   *  array/list/dict         * array/list/dict
*/

static L x_op_forall(void)
{
B *dict, *entry;

switch(CLASS(x_2))
     {
     case ARRAY: if (ARRAY_SIZE(x_2) <= 0)
                    { FREEexecs = x_2; return(OK); }
                 if (o1 >= CEILopds) return(OPDS_OVF);
                 TAG(o1) = NUM | TYPE(x_2); ATTR(o1) = 0;
                 MOVE(x_2,o1);
                 VALUE_BASE(x_2) +=  VALUEBYTES(TYPE(x_2));
                 ARRAY_SIZE(x_2)--; FREEopds = o2;
                 break;
     case LIST:  if (VALUE_BASE(x_2) >= LIST_CEIL(x_2))
                    { FREEexecs = x_2; return(OK); }
                 if (o1 >= CEILopds) return(OPDS_OVF);
                 moveframes((B *)VALUE_BASE(x_2),o1,1L);
                 FREEopds = o2;
                 VALUE_BASE(x_2) += FRAMEBYTES;
                 break;
     case DICT:  dict = (B *)VALUE_BASE(x_2);
                 if (DICT_CURR(x_2) >= DICT_FREE(dict))
                    { FREEexecs = x_2; return(OK); }
                 if (o2 >= CEILopds) return(OPDS_OVF);
                 entry = (B *)DICT_CURR(x_2); 
								 DICT_CURR(x_2) += ENTRYBYTES;
                 moveframes(ASSOC_NAME(entry),o1,1L);
                 ATTR(o1) = 0;
                 moveframes(ASSOC_FRAME(entry),o2,1L);
                  FREEopds = o3; break;
     default: return(EXECS_COR);
     }
moveframes(x_1,x2, 1L); FREEexecs = x3;
return(OK);
}

L op_forall(void)
{
B *dict;

if (o_2 < FLOORopds) return(OPDS_UNF);
if ((ATTR(o_1) & ACTIVE) == 0) return(OPD_ATR);
if (x3 >= CEILexecs) return(EXECS_OVF);
switch(CLASS(o_2))
     {
     case ARRAY: break;
     case LIST:  break;
     case DICT:  dict = (B *)VALUE_BASE(o_2);
                 DICT_CURR(o_2) = DICT_ENTRIES(dict); break;
     default: return(OPD_CLA);
     }
if (CLASS(o_1) == NAME) replace_active_name(o_1); 
moveframes(o_2,x1,2L); ATTR(x1) |= EXITMARK;
TAG(x3) = OP; ATTR(x3) = ACTIVE;
OP_NAME(x3) = (L)"x_forall"; OP_CODE(x3) = (L)x_op_forall;
FREEexecs = x4; FREEopds = o_2;
return(OK);
}

/*---------------------------------------------- exit */

L op_exit(void)
{
B *frame; W m;

frame = FREEexecs;
while ((frame -= FRAMEBYTES) >= FLOORexecs)
 {
     if ((m = ATTR(frame) & XMARK))
     {
        if (m == EXITMARK) { FREEexecs = frame; return(OK); }
        else return(INV_EXT);
     }     
 }
return(EXECS_UNF);
} 

/*----------------------------------------------- stop */

L op_stop(void)
{
B *frame; W m; 

frame = FREEexecs;
while ((frame -= FRAMEBYTES) >= FLOORexecs)
 {
     if ((m = ATTR(frame) & XMARK))
     {
        if (m == STOPMARK)
           { BOOL_VAL(frame) = TRUE; ATTR(frame) &= (~XMARK);
             FREEexecs = frame + FRAMEBYTES; return(OK); }
        else if (m == ABORTMARK) return(INV_STOP);
     }
 }
return(EXECS_UNF);
} 

/*----------------------------------------------- stopped
   any_active | bool

    any     
  * false 
*/

L op_stopped(void)
{
if (o_1 < FLOORopds) return(OPDS_UNF);
if ((ATTR(o_1) & ACTIVE) == 0) return(OPD_ATR);
if (x3 > CEILexecs) return(EXECS_OVF);
TAG(x1) = BOOL; ATTR(x1) = (STOPMARK | ACTIVE);
BOOL_VAL(x1) = FALSE;
moveframes(o_1, x2, 1L); FREEexecs = x3;
FREEopds = o_1;
return(OK);
}

/*----------------------------------------------- countexecstack
    --- | int
  returns number of elements on execution stack
*/

L op_countexecstack(void)
{
if (o1 >= CEILopds) return(OPDS_OVF);
TAG(o1) = NUM | LONGTYPE; ATTR(o1) = 0;
LONG_VAL(o1) = (FREEexecs-FLOORexecs) / FRAMEBYTES;
FREEopds = o2;
return(OK);
}

/*-------------------------------------- execstack
  list | sublist

  stores all elements of the execution stack into the list and
  returns the sublist of copied elements in the list.
*/

L op_execstack(void)
{
B *eframe; L n,nb;

if (o_1 < FLOORopds) return(OPDS_UNF);
if (CLASS(o_1) != LIST) return(OPD_CLA);
nb = FREEexecs - FLOORexecs; n = nb / FRAMEBYTES;
if (nb > (LIST_CEIL(o_1) - VALUE_BASE(o_1))) return(RNG_CHK);
moveframes(FLOORexecs, (B *)VALUE_BASE(o_1), n);
ATTR(o_1) &= (~PARENT);
LIST_CEIL(o_1) = VALUE_BASE(o_1) + nb;
for (eframe = (B *)VALUE_BASE(o_1); eframe < (B *)LIST_CEIL(o_1);
     eframe += FRAMEBYTES)
     { ATTR(eframe) &= (~XMARK);
       if (CLASS(eframe) == DICT)
          moveframes((B *)VALUE_BASE(eframe)-FRAMEBYTES,
                     eframe,1L); /* restore frame's DICT_NB */
     }
return(OK);
}

/*--------------------------------------------------- quit
   ---|---
*/

L op_quit(void)  {  return(QUIT); }

/*---------------------------------------------------- eq
   any1 any2 | bool

simple objects:     equality of values (including undefined)
composite objects:  identity of values (i.e. shared VM) 

*/

L op_eq(void)
{
BOOLEAN t;

if (o_2 < FLOORopds) return(OPDS_UNF);
if (CLASS(o_2) == CLASS(o_1))
   { switch(CLASS(o_2))
      {
      case MARK: t=TRUE; break;
      case NULLOBJ: 
				if (TYPE(o_1) != TYPE(o_2)) {t = FALSE; break;};
				switch (TYPE(o_1)) {
				  case SOCKETTYPE: 
						t = (LONG_VAL(o_1) == LONG_VAL(o_2)) ? TRUE : FALSE;
						break;
				  default: t=TRUE; break;
				};
				break;
      case NUM: t = COMPARE(o_2,o_1);
                if (t == UN) { t = ((TEST(o_2) == UN) && (TEST(o_1) == UN));
                               break; }
                if (t == EQ) t = TRUE; else t = FALSE; break;
      case BOOL: if (BOOL_VAL(o_2) == BOOL_VAL(o_1)) t = TRUE;
                 else t = FALSE; break;
      case OP: if ((OP_NAME(o_2) == OP_NAME(o_1)) &&
                   (OP_CODE(o_2) == OP_CODE(o_1))) t = TRUE;
                   else t = FALSE; break;
      case NAME: if ( (NAME_KEY(o_2) == NAME_KEY(o_1)) &&
                      matchname(o_2,o_1)
                    ) t = TRUE; else t = FALSE; break;
      case ARRAY: 
      case LIST:
      case DICT:
      case BOX:  t = ((VALUE_BASE(o_2) == VALUE_BASE(o_1)) &&
                      (ARRAY_SIZE(o_2) == ARRAY_SIZE(o_1)));
                 break;
      default: return OPD_CLA; // never happen
      } 
   }
   else t = FALSE;
TAG(o_2) = BOOL; ATTR(o_2) = 0; BOOL_VAL(o_2) = t;
FREEopds = o_1;
return(OK);
}

/*---------------------------------------------------- ne
   any1 any2 | bool

simple objects:     equality of values
composite objects:  identity of values (shared VM)
*/

L op_ne(void)
{
BOOLEAN t;

if (o_2 < FLOORopds) return(OPDS_UNF);
if (CLASS(o_2) == CLASS(o_1))
   { switch(CLASS(o_2))
      {
      case MARK: t=FALSE; break;
      case NULLOBJ: 
				if (TYPE(o_1) != TYPE(o_2)) {t = TRUE; break;};
				switch (TYPE(o_1)) {
				  case SOCKETTYPE:
						t = (LONG_VAL(o_1) != LONG_VAL(o_2)) ? TRUE : FALSE;
						break;
				  default: t=FALSE; break;
				};
				break;
      case NUM: t = COMPARE(o_2,o_1);
                if (t == UN) { t = ((TEST(o_2) != UN) || (TEST(o_1) != UN));
                               break; }
                if (t != EQ) t = TRUE; else t = FALSE; break;
      case BOOL: if (BOOL_VAL(o_2) != BOOL_VAL(o_1)) t = TRUE;
                 else t = FALSE; break;
      case OP: if ((OP_NAME(o_2) != OP_NAME(o_1)) ||
                   (OP_CODE(o_2) != OP_CODE(o_1))) t = TRUE;
                   else t = FALSE; break;
      case NAME: if ( (NAME_KEY(o_2) == NAME_KEY(o_1)) &&
                      matchname(o_2,o_1)
                    ) t = FALSE; else t = TRUE; break;
      case ARRAY: 
      case LIST:
      case DICT:
      case BOX:  t = ((VALUE_BASE(o_2) != VALUE_BASE(o_1)) ||
                      (ARRAY_SIZE(o_2) != ARRAY_SIZE(o_1)));
                 break;
      default: return OPD_CLA; //never happen
      } 
   }
   else t = TRUE;
TAG(o_2) = BOOL; ATTR(o_2) = 0; BOOL_VAL(o_2) = t;
FREEopds = o_1;
return(OK);
}

/*---------------------------------------------------- ge
   num1 num2 | bool
*/

L op_ge(void)
{
W t;

if (o_2 < FLOORopds) return(OPDS_UNF);
if ((CLASS(o_2) != NUM) || (CLASS(o_1) != NUM)) return(OPD_CLA);
t = COMPARE(o_2,o_1);  if (t == UN) return(UNDF_VAL);
BOOL_VAL(o_2) = ((t == EQ) || (t == GT));
TAG(o_2) = BOOL; ATTR(o_2) = 0;
FREEopds = o_1;
return(OK);
}

/*---------------------------------------------------- gt
   num1 num2 | bool
*/

L op_gt(void)
{
W t;

if (o_2 < FLOORopds) return(OPDS_UNF);
if ((CLASS(o_2) != NUM) || (CLASS(o_1) != NUM)) return(OPD_CLA);
t = COMPARE(o_2,o_1);  if (t == UN) return(UNDF_VAL);
BOOL_VAL(o_2) = (t == GT); TAG(o_2) = BOOL; ATTR(o_2) = 0;
FREEopds = o_1;
return(OK);
}

/*---------------------------------------------------- le
   num1 num2 | bool
*/

L op_le(void)
{
W t;

if (o_2 < FLOORopds) return(OPDS_UNF);
if ((CLASS(o_2) != NUM) || (CLASS(o_1) != NUM)) return(OPD_CLA);
t = COMPARE(o_2,o_1);  if (t == UN) return(UNDF_VAL);
BOOL_VAL(o_2) = ((t == EQ) || (t == LT));
TAG(o_2) = BOOL; ATTR(o_2) = 0;
FREEopds = o_1;
return(OK);
}

/*---------------------------------------------------- lt
   num1 num2 | bool
*/

L op_lt(void)
{
W t;

if (o_2 < FLOORopds) return(OPDS_UNF);
if ((CLASS(o_2) != NUM) || (CLASS(o_1) != NUM)) return(OPD_CLA);
t = COMPARE(o_2,o_1); if (t == UN) return(UNDF_VAL);
BOOL_VAL(o_2) = (t == LT); TAG(o_2) = BOOL; ATTR(o_2) = 0;
FREEopds = o_1;
return(OK);
}

/*---------------------------------------------------- and
     num1 num2 | num     (result is of type of num1)
   bool1 bool2 | bool
*/

L op_and(void)
{
L n[2];

if (o_2 < FLOORopds) return(OPDS_UNF);
if (CLASS(o_2) != CLASS(o_1)) return(OPD_ERR);
n[0] = n[1] = 0;
switch (CLASS(o_2))
   {
   case NUM: moveB(NUM_VAL(o_1) + VALUEBYTES(TYPE(o_1)) - VALUEBYTES(TYPE(o_2)),
               (B *)n,VALUEBYTES(TYPE(o_2)));
             *((L *)(NUM_VAL(o_2))) &= n[0];
             *(((L *)(NUM_VAL(o_2))) + 1) &= n[1];
             break;
   case BOOL: BOOL_VAL(o_2) &= BOOL_VAL(o_1); break;
   default: return(OPD_CLA);
   }
FREEopds = o_1;
return(OK);
}

/*---------------------------------------------------- not
     num | num
    bool | bool
*/

L op_not(void)
{
if (o_1 < FLOORopds) return(OPDS_UNF);
switch (CLASS(o_1))
   {
   case NUM: *((L *)(NUM_VAL(o_1))) = ~(*((L *)(NUM_VAL(o_1))));
             *(((L *)(NUM_VAL(o_1))) + 1) = ~(*(((L *)(NUM_VAL(o_1))) + 1));
             break;
   case BOOL: BOOL_VAL(o_1) = !BOOL_VAL(o_1); break;
   default: return(OPD_CLA);
   }
return(OK);
}

/*---------------------------------------------------- or
     num1 num2 | num  (result is of first operand type)
   bool1 bool2 | bool
*/

L op_or(void)
{
L n[2];

if (o_2 < FLOORopds) return(OPDS_UNF);
if (CLASS(o_2) != CLASS(o_1)) return(OPD_ERR);
n[0] = n[1] = 0;
switch (CLASS(o_2))
   {
   case NUM: moveB(NUM_VAL(o_1) + VALUEBYTES(TYPE(o_1)) - VALUEBYTES(TYPE(o_2)),
               (B *)n,VALUEBYTES(TYPE(o_2)));
             *((L *)(NUM_VAL(o_2))) |= n[0];
             *(((L *)(NUM_VAL(o_2))) + 1) |= n[1];
             break;
   case BOOL: BOOL_VAL(o_2) |= BOOL_VAL(o_1); break;
   default: return(OPD_CLA);
   }
FREEopds = o_1;
return(OK);
}
/*---------------------------------------------------- xor
     num1 num2 | num   (result is of first operand type)
   bool1 bool2 | bool
*/

L op_xor(void)
{
L n[2];

if (o_2 < FLOORopds) return(OPDS_UNF);
if (CLASS(o_2) != CLASS(o_1)) return(OPD_ERR);
n[0] = n[1] = 0;
switch (CLASS(o_2))
   {
   case NUM: moveB(NUM_VAL(o_1) + VALUEBYTES(TYPE(o_1)) - VALUEBYTES(TYPE(o_2)),
               (B *)n,VALUEBYTES(TYPE(o_2)));
             *((L *)(NUM_VAL(o_2))) ^= n[0];
             *(((L *)(NUM_VAL(o_2))) + 1) ^= n[1];
             break;
   case BOOL: if (BOOL_VAL(o_2) != BOOL_VAL(o_1))
              BOOL_VAL(o_2) = TRUE; else BOOL_VAL(o_2) = FALSE;
              break;
   default: return(OPD_CLA);
   }
FREEopds = o_1;
return(OK);
}

/*---------------------------------------------------- bitshift
     num count | num
*/

L op_bitshift(void)
{
L n,c;

if (o_2 < FLOORopds) return(OPDS_UNF);
if ((CLASS(o_2) != NUM) || (CLASS(o_1) != NUM)) return(OPD_CLA);
if (VALUEBYTES(TYPE(o_2)) > 4) return(OPD_ERR);
if (!VALUE(o_1,&c)) return(UNDF_VAL);
n = 0;
moveB(NUM_VAL(o_2),(B *)&n,VALUEBYTES(TYPE(o_2)));
if (c < 0)  { n = n >> (-c); }
 else if (c > 0) { n = n << c; }
moveB((B *)&n,NUM_VAL(o_2),VALUEBYTES(TYPE(o_2)));
FREEopds = o_1;
return(OK);
}

