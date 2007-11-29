/*====================== D machine Rev3.0 (dm6.c) =======================

    - check FPU exception
          - checkFPU

    - monadic math operators
          - neg
          - abs
          - sqrt
          - exp
          - ln
          - lg
          - cos
          - sin
          - tan
          - atan
          - floor
          - ceil
          - acos
          - asin

    - universal copy/conversion operator
          - copy

    - dyadic math operators
          - add
          - sub
          - mul
          - div
          - pwr

    - VM operators / bind
          - save
          - restore
          - vmstatus
          - bind

    - class / type / attribute / conversion / string operators
          - class
          - type
          - readonly
          - active
          - mkread
          - mkact
          - mkpass
          - ctype
          - parcel
          - text
          - number
          - token
          - search
          - anchorsearch

*/

#include "dm.h"
#include <string.h>
#include <stdio.h>
#include <math.h>

/*---------------------------------------------------- checkFPU
     -- | bool

  the boolean signals that an FPU exception has occurred since the
  last check; the exception is cleared.
*/

P op_checkFPU(void)
{
  if (o1 > CEILopds) return OPDS_OVF;
  TAG(o1) = BOOL; 
  ATTR(o1) = 0; 
  BOOL_VAL(o1) = numovf;
  numovf = FALSE;
  FREEopds = o2;
  return OK;
}
  
/*---------------------------------------------------- dyadic
     num1 num2 | num1         - add to first scalar
    array1 num | array1       - add numeral to all array elements
 array1 array2 | array1       - add second array onto first

 No restriction on type; 'add' stands for any dyadic operation.
*/

static P dyadop(void)
{
  if (o_2 < FLOORopds) return OPDS_UNF;
  if (ATTR(o_2) & READONLY) return OPD_ATR;
  switch(CLASS(o_2))  { 
    case NUM:  
      switch(CLASS(o_1)) { 
        case NUM: break;
        case ARRAY: break;
        default: return OPD_CLA;
      }
      break;

    case ARRAY: 
      switch(CLASS(o_1)) { 
        case NUM: break;
        case ARRAY:
          if (ARRAY_SIZE(o_2) != ARRAY_SIZE(o_1))
            return RNG_CHK;
          break;
        default: return OPD_CLA;
      }
      break;

    default: 
      return OPD_CLA;
  }

  FREEopds = o_1;
  return OK;
}

P op_thearc(void)
{
  P retc;
  if ((retc = dyadop()) != OK) return retc;
  THEARC(o_1,o1);
  return OK;
}

P op_mod(void)
{
  P retc;
  if ((retc = dyadop()) != OK) return retc;
  MOD(o_1,o1);
  return OK;
}

P op_add(void)
{
  P retc;
  if ((retc = dyadop()) != OK) return retc;
  ADD(o_1,o1);
  return OK;
}

P op_sub(void)
{
  P retc;
  if ((retc = dyadop()) != OK) return retc;
  SUB(o_1,o1);
  return OK;
}

P op_mul(void)
{
  P retc;
  if ((retc = dyadop()) != OK) return retc;
  MUL(o_1,o1);
  return OK;
}

P op_div(void)
{
  P retc;
  if ((retc = dyadop()) != OK) return retc;
  DIV(o_1,o1);
  return OK;
}

P op_pwr(void)
{
  P retc;
  if ((retc = dyadop()) != OK) return retc;
  PWR(o_1,o1);
  return OK;
}

/*-------------------------------------------------- copy
   any1..anyn n | any1..anyn any1..anyn

copies n top elements of operand stack excluding n.

  array1 array2   | subarray2
    num1 array2   | array2
    list1 list2   | sublist2

copies all elements of the first composite object into the second,
starting at index zero of the destination (array or list), and returning
the subarray/list filled by the copy (the remainder of the destination
object is unaffected). The arrays/numeral may be of different types,
then invoking automatic conversion; an array may be copied into a
differently typed replica of itself, thus converting it in place
(towards a type of equal or smaller width). With a numeral in the
place of a first array, the numeral is expanded to fill the entire
destination array, which then is returned. The resulting object
inherits the destination attributes.

NB: internals only

*/

