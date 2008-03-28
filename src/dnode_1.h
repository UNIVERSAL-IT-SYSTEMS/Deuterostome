/*=================== D machine Rev3.0: dnode_1.c =====================

  Include module for dnode.c: specific operators of dnode
*/

#include <stdio.h>
#include <string.h>

#include "pluginlib.h"

BOOLEAN moreX = FALSE;

/*-------------------------- Dnode operators -------------------------*/

P x_op_lock(void) {
	if (o_1 < FLOORopds) return OPDS_UNF;
	if (x_1 < FLOORexecs) return EXECS_UNF;
	if (TAG(o_1) != BOOL) return OPD_CLA;
	if (TAG(x_1) != BOOL) return EXECS_COR;
	
	locked = BOOL_VAL(x_1);
	if (! BOOL_VAL(o_1)) FREEexecs = x_1;
	else {
		TAG(x_1) = OP; ATTR(x_1) = ACTIVE;
		OP_NAME(x_1) = (P) "stop"; OP_CODE(x_1) = (P) op_stop;
	}
	FREEopds = o_1;
	return OK;
}

/* ~active | -- */
P op_lock(void) {
	if (o_1 < FLOORopds) return OPDS_UNF;
	if (CEILexecs < x5) return EXECS_OVF;
	if (! (ATTR(o_1) & ACTIVE)) return OPD_ATR;

	TAG(x1) = BOOL; ATTR(x1) = 0;
	BOOL_VAL(x1) = locked;

	TAG(x2) = OP; ATTR(x2) = ACTIVE;
	OP_NAME(x2) = (P) "x_lock"; OP_CODE(x2) = (P) x_op_lock;

	TAG(x3) = BOOL; ATTR(x3) = (STOPMARK | ACTIVE);
	BOOL_VAL(x3) = FALSE;

	moveframe(o_1, x4);
	FREEexecs = x5;
	FREEopds = o_1;
	locked = TRUE;

	return OK;
}

P x_op_serialize(void) {
	if (o_1 < FLOORopds) return OPDS_UNF;
	if (x_1 < FLOORexecs) return EXECS_UNF;
	if (TAG(o_1) != BOOL) return OPD_CLA;
	if (TAG(x_1) != BOOL) return EXECS_COR;
	
	serialized = BOOL_VAL(x_1);
	if (! BOOL_VAL(o_1)) FREEexecs = x_1;
	else {
		TAG(x_1) = OP; ATTR(x_1) = ACTIVE;
		OP_NAME(x_1) = (P) "stop"; OP_CODE(x_1) = (P) op_stop;
	}
	FREEopds = o_1;
	return OK;
}

/* ~active | -- */
P op_serialize(void) {
	if (o_1 < FLOORopds) return OPDS_UNF;
	if (CEILexecs < x5) return EXECS_OVF;
	if (! (ATTR(o_1) & ACTIVE)) return OPD_ATR;

	TAG(x1) = BOOL; ATTR(x1) = 0;
	BOOL_VAL(x1) = serialized;

	TAG(x2) = OP; ATTR(x2) = ACTIVE;
	OP_NAME(x2) = (P) "x_serialize"; OP_CODE(x2) = (P) x_op_serialize;

	TAG(x3) = BOOL; ATTR(x3) = (STOPMARK | ACTIVE);
	BOOL_VAL(x3) = FALSE;

	moveframe(o_1, x4);
	FREEexecs = x5;
	FREEopds = o_1;
	serialized = TRUE;

	return OK;
}

/*------------------------------------- 'halt' 
   - pushes 'x_halt' frame on the execution stack and directs phrases
     received from the console to the execution stack
   - 'x_halt' blocks execution of frames below it on the execution stack
     by pushing itself back on the stack until 'continue' is executed
   - frames pushed above 'x_halt' are executed normally
*/

static P x_op_halt(void)
{
	if (x_1 < FLOORexecs) return EXECS_UNF;
	if (TAG(x_1) != BOOL) return EXECS_COR;
  if (halt_flag) { FREEexecs = x2; return DONE; }
	locked = BOOL_VAL(x_1);
	FREEexecs = x_1;
	return OK;
}

