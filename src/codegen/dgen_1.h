
/*---------------- D machine 3.0 (Linux) dvt_1.c -------------------------

 This is an 'include' module for dvt.c and contains dvt-specific
 operators plus their support:

     - error
     - aborted
     - abort
     - toconsole
     - nextevent
     - send
     - getsocket
     - connect
     - disconnect

*/

/*-------------------- operator support ------------------------------*/

#include <string.h>

L toconsole(B *p, L atmost)
{
  L nb;
  if (atmost == -1) atmost = strlen(p);
  while (atmost > 0)
   { tc1:
  if (abortflag) { abortflag = FALSE; return(ABORT); }
     if ((nb = write(1, p, atmost)) < 0)
       { if ((errno == EINTR) || (errno == EAGAIN)) goto tc1;
            else return(-errno);
       }
     atmost -= nb; p += nb;
   }
  return(OK);
}

/*--------------------------- read a line from the console keyboard
    Tries to read a full line (terminated by '\n') from the console
    into the provided string buffer object. On success, the substring
    representing the line minus the '\n' character is inserted into
    the string buffer frame supplied to 'fromconsole'. Several abnormal
    returns can occur.
 */

L op_fromconsole(void)
{
  L nb, nsbuf;
  B *sbuf;
  BOOLEAN eof = FALSE;

  if (feof(stdin)) return QUIT;
  if (CEILexecs <= x2) return EXECS_OVF;
  
  moveframe(inputframe, x1);
  nsbuf = ARRAY_SIZE(inputframe);
  sbuf = VALUE_PTR(inputframe);

/* we read until we have a \n-terminated string */
  if (!fgets(sbuf, nsbuf, stdin)) {
      if (ferror(stdin)) return -errno;
      eof = feof(stdin);
  }
  nb = strlen(sbuf);
  /* we trim the buffer string object on the operand stack */
  ARRAY_SIZE(x1) = eof ? nb : nb - 1;
  FREEexecs = x2;
 return(OK);
}

/*-------------------- DVT-specific operators -------------------------*/

/*-------------------------------------- 'error'
   use: instance_string error_numeral | (->abort)

  - Clib error numerals are negative errno of Clib
  - decodes the error numeral and writes message
  - executes 'abort'
  - NOTE: you do not want to report errors of D nodes this way
    because 'error' aborts; use 'nodeerror' instead, which simply reports
*/

L op_error(void)
{
L e; B *m;
B *p, strb[256];
L nb, atmost; 

if (o_2 < FLOORopds) goto baderror;
if (TAG(o_2) != (ARRAY | BYTETYPE)) goto baderror;
if (CLASS(o_1) != NUM) goto baderror;
if (!VALUE(o_1,&e)) goto baderror;

 p = strb; atmost = 255;
 nb = snprintf(p,atmost,"\033[31m");
 p += nb; atmost -= nb;
 
if (e < 0) 
   { /*Clib error */
       nb = snprintf(p,atmost,(B*)strerror(-e));
   }
 else
   { /* one of our error codes: decode */
       m = geterror(e);
       nb = snprintf(p,atmost,m);
   }

 p += nb; atmost -= nb;
 nb = snprintf(p,atmost," in %s\033[0m\n", (B*)VALUE_BASE(o_2));
 nb += (L) (p - strb);
 toconsole(strb, nb);
FREEopds = o_2;
//return(op_abort());
return ABORT;

baderror: 
toconsole("Error with corrupted error info on operand stack!\n", -1L);
//return(op_abort());
return ABORT;
}

/*-------------------------------------- 'errormessage'
  use: instance_string error-numeral stringbuf | substring_of_stringbuf

  - composes an error message and returns it in a subarray of string buffer
*/

L op_errormessage(void)
{
L e, nb, tnb; B *m, *s;

if (o_3 < FLOORopds) return(OPDS_UNF);
if (TAG(o_3) != (ARRAY | BYTETYPE)) return(OPD_ERR);
if (CLASS(o_2) != NUM) return(OPD_CLA);
if (!VALUE(o_2,&e)) return(UNDF_VAL);
if (TAG(o_1) != (ARRAY | BYTETYPE)) return(OPD_ERR);
s = (B *)VALUE_BASE(o_1); tnb = ARRAY_SIZE(o_1);
if (e < 0) 
   { /*Clib error */
     nb = snprintf(s,tnb,(B *)strerror(-e));
     if (nb > tnb) nb = tnb;
   }
 else
 { /* one of our error codes: decode */
     m = geterror(e);
     nb = strlen(m);
     if (nb > tnb) nb = tnb;
     moveB(m,s,nb);
 }
s += nb; tnb -= nb;
nb = snprintf(s,tnb," in %s\n", (B *)VALUE_BASE(o_3));
 if (nb > tnb) nb = tnb;
ARRAY_SIZE(o_1) = (L)(s + nb) - VALUE_BASE(o_1);
moveframe(o_1,o_3);
FREEopds = o_2;
return(OK);
}
    


/*--------------------------------------- abort
   - drops execution stack to level above nearest ABORTMARK object (a BOOL)
   - sets the boolean object that carries ABORTMARK to TRUE
*/

L op_abort(void)
{
  return(ABORT);
}

/*---------------------------------------------------- toconsole
     string | ---

  - prints string operand on console
*/
L op_toconsole(void)
{
  if (o_1 < FLOORopds) return(OPDS_UNF);
  if (TAG(o_1) != (ARRAY | BYTETYPE)) return(OPD_ERR);
  FREEopds = o_1;
  return(toconsole((B *)VALUE_BASE(o1), ARRAY_SIZE(o1)));
}