P op_copy(void)
{
  B *from, *cframe, cframebuf[FRAMEBYTES];
  P n;
  P nb;

  cframe = cframebuf;
  if (o_1 < FLOORopds) return OPDS_UNF;

  if (CLASS(o_1) == NUM) {          /* copy operand stack elements */
    if (!PVALUE(o_1,&n)) return UNDF_VAL;
    if (n < 0) return RNG_CHK;
    nb = n * FRAMEBYTES;
    if ((from = o_1 - nb) < FLOORopds) return RNG_CHK;
    if ((o_1 + nb) > CEILopds) return RNG_CHK;
    moveframes(from, o_1, n);
    FREEopds = o_1 + nb;
    return OK;
  }

  if (o_2 < FLOORopds) return OPDS_UNF;
  if (ATTR(o_1) & READONLY) return OPD_ATR;

  switch(CLASS(o_2)) {
    case NUM:
      switch (CLASS(o_1)) {
        case ARRAY:
          MOVE(o_2,o_1);
          moveframe(o_1,o_2);
          break;

        default: 
          return OPD_CLA;
      }
      break;
			 
    case ARRAY: 
      if (CLASS(o_1) != ARRAY) return OPD_CLA;
      if (ARRAY_SIZE(o_1) < ARRAY_SIZE(o_2)) return RNG_CHK;
      ARRAY_SIZE(o_1) = ARRAY_SIZE(o_2);
      MOVE(o_2,o_1);
      moveframe(o_1,o_2);
      ATTR(o_2) &= (~PARENT);
      break;

    case LIST: 
      if (CLASS(o_1) != LIST) return OPD_CLA;
      nb = LIST_CEIL(o_2) - VALUE_BASE(o_2);
      n = nb / FRAMEBYTES;
      if ( (n <=0) || ((LIST_CEIL(o_1) - VALUE_BASE(o_1)) < nb))
        return RNG_CHK;
      moveframes((B *)VALUE_BASE(o_2), (B *)VALUE_BASE(o_1), n);
      moveframe(o_1,o_2);
      LIST_CEIL(o_2) = VALUE_BASE(o_2) + nb;
      ATTR(o_2) &= (~PARENT);
      break;

    default: return OPD_CLA;
  }

  FREEopds = o_1;
  return OK;
}

/*---------------------------------------------------- monadic
     num | num
   array | array

 No restriction on type.
*/
static P monop(void)
{
  if (o_1 < FLOORopds) return OPDS_UNF;
  if (ATTR(o_1) & READONLY) return OPD_ATR;
  switch(CLASS(o_1)) { 
    case NUM: break;
    case ARRAY: break;
    default: return OPD_CLA;
  }
  return OK;
}

P op_neg(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  NEG(o_1);
  return OK;
}

P op_abs(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  ABS(o_1);
  return OK;
}

P op_sqrt(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  SQRT(o_1);
  return OK;
}

P op_exp(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  EXP(o_1);
  return OK;
}

P op_ln(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  LN(o_1);
  return OK;
}

P op_lg(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  LG(o_1);
  return OK;
}

P op_cos(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  COS(o_1);
  return OK;
}

P op_sin(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  SIN(o_1);
  return OK;
}

P op_tan(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  TAN(o_1);
  return OK;
}

P op_atan(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  ATAN(o_1);
  return OK;
}

P op_floor(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  FLOOR(o_1);
  return OK;
}

P op_ceil(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  CEIL(o_1);
  return OK;
}

P op_asin(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  ASIN(o_1);
  return OK;
}

P op_acos(void)
{
  P retc;
  if ((retc = monop()) != OK) return retc;
  ACOS(o_1);
  return OK;
}

/*----------------------------------------------- save
     --- | VM_box
     
  - creates a box object in VM
  - returns the box object
*/

P op_save(void)
{
  B *bf, *bv;

  if (o1 >= CEILopds) return OPDS_OVF;
  if ((FREEvm + FRAMEBYTES + SBOXBYTES) > CEILvm) return VM_OVF;
  bf = FREEvm; bv = bf + FRAMEBYTES;
  SBOX_FLAGS(bv) = 0; 
  memset((B*) SBOX_DATA(bv), 0, SBOX_DATA_SIZE);
  SBOX_CAP(bv) = (B *)0;
  TAG(bf) = BOX; ATTR(bf) = PARENT;
  VALUE_BASE(bf) = (P)bv; BOX_NB(bf) = SBOXBYTES;
  FREEvm = bv + SBOXBYTES;
  moveframe(bf,o1); FREEopds = o2;
  return OK;
}

/*----------------------------------------------- capsave
     VM_box | ---
     
  - requires a box object from a preceding 'save'
  - modifies the box value to direct 'restore' to discard objects created
    between 'save' and 'capsave', retaining objects created following 'capsave'
*/

P op_capsave(void)
{
  B *box;
  if (o_1 < FLOORopds) return OPDS_UNF;
  if (CLASS(o_1) != BOX) return OPD_CLA;
  box = (B *)VALUE_BASE(o_1); SBOX_CAP(box) = FREEvm;
  FREEopds = o_1;
  return OK;
}

static void shift_subframe(B* frame, P offset) 
{
		VALUE_PTR(frame) -= offset;
		switch (CLASS(frame)) {
				case LIST: LIST_CEIL(frame) -= offset; break;
		}
}