P op_halt(void)
{
	if (x2 >= CEILexecs) return EXECS_OVF;

	TAG(x1) = BOOL; ATTR(x1) = 0;
	BOOL_VAL(x1) = locked;
	TAG(x2) = OP; ATTR(x2) = ACTIVE;
	OP_NAME(x2) = (P)"x_halt"; 
  OP_CODE(x2) = (P)x_op_halt;
	FREEexecs = x3;
	halt_flag = TRUE;
	return DONE;
}

/*------------------------------------- 'continue'
   - enables removal of x_halt from the execution stack
*/

P op_continue(void) { halt_flag = FALSE; return OK; }

/*------------------------------------- 'setconsole'
   consolesocket | -

  - 'consolesocket' is a null object of type 'socket'
    or a plain null object (to select the default, 'stderr')
  - selects a socket to receive console output
  - this socket is used until another socket is selected
  - if the designated socket connection breaks, console output
    is directed to the default, 'stderr'
*/

P op_setconsole(void)
{
  if (o_1 < FLOORopds) return OPDS_UNF;
  if (CLASS(o_1) != NULLOBJ) return OPD_CLA;
  if (TYPE(o_1) == SOCKETTYPE) consolesocket = (P) LONGBIG_VAL(o_1);
  else  consolesocket = PINF;
  FREEopds = o_1;
  return OK;
}

/*-------------------------------------- 'console'
    -- | consolesocket or null (if stderr)

  - returns a null object of type 'socket' that refers to
    the current console socket (or 'stderr' for default)
*/

P op_console(void) {
  if (o1 > CEILopds) return (OPDS_OVF);
  TAG(o1) = NULLOBJ;
  if (consolesocket != PINF) {
    TAG(o1) |= SOCKETTYPE;
    LONGBIG_VAL(o1) = consolesocket;
  }
  FREEopds = o2;
  return OK;
}

P op_tostderr(void)
{
  B *p;
  P nb, atmost;

  if (o_1 < FLOORopds) return OPDS_UNF;
  if (TAG(o_1) != (ARRAY | BYTETYPE)) return OPD_ERR;

  p = VALUE_PTR(o_1);
  atmost = ARRAY_SIZE(o_1);
  while (atmost > 0) {
    while ((nb = write(2, p, atmost)) < 0
           && ((errno == EINTR) || (errno == EAGAIN)));
    if (nb < 0) return op_abort();
    atmost -= nb;
    p += nb;
  }

  FREEopds = o_1;
  return OK;
}
  
/*-------------------------------------- 'toconsole'
   (message) | -

  - sends a command to print the message string to the current
    console node
  - if there is no console socket assigned or if the console
    socket fails, we default to 'stderr' and simply print the
    message
  - if 'stderr' fails, we give up and abort
*/