/*----------------------------------------------- restore
     VM_box | ---

  - requires a box object from a preceding 'save' (optionally capped by
    'capsave')
  - objects following 'box' in VM will be discarded up to the VM freespace
    (no cap) or to the VM level established by 'capsave'
  - terminates if the execution stack holds references to discardable objects
  - NOTE: uncapped saves handle objects on any stack in the save box
    by removing them from that stack.
  - if cap exists, moves down all objects located above the cap to repack VM;
    in the process, corrects masterframes and dictionary values for the offset
  - replaces discardable objects in retained lists by nulls, maintaining
    their 'active' attribute
  - removes associations to discardable objects (name and object) from
    retained dictionaries
  - adjusts VM freespace
  - NOTE: since we have in the linux version all operator dictionaries
    (system and external) stored ABOVE the VM ceiling, these need be
    exempted from address modifications made to shifted objects
  - NOTE: we no longer support restoration of operand and dictionary
    stacks from uncapped 'save' objects
  - Added cleanup handlers. If the SBOX_FLAGS has SBOX_CLEANUP set,
    SBOX_DATA points to an OPNAME and OPCODE pair. These are used to
    construct an OP called with the first object in the box as operand.
    This is done instead of the restore - the op should finish be calling
    restore again (that time, a normal restore will be done).
    All boxes are walked through prior to actually doing a restore, to find
    save boxes inside that have SBOX_FLAGS_CLEANUP set (which is of course
    checked recursively).
 */
P x_op_restore(void) 
{
	B *cframe, *frame, *dict, *tdict, *entry, *box, *savebox,
		*caplevel, *savefloor, *topframe;
	P nb, offset;
	BOOLEAN capped;

	if (o_1 < FLOORopds) return OPDS_UNF;
	if (CLASS(o_1) != BOX) return OPD_CLA;
	savebox = (B *)VALUE_BASE(o_1);
	savefloor = (B *)VALUE_BASE(o_1) - FRAMEBYTES;
	if ((caplevel = SBOX_CAP(savebox)) == (B *)0) { 
		capped = FALSE; caplevel = FREEvm; 
	}
	else capped = TRUE;
	offset = caplevel - savefloor;
	FREEopds = o_1;

	topframe = cframe = FREEexecs - FRAMEBYTES;
	while (cframe >= FLOORexecs) {
    if (COMPOSITE(cframe)
				&& (VALUE_BASE(cframe) >= (P)savefloor)
				&& (VALUE_BASE(cframe) < (P)caplevel)) {
			if (capped) return INV_REST;
			moveframes(cframe + FRAMEBYTES,
								 cframe,
								 (topframe - cframe)/FRAMEBYTES);
			topframe -= FRAMEBYTES;
			FREEexecs -= FRAMEBYTES;
    }
    cframe -= FRAMEBYTES;
	}
 
	topframe = cframe = FREEdicts - FRAMEBYTES;
	while (cframe >= FLOORdicts) {
    if (COMPOSITE(cframe)
				&& (VALUE_BASE(cframe) >= (P)savefloor)
				&& (VALUE_BASE(cframe) < (P)caplevel)) {
			if (capped) return INV_REST;
			moveframes(cframe + FRAMEBYTES,
								 cframe,
								 (topframe - cframe)/FRAMEBYTES);
			topframe -= FRAMEBYTES;
			FREEdicts -= FRAMEBYTES;
    }
    cframe -= FRAMEBYTES;
	}
 
	topframe = cframe = FREEopds - FRAMEBYTES;
	while (cframe >= FLOORopds) {
    if (COMPOSITE(cframe)
				&& (VALUE_BASE(cframe) >= (P)savefloor)
				&& (VALUE_BASE(cframe) < (P)caplevel)) {
			if (capped) return INV_REST;
			moveframes(cframe + FRAMEBYTES,
								 cframe,
								 (topframe - cframe)/FRAMEBYTES);
			topframe -= FRAMEBYTES;
			FREEopds -= FRAMEBYTES;
    }
    cframe -= FRAMEBYTES;
	}
 
	if (capped)
		moveLBIG((LBIG*)caplevel, (LBIG*)savefloor, 
             (FREEvm - caplevel)/sizeof(LBIG));

	FREEvm -= offset;
	cframe = FLOORvm;
	while (cframe < FREEvm) {
		switch(CLASS(cframe)) {
			case ARRAY: 
				nb = DALIGN(ARRAY_SIZE(cframe) * VALUEBYTES(TYPE(cframe)));
				if (VALUE_BASE(cframe) >= (P)caplevel)
					VALUE_BASE(cframe) -= offset;
				cframe += nb + FRAMEBYTES; 
				break;
							
			case LIST:  
				if (VALUE_BASE(cframe) >= (P)caplevel) { 
					VALUE_BASE(cframe) -= offset; LIST_CEIL(cframe) -= offset; 
				}
				for (frame = (B *)VALUE_BASE(cframe);
						 frame < (B *)LIST_CEIL(cframe); 
						 frame += FRAMEBYTES) {
					if (COMPOSITE(frame)) {  
						if ((VALUE_BASE(frame) >= (P)caplevel) &&
								(VALUE_BASE(frame) < (P) CEILvm)) { 
							shift_subframe(frame, offset);
						}
						else if ((VALUE_BASE(frame) >= (P)savefloor) 
										 && (VALUE_BASE(frame) < (P) caplevel)) { 
							TAG(frame) = NULLOBJ; ATTR(frame) = 0; 
						}
					}
				}
				cframe = (B *)LIST_CEIL(cframe); 
				break;
			case DICT:  
				if (VALUE_BASE(cframe) >= (P)caplevel) { 
					VALUE_BASE(cframe) -= offset;
					d_reloc((B *)VALUE_BASE(cframe),VALUE_BASE(cframe)+offset,
									VALUE_BASE(cframe));
				}
				dict = (B *)VALUE_BASE(cframe);
				if ((tdict = makedict((DICT_TABHASH(dict) - DICT_ENTRIES(dict))
															/ ENTRYBYTES)) == (B *)(-1L)) 
					return VM_OVF;
				
				for (entry = (B *)DICT_ENTRIES(dict);
						 entry < (B *)DICT_FREE(dict); 
						 entry += ENTRYBYTES) {
					frame = ASSOC_FRAME(entry);
					if (COMPOSITE(frame) && (VALUE_BASE(frame) < (P)CEILvm)) { 
						if (VALUE_BASE(frame) >= (P)caplevel) { 
							shift_subframe(frame, offset);
						}
						else
							if (VALUE_BASE(frame) >= (P)savefloor) continue;
					}
					insert(ASSOC_NAME(entry),tdict,frame);
				} 
				d_rreloc(tdict,(P)tdict,(P)dict);
				moveD((D *)tdict, (D *)dict, DICT_NB(cframe)/sizeof(D));
				FREEvm = tdict - FRAMEBYTES;
				cframe += DICT_NB(cframe) + FRAMEBYTES; 
				break;
			case BOX:  
				if (VALUE_BASE(cframe) >= (P)caplevel)
					VALUE_BASE(cframe) -= offset;
				box = (B *)VALUE_BASE(cframe);
				if (SBOX_CAP(box)) { 
					if (SBOX_CAP(box) >= caplevel) SBOX_CAP(box) -= offset;
					else if (SBOX_CAP(box) > savefloor)
						SBOX_CAP(box) = savefloor;
				}
				cframe += BOX_NB(cframe) + FRAMEBYTES; 
				break;
			default:   return CORR_OBJ;
		}
	}

	if (capped) { 
		cframe = FREEexecs - FRAMEBYTES;
		while (cframe >= FLOORexecs) { 
			if (COMPOSITE(cframe))
				if ((VALUE_BASE(cframe) >= (P)caplevel) &&
						(VALUE_BASE(cframe) < (P) CEILvm)) { 
						shift_subframe(cframe, offset);
				}
			cframe -= FRAMEBYTES;
		}
		cframe = FREEdicts - FRAMEBYTES;
		while (cframe >= FLOORdicts)  { 
			if (COMPOSITE(cframe))
				if ((VALUE_BASE(cframe) >= (P)caplevel) 
						&& (VALUE_BASE(cframe) < (P) CEILvm)) {
						shift_subframe(cframe, offset);
				}
			cframe -= FRAMEBYTES;
		}
		cframe = FREEopds - FRAMEBYTES;
		while (cframe >= FLOORopds) { 
			if (COMPOSITE(cframe))
				if ((VALUE_BASE(cframe) >= (P)caplevel) 
						&& (VALUE_BASE(cframe) < (P) CEILvm)) {
						shift_subframe(cframe, offset);
				}
			cframe -= FRAMEBYTES;
		} 
	}

	return OK;
}

P x_op_restore_it(void) 
{
		B *next, *top, *box;
		P nb;
		
		if (FLOORexecs > x_2) return EXECS_UNF;
		if (TAG(x_1) != (ARRAY | BYTETYPE)) return EXECS_COR;
		if (TAG(x_2) != (ARRAY | BYTETYPE)) return EXECS_COR;
		FREEexecs = x2;

		next = VALUE_PTR(x_3) + FRAMEBYTES;
		top = VALUE_PTR(x_2);
		while (next < top) {
				switch (CLASS(next)) {
						case ARRAY:
								nb = DALIGN(ARRAY_SIZE(next) * VALUEBYTES(TYPE(next)));
								next += nb + FRAMEBYTES;
								break;
						case LIST:
								next = LIST_CEIL_PTR(next);
								break;
						case DICT:
								next += DICT_NB(next) + FRAMEBYTES;
								break;
						case BOX:
								box = VALUE_PTR(next);
								if (SBOX_FLAGS(box) & SBOX_FLAGS_CLEANUP) {
										if (CEILexecs < x2) return EXECS_OVF;
										if (CEILopds < o2) return OPDS_OVF;
										VALUE_PTR(x_3) = next - FRAMEBYTES;
										
										moveframe(next, o1);
										FREEopds = o2;
										
										TAG(x1) = OP;
										ATTR(x1) = ACTIVE;
										OP_NAME(x1) = (P) "op_restore";
										OP_CODE(x1) = (P) op_restore;
										FREEexecs = x2;
										
										return OK;
								}
								next += BOX_NB(next) + FRAMEBYTES;
								break;
						default:
								return CORR_OBJ;
				};
		};
		
		OP_NAME(x_1) = (P) "x_op_restore";
		OP_CODE(x_1) = (P) x_op_restore;
		moveframe(x_1, x_3);
		FREEexecs = x_2;
		
		return OK;
}