P op_toconsole(void)
{
  B *p, nf[FRAMEBYTES], sf[FRAMEBYTES], *oldFREEvm;
  P nb, atmost, retc;
  B *p_;

  if (o_1 < FLOORopds) return OPDS_UNF;
  if (TAG(o_1) != (ARRAY | BYTETYPE)) return OPD_ERR;
  if (consolesocket != PINF) { 
    B* max_ = VALUE_PTR(o_1) + ARRAY_SIZE(o_1);
    TAG(nf) = NULLOBJ;
    if ((FREEvm + ARRAY_SIZE(o_1) + 25) > CEILvm) return VM_OVF;
    p_ = VALUE_PTR(o_1);
    do {
      B* max = FREEvm + 8192 - 20;
      if (max > CEILvm) max = CEILvm;

      p = FREEvm; 
      moveB((B*)"save (", p, 6); p += 6;    
      for (; p_ <  max_ && p < max; p_++) {
        switch (*p_) {
          case ')': case '\\': 
            p += dm_snprintf((char*)p, max - p, "\\%c", (unsigned int) *p_);
            break;
            
          case 0: case 1: case 2: case 3: case 4: case 5: 
          case 6: case 7: case 8: case 9: case 10: case 11: 
          case 12: case 13: case 14: case 15: case 16: case 17: 
          case 18: case 19: case 20: case 21: case 22: case 23: 
          case 24: case 25: case 26: case 27: case 28: case 29: 
          case 30: case 31: case 127:
            p += dm_snprintf((char*)p, max - p, "\\%.3o", (unsigned int) *p_);
            break;

          default:
            *(p++) = *p_;
            break;
        }
        if (p == CEILvm) return VM_OVF;
      }
      if (p + 19 > CEILvm) return VM_OVF;
      moveB((B*)") toconsole restore",p,19); 
      p += 19;
      TAG(sf) = ARRAY | BYTETYPE; ATTR(sf) = READONLY;
      VALUE_BASE(sf) = (P)FREEvm; ARRAY_SIZE(sf) = (P)(p - FREEvm);
      oldFREEvm = FREEvm; FREEvm = (B*)DALIGN(p);
      if ((retc = tosocket(consolesocket,sf,nf)) != OK) {
        consolesocket = PINF;
        FREEvm = oldFREEvm;
        return retc;
      }
      FREEvm = oldFREEvm;
    } while (p_ < max_);
  }
  else {
    p = (B *)VALUE_BASE(o_1); 
    atmost = ARRAY_SIZE(o_1);
    while (atmost > 0) { 
    tc1:
      if ((nb = write(2, p, atmost)) < 0) { 
        if ((errno == EINTR) || (errno == EAGAIN)) goto tc1;
        else return op_abort();  /* we drop dead */
      }
      atmost -= nb; p += nb;
    }
  }
  FREEopds = o_1;
  return OK;
}

/*-------------------------------------- 'error'
  - expects on operand stack:
     error code    (top)
     errsource string
     port#
     hostname string
  - prints message on current console or startup
    terminal (default)
  - aborts on corrupted error info
  - halts after uncorrupted error
*/

P op_error(void)
{
  LBIG e;
  P nb, atmost; 
  B *m, strb[256], *p;
  P ret;

  p = strb; 
  atmost = 255;
  if (o_4 < FLOORopds) goto baderror;
  if (TAG(o_4) != (ARRAY | BYTETYPE)) goto baderror;
  if (TAG(o_3) != (NUM | LONGBIGTYPE)) goto baderror;
  if (TAG(o_2) != (ARRAY | BYTETYPE)) goto baderror;
  if (CLASS(o_1) != NUM) goto baderror;
  if (!VALUE(o_1,&e)) goto baderror;

  nb = dm_snprintf((char*)p,atmost,"\033[31mOn %*s port %lld: ",
                   (int) ARRAY_SIZE(o_4), (char*)VALUE_BASE(o_4), 
                   (long long) LONGBIG_VAL(o_3));

  p += nb; atmost -= nb;
  if ((P)e < 0) /*Clib error */
    nb = dm_snprintf((char*)p,atmost,(char*)strerror((P)-e));
  else { /* one of our error codes: decode */
    m = geterror((P)e);
    nb = dm_snprintf((char*)p,atmost,(char*)m);
  }
  p += nb; atmost -= nb;
  nb = dm_snprintf((char*)p,atmost," in %s\033[0m\n", (char*)VALUE_BASE(o_2));
  nb += (P)(p - strb);
  TAG(o_4) = ARRAY | BYTETYPE; 
  ATTR(o_4) = READONLY;
  VALUE_BASE(o_4) = (P)strb; 
  ARRAY_SIZE(o_4) = nb;
  FREEopds = o_3;
  op_toconsole();
  if ((ret = op_halt()) == DONE) return DONE;

  nb = dm_snprintf((char*)p, atmost, "** Error in internal halt!\n");
  goto baderror2;

 baderror: 
  nb = dm_snprintf((char*)p,atmost,
                   "**Error with corrupted error info on operand stack!\n");
 baderror2:
  op_abort();
  nb += (P)(p - strb);
  TAG(o1) = ARRAY | BYTETYPE; 
  ATTR(o1) = READONLY;
  VALUE_BASE(o1) = (P)strb; 
  ARRAY_SIZE(o1) = nb;
  FREEopds = o2;
  return op_toconsole();
}

/*-------------------------------------- 'errormessage'
  - expects on operand stack:
     string buffer (top)
     error code
     errsource string
     port#
     hostname string
  - composes an error message and returns it in a subarray of string buffer
*/

P op_errormessage(void)
{
  LBIG e;
  P nb, tnb; 
  B *m, *s;

  if (o_5 < FLOORopds) goto baderror;
  if (TAG(o_5) != (ARRAY | BYTETYPE)) goto baderror;
  if (TAG(o_4) != (NUM | LONGBIGTYPE)) goto baderror;
  if (TAG(o_3) != (ARRAY | BYTETYPE)) goto baderror;
  if (CLASS(o_2) != NUM) goto baderror;
  if (!VALUE(o_2,&e)) goto baderror;
  if (TAG(o_1) != (ARRAY | BYTETYPE)) goto baderror;

  s = (B *)VALUE_BASE(o_1); 
  tnb = ARRAY_SIZE(o_1);
  nb = dm_snprintf((char*)s,
		   tnb,"On %*s port %lld: ", (int) ARRAY_SIZE(o_5),
                   (char*)VALUE_BASE(o_5), 
                   (long long) LONGBIG_VAL(o_4));
  s += nb; tnb -= nb;

  if ((P)e < 0) /*Clib error */
    nb = dm_snprintf((char*)s,tnb,(char*)strerror(-e));
  else { /* one of our error codes: decode */
    m = geterror((P)e);
    nb = strlen((char*)m);
    if (nb > tnb) nb = tnb;
    moveB(m,s,nb);
  }
  s += nb; tnb -= nb;
  nb = dm_snprintf((char*)s,tnb," in %s\n", (char*)VALUE_BASE(o_3));
  ARRAY_SIZE(o_1) = (P)(s + nb) - VALUE_BASE(o_1);
  moveframe(o_1,o_5);
  FREEopds = o_4;
  return OK;

 baderror:
  printf("**Error with corrupted error info on operand stack!\n");
  return op_halt();
}

/*--------------------------------------- abort
   - clears the operand stack
   - clears the execution stack
   - drops the dictionary stack to 'userdict'

*/

P op_abort(void)
{
  FREEopds = FLOORopds;
  FREEexecs = FLOORexecs;
  FREEdicts = FLOORdicts + FRAMEBYTES + FRAMEBYTES;
  moveframe(msf,cmsf);
  return DONE;
}

/*------------------------------------------------maketinysetup
  - creates a 'tiny' memory, just enough to bootstrap
    vmresize.  Sysdict is at the bottom of vm, not top
*/
  
static void maketinysetup(void)
{
  B *sysdict, *userdict;
  
  makeDmemory(tinyDmemory,tinysetup);
  if ((sysdict = makeopdict((B*) sysop,syserrc,syserrm)) == (B*) -1L)
    error(EXIT_FAILURE, 0, "Cannot make system dictionary");;
  if ((userdict = makedict(tinysetup[4])) == (B *)(-1L))
    error(EXIT_FAILURE, 0, "Cannot make user dictionary");
  tinymemory = TRUE;

  moveframe(sysdict-FRAMEBYTES,FREEdicts);
  FREEdicts += FRAMEBYTES;
  moveframe(userdict-FRAMEBYTES,FREEdicts); 
  FREEdicts += FRAMEBYTES;
  TAG(msf) = (ARRAY | BYTETYPE); ATTR(msf) = READONLY;
  if (FREEvm + 100000 + FRAMEBYTES > CEILvm)
    error(EXIT_FAILURE, 0, "VM chosen too small");
  VALUE_BASE(msf) = (P)FREEvm + FRAMEBYTES; ARRAY_SIZE(msf) = 100000;
  moveframe(msf, FREEvm); FREEvm += FRAMEBYTES + DALIGN(100000);
  moveframe(msf,cmsf);
}

/*-------------------------------------------- vmresize
    <L nopds ndicts nexecs nVM/MB userdictsize > | bool
                                            null | true
    
  - with NULL as operand, establishes the 'tiny' D workspace
  - with dimensions operand, establishes a new workspace for the
    given stack and VM dimensions (stack dimensions are in objects,
    VM dimension is in MB)
  - sets up startup dir & switches back to original working directory
  - puts sysdict at top
	- pushes true if memory allocation succeeded.
*/