P op_restore(void)
{
		B *savebox, *caplevel;
		if (o_1 < FLOORopds) return OPDS_UNF;
		if (CLASS(o_1) != BOX) return OPD_CLA;
		savebox = VALUE_PTR(o_1);
		if (SBOX_FLAGS(savebox) & SBOX_FLAGS_CLEANUP) {
				if (CEILexecs < x2) return EXECS_OVF;
				SBOX_FLAGS(savebox) &= ~SBOX_FLAGS_CLEANUP;
				TAG(x1) = OP;
				ATTR(x1) = ACTIVE;
				OP_NAME(x1) = OPDEF_NAME(SBOX_DATA(savebox));
				OP_CODE(x1) = OPDEF_CODE(SBOX_DATA(savebox));
				FREEexecs = x2;
				moveframe(VALUE_PTR(o_1) + BOX_NB(o_1), o_1);
				return OK;
		}
		
		if (CEILexecs < x4) return EXECS_OVF;
		TAG(x1) = ARRAY | BYTETYPE;
		ATTR(x1) = 0;
		ARRAY_SIZE(x1) = 0;
		VALUE_PTR(x1) = VALUE_PTR(o_1) + SBOXBYTES - FRAMEBYTES;
		TAG(x2) = ARRAY | BYTETYPE;
		ATTR(x2) = 0;
		ARRAY_SIZE(x2) = 0;
		if ((caplevel = SBOX_CAP(savebox))) VALUE_PTR(x2) = caplevel;
		else VALUE_PTR(x2) = FREEvm;
		
		TAG(x3) = OP;
		ATTR(x3) = ACTIVE;
		OP_NAME(x3) = (P) "x_op_restore_it";
		OP_CODE(x3) = (P) x_op_restore_it;
		FREEexecs = x4;
		return OK;
}

//------------------- setcleanup ------------
//
// /name^op savebox | --
// sets the savebox cleanup op to op, or the op
//   pointed to by /name
//
P op_setcleanup(void) 
{
		B* box;
		if (o_2 < FLOORopds) return OPDS_UNF;
		if (CLASS(o_1) != BOX) return OPD_CLA;
		box = VALUE_PTR(o_1);
		if (SBOX_FLAGS(box) & SBOX_FLAGS_CLEANUP) return SBOX_SET;
		FREEopds = o_1;
		
		if (CLASS(o_1) == NAME) {
				int ret = op_find();
				if (ret != OK) return ret;
		}
		if (CLASS(o_1) != OP) return OPD_CLA;

		SBOX_FLAGS(box) |= SBOX_FLAGS_CLEANUP;
		OPDEF_NAME(SBOX_DATA(box)) = OP_NAME(o_1);
		OPDEF_CODE(SBOX_DATA(box)) = OP_CODE(o_1);

		FREEopds = o_1;
		return OK;
}

/*----------------------------------------------- vmstatus
   --- | max used
*/
P op_vmstatus(void)
{
  if (o2 >= CEILopds) return OPDS_OVF;

  TAG(o1) = TAG(o2) = NUM | LONGBIGTYPE;
  ATTR(o1) = ATTR(o2) = 0;
  LONGBIG_VAL(o1) = CEILvm - FLOORvm;
  LONGBIG_VAL(o2) = FREEvm - FLOORvm;
  FREEopds = o3;
  return OK;
}

/*----------------------------------------------- bind
   proc | proc

 - replaces executable names in proc that resolve to operators by their
   value
 - in addition, applies itself recursively to any not write-protected
   internal procedure nested in proc, and makes that procedure read-only
 - does not distinguish between system and dynamic operators
*/

// name bind conflicts with socket bind function, changed to dmbind
static P dmbind(B *pframe)
{
  P retc; 
  B *frame, *xframe, *dframe, *dict;

  if ((ATTR(pframe) & (READONLY | ACTIVE)) != ACTIVE) return OK;
  frame = (B *)VALUE_BASE(pframe);
  while (frame < (B *)LIST_CEIL(pframe)) { 
    switch(CLASS(frame)) {
      case PROC: 
        if ((retc = dmbind(frame)) != OK) return retc; 
        break;

      case NAME: 
        if ((ATTR(frame) & ACTIVE) == 0) break;
        dframe = FREEdicts - FRAMEBYTES; xframe = 0;
        while ((dframe >= FLOORdicts) && (xframe == 0L)) { 
          dict = (B *)VALUE_BASE(dframe);
          xframe = lookup(frame,dict);
          dframe -= FRAMEBYTES;
        }
        if ((P)xframe > 0 && CLASS(xframe) == OP)
          moveframes(xframe,frame,1L);
        break;
    }
    frame += FRAMEBYTES;
  }

  ATTR(pframe) |= READONLY;
  return OK;
}

P op_bind(void)
{
  if (o_1 < FLOORopds) return OPDS_UNF;
  if (CLASS(o_1) != PROC) return OK;
  return dmbind(o_1);
}

/*------------------------------------------- class
   object | /classname     (see below)
*/