static P VMRESIZE_ERR(P err, BOOLEAN bool) {
	TAG(o1) = BOOL; 
  ATTR(o1) = 0; 
  BOOL_VAL(o1) = bool;
	FREEopds = o2;
	return err;
}

P op_vmresize(void)
{
  P nb; 
  B *userdict, *sysdict;
  B* newDmemory;

  if (o_1 < FLOORopds) return VMRESIZE_ERR(OPDS_UNF, FALSE);
	FREEopds = o_1;
  if (CLASS(o1) == NULLOBJ) { 
    if (tinymemory) {op_abort(); return VMRESIZE_ERR(VMR_STATE, FALSE);};
    closealllibs();
    maketinysetup();
    free(Dmemory);
    Dmemory = NULL;
	} else { 
		if (TAG(o1) != (ARRAY | LONGBIGTYPE)) return VMRESIZE_ERR(OPD_ERR, FALSE);
		if (ARRAY_SIZE(o1) < 5) return VMRESIZE_ERR(RNG_CHK, FALSE);
    moveLBIG((LBIG *)VALUE_BASE(o1), setup, 5);
    if ((setup[0] < 1000) || (setup[1] < 100)
        || (setup[2] < 50) || (setup[3] < 1)
        || (setup[4] < 200))
      return VMRESIZE_ERR(RNG_CHK, FALSE);
    if ((setup[0] > MAX_NUM_OPDS) || (setup[1] > MAX_NUM_DICTS)
        || (setup[2] > MAX_NUM_EXECS) || (setup[3] > MAX_MEM_SIZE)
        || (setup[4] > MAX_USER_DICT_SIZE))
      return VMRESIZE_ERR(RNG_CHK, FALSE);
    
    if (!tinymemory) {closealllibs(); maketinysetup();}
    
    nb = (setup[0] + setup[1] + setup[2]) * FRAMEBYTES
      + setup[3] * 1000000;
    newDmemory = (B *) realloc(Dmemory, nb+FRAMEBYTES/2+1);
    if (! newDmemory) return VMRESIZE_ERR(VMR_ERR, FALSE);
    Dmemory = newDmemory;
    makeDmemory(Dmemory,setup);
    
    if ((sysdict = makeopdictbase((B*) sysop,syserrc,syserrm,SYS_DICT_SIZE))
        == (B*) -1L)
      error(EXIT_FAILURE, 0, "systemdict > vm");
    if ((userdict = makedict(setup[4])) == (B *)(-1L))
      error(EXIT_FAILURE, 0, "userdict > vm");
    tinymemory = FALSE;

    moveframe(sysdict-FRAMEBYTES,FREEdicts); 
    FREEdicts += FRAMEBYTES;
    moveframe(userdict-FRAMEBYTES,FREEdicts);
    FREEdicts += FRAMEBYTES;
    
	  initialize_plugins();
    setupdirs();
  }

  if (chdir(original_dir)) error(EXIT_FAILURE,errno,"chdir");

#if X_DISPLAY_MISSING
	return VMRESIZE_ERR(OK, TRUE);
#else
  return VMRESIZE_ERR(op_Xdisconnect(), TRUE);
#endif
}

/**********************************************vmreset
 * call right after vmresize, to reset sockets if
 * vmresize failed
 * --- | --- <<all non-server sockets closed>>
 */
P op_killsockets(void) {return KILL_SOCKS;}

/*------------------------------------------- Xconnect
     (hostname:screen#) | --

  - establishes an X windows connection to the specified screen of
    the specified host (hostname is the plain host name)
*/

P int_Xdisconnect(BOOLEAN nocheck) {
#if X_DISPLAY_MISSING
  return NO_XWINDOWS;
#else
  if (nocheck || dvtdisplay)  {
    if (dvtdisplay) HXCloseDisplay(dvtdisplay);
    FD_CLR(xsocket, &sock_fds);
    xsocket = -1;
    if (defaultdisplay) setenv("DISPLAY", defaultdisplay, 1);
    else unsetenv("DISPLAY");
    dvtdisplay = NULL;
  }
  *displayname = '\0';
  moreX = FALSE;
  return OK;
#endif
}


#if ! X_DISPLAY_MISSING
int xioerrorhandler(Display* display) {
  char msg[80];
  HXGetErrorDatabaseText(display, "dnode", 
			 "XRequest", "Connection Dead", msg, sizeof(msg));
  fprintf(stderr, "Fatal Xerror: %s\n", msg);
  HXGetErrorDatabaseText(display, "dnode", 
			 "XlibMessage", "Connection Dead", msg, sizeof(msg));
  fprintf(stderr, "Internal Xerror: %s\n", msg);

  dvtdisplay = NULL;
  int_Xdisconnect(TRUE);
  longjmp(xhack_buf, 1);
}

int xerrorhandler(Display* display, XErrorEvent* event) {
  char msg[80];
  HXGetErrorText(display, event->error_code, msg, sizeof(msg));
  fprintf(stderr, "Xerror: %s\n", msg);
  if (x2 <= CEILexecs) {
    makename((B*)"Xdisconnect", x1); ATTR(x1) = ACTIVE;
    FREEexecs = x1;
  }
  return 0;
}
#endif
	

P op_Xconnect(void)
{
#if X_DISPLAY_MISSING
	return NO_XWINDOWS;
#else
  if (o_1 < FLOORopds) return OPDS_UNF;
  if (TAG(o_1) != (ARRAY | BYTETYPE)) return OPD_ERR;
  if (ARRAY_SIZE(o_1) > 79) return RNG_CHK;
  if (ARRAY_SIZE(o_1) > 0) {
    moveB((B *)VALUE_BASE(o_1), displayname, ARRAY_SIZE(o_1));
    displayname[ARRAY_SIZE(o_1)] = '\000';
    dvtdisplay = XOpenDisplay((char*)displayname);
  }
  else if ((dvtdisplay = XOpenDisplay(NULL))) {
    strncpy((char*)displayname, DisplayString(dvtdisplay), 
	    sizeof(displayname)-1);
    displayname[sizeof(displayname)-1] = '\000';
  };

  if (! dvtdisplay) {
    *displayname = '\0';
    return X_BADHOST;
  };

  setenv("DISPLAY", (char*)displayname, 1);
  dvtscreen = HXDefaultScreenOfDisplay(dvtdisplay);
  dvtrootwindow = HXDefaultRootWindow(dvtdisplay);
  if (HXGetWindowAttributes(dvtdisplay,dvtrootwindow,&rootwindowattr) == 0)
    error(EXIT_FAILURE,0,"Xwindows: no root window attributes");
  ndvtwindows = 0; 
  ncachedfonts = 0;
  dvtgc = HXCreateGC(dvtdisplay,dvtrootwindow,0,NULL);
  xsocket = ConnectionNumber(dvtdisplay);
  FD_SET(xsocket, &sock_fds);
  FREEopds = o_1; 
  XSetErrorHandler(xerrorhandler);
  XSetIOErrorHandler(xioerrorhandler);
  return OK;
#endif
}

/*------------------------------------------- Xdisconnect
     -- | --

 - breaks an existing connection to an X windows server (thus
   removing all windows existing in that connection)
*/

P op_Xdisconnect(void)
{
  return int_Xdisconnect(FALSE);
}

/*------------------------------------------- getmyport
    | serverport/l

returns the host's port (such as for error)
*/

P op_getmyport(void)
{
  if (CEILopds < o2) return OPDS_OVF;
  TAG(o1) = (NUM | LONGBIGTYPE);
  ATTR(o1) = 0;
  LONGBIG_VAL(o1) = serverport - DM_IPPORT_USERRESERVED;
  FREEopds = o2;

  return OK;
}

/*----------------------------------------------- Xwindows_

   -- | bool

  - reports whether Xwindows has been built for initial connection
	  (if not, X windows operators
    will return the error NO_XWINDOWS)
*/

P op_Xwindows_()
{
  if (o1 >= CEILopds) return OPDS_OVF;
  TAG(o1) = BOOL; 
  ATTR(o1) = 0;
#if X_DISPLAY_MISSING
	BOOL_VAL(o1) = FALSE;
#else
  BOOL_VAL(o1) = TRUE;
#endif
  FREEopds = o2;
  return OK;
}