P op_class(void)
{
  char *s;

  if (o_1 < FLOORopds) return OPDS_UNF;
  switch(CLASS(o_1)) {
    case NULLOBJ:  s = "nullclass"; break;
    case NUM:   s = "numclass"; break;
    case OP:    s = "opclass"; break;
    case NAME:  s = "nameclass"; break;
    case BOOL:  s = "boolclass"; break;
    case MARK:  s = "markclass"; break;
    case ARRAY: s = "arrayclass"; break;
    case LIST:  s = "listclass"; break;
    case DICT:  s = "dictclass"; break;
    case BOX:   s = "boxclass"; break;
    default: return CORR_OBJ;
  }
  makename((B*)s,o_1);
  return OK;
}

/*------------------------------------------- type
   object | /type (upper-case, one-letter code)
   NULLOBJ | /T (socket) or /N (none)
   DICT    | /O (oplibtype) or /X (opaque) or /N (none)
*/

P op_type(void)
{
  B c[2]; W key;

  if (o_1 < FLOORopds) return OPDS_UNF;

  switch (CLASS(o_1)) {
    case NULLOBJ:
			*c = (TYPE(o_1) == SOCKETTYPE) ? 'T' : 'N';
			break;

    case DICT:
      switch (TYPE(o_1)) {
        case OPLIBTYPE: *c = 'O'; break;
        case OPAQUETYPE: *c = 'Q'; break;
        default: *c = 'N'; break;
      };
      break;

    case NUM: case ARRAY:
      key = 0x4030 | TYPE(o_1);
      for (*c = 'A'; *c <= 'Z'; (*c)++) 
        if ((ascii[(*c) & 0x7F] & 0x403F) == key) 
          goto op79_1;
      return RNG_CHK;

    default:
      return OPD_CLA;
  };
 
 op79_1:
  c[1] = '\000'; makename(c,o_1);
  return OK;
}

/*------------------------------------------- readonly
     object | boolean       (reports 'read-only' attribute of frame)
*/

P op_readonly(void)
{
  if (o_1 < FLOORopds) return OPDS_UNF;
  BOOL_VAL(o_1) = ((ATTR(o_1) & READONLY) != 0);
  TAG(o_1) = BOOL; ATTR(o_1) = 0; 
  return OK;
}

/*------------------------------------------- active
     object | boolean       (reports 'active' attribute)
*/

P op_active(void)
{
  if (o_1 < FLOORopds) return OPDS_UNF;
  BOOL_VAL(o_1) = ((ATTR(o_1) & ACTIVE) != 0);
  TAG(o_1) = BOOL; ATTR(o_1) = 0;
  return OK;
}

/*---------------------------------------------- tilde
 * object | boolean (reports 'tilde' attribute)
 */

P op_tilde(void)
{
  if (o_1 < FLOORopds) return OPDS_UNF;
  BOOL_VAL(o_1) = ((ATTR(o_1) & TILDE) != 0);
  TAG(o_1) = BOOL; ATTR(o_1) = 0;
  return OK;
}

/*------------------------------------------- mkread
     object | readonly_object

 - marks the 'readonly' attribute in operand frame
*/

P op_mkread(void)
{
  if (o_1 < FLOORopds) return OPDS_UNF;
  ATTR(o_1) |= READONLY;
  return OK;
}

/*------------------------------------------- mkact
     object | active_object
*/

P op_mkact(void)
{
  if (o_1 < FLOORopds) return OPDS_UNF;
  ATTR(o_1) |= ACTIVE;
  return OK;
}

/*------------------------------------------ mkpass
     object | passive_object
*/

P op_mkpass(void)
{
  if (o_1 < FLOORopds) return OPDS_UNF;
  ATTR(o_1) &= (~ACTIVE);
  return OK;
}

/*------------------------------------------ ctype
     numeral /type | numeral       (type and value converted)
       array /type | array         (type converted, length adjusted)
*/

P op_ctype(void)
{
  B s[NAMEBYTES+1]; 
  W type;

  if (o_2 < FLOORopds) return OPDS_UNF;
  if (CLASS(o_1) != NAME) return OPD_ERR;

  pullname(o_1,s); 
  type = ascii[(*s) & 0x7F];
  if ((type & 0x4030) != 0x4030) return RNG_CHK; 
  type &= 0x0F;

  switch(CLASS(o_2)) {
    case NUM: 
      TAG(o_1) = NUM | type; 
      ATTR(o_1) = ATTR(o_2);
      MOVE(o_2,o_1); 
      moveframe(o_1,o_2);
      break;

     case ARRAY: 
       ARRAY_SIZE(o_2) = 
         (ARRAY_SIZE(o_2) * VALUEBYTES(TYPE(o_2))) / VALUEBYTES(type);
       TAG(o_2) = ARRAY | type; 
       ATTR(o_2) &= (~PARENT);
       break;

    default: 
      return OPD_CLA;
  }

  FREEopds = o_1;
  return OK;
}

/*------------------------------------------ parcel
     array1 length /type | remainder_of_array1 array2
  
  parcels array2 of given type and length from an initial subarray of
  array 1, which may be of different type (the returned arrays are
  word-aligned as necessary).
*/

P op_parcel(void)
{
  B s[NAMEBYTES+1]; W type;
  P length;
  P sadjust, badjust, nb;

  if (o_3 < FLOORopds) return OPDS_UNF;
  if ((CLASS(o_3) != ARRAY) || (CLASS(o_2) != NUM)) return OPD_CLA;
  if (CLASS(o_1) != NAME) return OPD_ERR;
  if (!PVALUE(o_2,&length)) return UNDF_VAL;
  if (length < 0) return RNG_CHK;

  pullname(o_1,s); 
  type = ascii[(*s) & 0x7F];
  if ((type & 0x4030) != 0x4030) return RNG_CHK; 
  type &= 0x0F;
  badjust = sadjust = 0;
  if (VALUEBYTES(type) & 1) { 
    if ((VALUEBYTES(TYPE(o_3)) & 1) == 0) sadjust = (length & 1); 
  }
  else  badjust = (VALUE_BASE(o_3) & 1);

  nb = length * VALUEBYTES(type) + badjust + sadjust;
  if ((ARRAY_SIZE(o_3) * VALUEBYTES(TYPE(o_3))) < nb) return RNG_CHK;
  TAG(o_2) = ARRAY | type; 
  ATTR(o_2) = ATTR(o_3) & (~PARENT);
  VALUE_BASE(o_2) = VALUE_BASE(o_3) + badjust;
  VALUE_BASE(o_3) += nb;
  ARRAY_SIZE(o_2) = length;
  ARRAY_SIZE(o_3) 
    = (ARRAY_SIZE(o_3) * VALUEBYTES(TYPE(o_3)) - nb) / VALUEBYTES(TYPE(o_3));

  FREEopds = o_1;
  return OK;
}

/*------------------------------------------ text
   string1 index signed_width/undef one_of_x | string1 new_index

   x = numeral / string / name / operator

 A non-string item x is converted to string form (numeral: used
 as ASCII code for one character; name: namestring is used; operator:
 operator name is used). The resulting string is copied into a field
 of given or corresponding (if undefined) width in string1 starting
 at the index. A negative width specifies left-adjustment within the 
 field. The unused part of the field receives spaces.  
*/

P op_text(void)
{
  B *src, *dest, code, sbuf[NAMEBYTES+1];
  UP index, val, width;
  P length, start;

  if (o_4 < FLOORopds) return OPDS_UNF;
  if (ATTR(o_4) & READONLY) return OPD_ATR;
  if ((TAG(o_4) != (ARRAY | BYTETYPE)) || (CLASS(o_3) != NUM))
    return OPD_ERR;
  if (!PVALUE(o_3,(P*)&index)) return UNDF_VAL;
  if (index < 0) return RNG_CHK;

  switch(CLASS(o_1)) {
    case NUM: 
      if (!PVALUE(o_1,(P*)&val)) return UNDF_VAL;
      if ((val < 0) || (val > 255)) return UNDF_VAL;
      code = (B)val; 
      src = &code; 
      length = 1; 
      break;

    case OP: 
      src = (B *)OP_NAME(o_1); 
      length = strlen((char*)src); 
      break;

    case NAME: 
      src = sbuf; 
      pullname(o_1,src);
      length = strlen((char*)src); 
      break;
      
    case ARRAY: 
      if (TYPE(o_1) != BYTETYPE) return OPD_TYP;
      src = (B *)VALUE_BASE(o_1); 
      length = ARRAY_SIZE(o_1);
      break;
      
     default: 
       return OPD_CLA;
  }

  if (CLASS(o_2) != NUM) return OPD_CLA;
  if (!PVALUE(o_2, (P*)&width)) {width = length; start = index;}
  else { 
    if (width < 0) { width = -width; start = index; }
    else { start = index + width - length;}
    if (length > width) return RNG_CHK;
  }
  if ((index + width) > ARRAY_SIZE(o_4)) return RNG_CHK;
  TAG(o_3) = NUM | LONGBIGTYPE;
  LONGBIG_VAL(o_3) = index + width;
  dest = (B *)VALUE_BASE(o_4) + index;
  while (index < start) { *(dest++) = ' '; index++; width--; }
  while (length) { length--; *(dest++) = *(src++); width--; }
  while (width) { *(dest++) = ' '; width--; }

  FREEopds = o_2;
  return OK;
}

/*------------------------------------------ number
     string index signed_width/undef numeral format_int/undef |
     string new_index

 - sign of format integer selects between fixed-point (<0) and 
   floating-point (>0) formats; value gives precision (i.e. fractional
   digits); an undefined in this place selects automatic formatting. The
   precision is ignored for integer numerals.
*/

P op_number(void)
{
  static B buf[30];
  P prec; 
  BOOLEAN fauto;

  if (o_2 < FLOORopds) return OPDS_UNF;
  if (CLASS(o_1) != NUM) return OPD_CLA;
  if (!PVALUE(o_1,&prec)) fauto = TRUE;
  else {
    if ((prec < -17) || (prec > 17)) return RNG_CHK; 
    fauto = FALSE;
  }
  if (CLASS(o_2) != NUM) return OPD_CLA;

  DECODE(o_2, fauto, prec, buf);
  TAG(o_2) = ARRAY | BYTETYPE; 
  ATTR(o_2) = READONLY;
  VALUE_BASE(o_2) = (P) buf; 
  ARRAY_SIZE(o_2) = strlen((char*)buf);
  FREEopds = o_1;
  return op_text();
}

/*------------------------------------------ token
     string | remainder_of_string object true
              string false
*/    

P op_token(void)
{
  P retc; 
  BOOLEAN bool;

  if (o_1 < FLOORopds) return OPDS_UNF;
  if (TAG(o_1) != (ARRAY | BYTETYPE)) return OPD_ERR;
  if ((retc = tokenize(o_1)) == OK) bool = TRUE;
  else if (retc == DONE) bool = FALSE;
  else return retc;
  if (o1 >= CEILopds) return OPDS_OVF;

  TAG(o1) = BOOL; 
  ATTR(o1) = 0;
  BOOL_VAL(o1) = bool;
  FREEopds = o2;
  return OK;
}

/*--------------------------------------------- search
   string seek | if found: post match pre true
               | else:     string false

  - searches string for substring seek; divides string on success
*/

P op_search(void)
{
  UB *string, *xstring, *seek;
  P nstring, nseek;

  if (o_2 < FLOORopds) return OPDS_UNF;
  if ((TAG(o_2) != (ARRAY | BYTETYPE)) 
      || (TAG(o_1) != (ARRAY | BYTETYPE))) 
    return OPD_ERR;
  if (ARRAY_SIZE(o_2) == 0) goto op90_f;
  if (ARRAY_SIZE(o_1) == 0) return RNG_CHK;
  string = (UB *)VALUE_BASE(o_2); 
  nstring = ARRAY_SIZE(o_2);

 op90_1:
  seek = (UB *)VALUE_BASE(o_1); nseek = ARRAY_SIZE(o_1);
  while (nstring >= nseek) { 
    if ((*string) == (*seek)) goto op90_2; 
    string++; nstring--; 
  }
  goto op90_f;

 op90_2:
  nseek--; 
  xstring = string + 1; 
  nstring--;
  while (nseek) { 
    if ((*(xstring++)) != (*(++seek))) { string++; goto op90_1; }
    nseek--;
  }
  if (o2 >= CEILopds) return OPDS_OVF;
  
  moveframe(o_2,o1);
  ARRAY_SIZE(o1) = (P)string - VALUE_BASE(o1);
  VALUE_BASE(o_1) = (P)string;
  VALUE_BASE(o_2) = (P)xstring;
  ARRAY_SIZE(o_2) = nstring - ARRAY_SIZE(o_1) + 1;
  ATTR(o_2) &= ~PARENT;
  ATTR(o1) = ATTR(o_1) = ATTR(o_2);
  TAG(o2) = BOOL; ATTR(o2) = 0;
  BOOL_VAL(o2) = TRUE;
  FREEopds = o3;
  return OK;

 op90_f:
  TAG(o_1) = BOOL; ATTR(o_1) = 0; BOOL_VAL(o_1) = FALSE;
  return OK;
}

/*--------------------------------------------- anchorsearch
   string seek | if found: post match true
               | else:     string false

  - tests string for initial substring seek; divides string on success
*/

P op_anchorsearch(void)
{
  UB *string, *seek;
  P nstring, nseek;

  if (o_2 < FLOORopds) return OPDS_UNF;
  if ((TAG(o_2) != (ARRAY | BYTETYPE)) 
      || (TAG(o_2) != (ARRAY | BYTETYPE))) 
    return OPD_ERR;

  if (ARRAY_SIZE(o_2) == 0) goto op91_f;
  if (ARRAY_SIZE(o_1) == 0) return RNG_CHK;
  string = (UB *)VALUE_BASE(o_2); 
  nstring = ARRAY_SIZE(o_2);
  seek = (UB *)VALUE_BASE(o_1); 
  nseek = ARRAY_SIZE(o_1);
  if (nstring < nseek) goto op91_f;

  while (nseek) { 
    if (*(string++) != *(seek++)) goto op91_f;
    nseek--;
  }
  if (o1 >= CEILopds) return OPDS_OVF;

  nseek = ARRAY_SIZE(o_1);
  moveframe(o_2,o_1); 
  ARRAY_SIZE(o_1) = nseek;
  VALUE_BASE(o_2) += nseek; 
  ARRAY_SIZE(o_2) -= nseek;
  ATTR(o_2) &= ~PARENT; 
  ATTR(o_1) = ATTR(o_2);
  TAG(o1) = BOOL; 
  ATTR(o1) = 0; 
  BOOL_VAL(o1) = TRUE;
  FREEopds = o2;
  return OK;

 op91_f:
  TAG(o_1) = BOOL; 
  ATTR(o_1) = 0; 
  BOOL_VAL(o_1) = FALSE;
  return OK;
}
