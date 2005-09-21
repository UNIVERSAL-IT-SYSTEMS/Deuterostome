/*=================== D machine Rev3.0: dnode_1.c =====================

  Include module for dnode.c: specific operators of dnode
*/

#include <ltdl.h>
#include <stdio.h>
#include <string.h>

BOOLEAN moreX = FALSE;

/*-------------------------- Dnode operators -------------------------*/

L op_getlock(void)
{
    if (CEILopds < o2) return (OPDS_OVF);
    TAG(o1) = BOOL;
    BOOL_VAL(o1) = locked;
    FREEopds = o2;
    return OK;
}

    
L op_setlock(void) 
{
    if (o_1 < FLOORopds) return (OPDS_UNF);
    if (TAG(o_1) != BOOL) return (OPD_TYP);
    locked = BOOL_VAL(o_1);
    FREEopds = o_1;
    return OK;
}

/*------------------------------------- 'halt' 
   - pushes 'x_halt' frame on the execution stack and directs phrases
     received from the console to the execution stack
   - 'x_halt' blocks execution of frames below it on the execution stack
     by pushing itself back on the stack until 'continue' is executed
   - frames pushed above 'x_halt' are executed normally
*/

static L x_op_halt(void)
{
  if (halt_flag) { FREEexecs = x2; return(DONE); }
return(OK);
}

L op_halt(void)
{
TAG(x1) = OP; ATTR(x1) = ACTIVE;
OP_NAME(x1) = (L)"x_halt"; OP_CODE(x1) = (L)x_op_halt;
FREEexecs = x2;
halt_flag = TRUE;
return(DONE);
}

/*------------------------------------- 'continue'
   - enables removal of x_halt from the execution stack
*/

L op_continue(void) { halt_flag = FALSE; return(OK); }

/*------------------------------------- 'setconsole'
   consolesocket | -

  - 'consolesocket' is a null object of type 'socket'
    or a plain null object (to select the default, 'stderr')
  - selects a socket to receive console output
  - this socket is used until another socket is selected
  - if the designated socket connection breaks, console output
    is directed to the default, 'stderr'
*/

L op_setconsole(void)
{
  if (o_1 < FLOORopds) return(OPDS_UNF);
  if (CLASS(o_1) != NULLOBJ) return(OPD_CLA);
  if (TYPE(o_1) == SOCKETTYPE)
    consolesocket = LONG_VAL(o_1);
  else 
    consolesocket = LINF;
  FREEopds = o_1;
  return(OK);
}

/*-------------------------------------- 'console'
    -- | consolesocket

  - returns a null object of type 'socket' that refers to
    the current console socket (or 'stderr' for default)
*/

L op_console(void)
{
  if (o1 > CEILopds) return (OPDS_OVF);
  TAG(o1) = NULLOBJ | SOCKETTYPE; 
  LONG_VAL(o1) = consolesocket;
  FREEopds = o2;
  return(OK);
}

L op_tostderr(void)
{
  B *p;
  L nb, atmost;

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

L op_toconsole(void)
{
  B *p, nf[FRAMEBYTES], sf[FRAMEBYTES], *oldFREEvm;
  L nb, atmost, retc;

  if (o_1 < FLOORopds) return(OPDS_UNF);
  if (TAG(o_1) != (ARRAY | BYTETYPE)) return(OPD_ERR);
  if (consolesocket != LINF)
    { TAG(nf) = NULLOBJ;
      if ((FREEvm + ARRAY_SIZE(o_1) + 25) > CEILvm) return(VM_OVF);
      p = FREEvm; moveB("save (", p, 6); p += 6;
      moveB((B *)VALUE_BASE(o_1),p,ARRAY_SIZE(o_1));
      p += ARRAY_SIZE(o_1);
      moveB(") toconsole restore",p,19); p += 19;
      TAG(sf) = ARRAY | BYTETYPE; ATTR(sf) = READONLY;
      VALUE_BASE(sf) = (L)FREEvm; ARRAY_SIZE(sf) = (L)(p - FREEvm);
      oldFREEvm = FREEvm; FREEvm = (B*)DALIGN(p);
      if ((retc = tosocket(consolesocket,sf,nf)) != OK)
        consolesocket = LINF;
      FREEvm = oldFREEvm;
    }
  if (consolesocket == LINF)
    {
      p = (B *)VALUE_BASE(o_1); atmost = ARRAY_SIZE(o_1);
      while (atmost > 0)
       { tc1:
         if ((nb = write(2, p, atmost)) < 0)
           { 
						 if ((errno == EINTR) || (errno == EAGAIN)) goto tc1;
						 else return(op_abort());  /* we drop dead */
           }
         atmost -= nb; p += nb;
       }
    }
  FREEopds = o_1;
  return(OK);
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

L op_error(void)
{
L e, nb, atmost; B *m, strb[256], *p;

p = strb; atmost = 255;
if (o_4 < FLOORopds) goto baderror;
if (TAG(o_4) != (ARRAY | BYTETYPE)) goto baderror;
if (TAG(o_3) != (NUM | LONGTYPE)) goto baderror;
if (TAG(o_2) != (ARRAY | BYTETYPE)) goto baderror;
if (CLASS(o_1) != NUM) goto baderror;
if (!VALUE(o_1,&e)) goto baderror;

 nb = snprintf(p,atmost,"\\033[31mOn %*s port %d: ",
        (L) ARRAY_SIZE(o_4), (B *)VALUE_BASE(o_4), LONG_VAL(o_3));
 p += nb; atmost -= nb;
 if (e < 0) 
   { /*Clib error */
     nb = snprintf(p,atmost,(B *)strerror(-e));
   }

 else
   { /* one of our error codes: decode */
       m = geterror(e);
       nb = snprintf(p,atmost,m);
   }
 p += nb; atmost -= nb;
 nb = snprintf(p,atmost," in %s\\033[0m\n", (B *)VALUE_BASE(o_2));
 nb += (L)(p - strb);
 TAG(o_4) = ARRAY | BYTETYPE; ATTR(o_4) = READONLY;
 VALUE_BASE(o_4) = (L)strb; ARRAY_SIZE(o_4) = nb;
 FREEopds = o_3;
 op_toconsole();
 return(op_halt());

baderror: 
nb = snprintf(p,atmost,
   "**Error with corrupted error info on operand stack!\n");
op_abort();
 nb += (L)(p - strb);
 TAG(o1) = ARRAY | BYTETYPE; ATTR(o1) = READONLY;
 VALUE_BASE(o1) = (L)strb; ARRAY_SIZE(o1) = nb;
 FREEopds = o2;
return(op_toconsole());
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

L op_errormessage(void)
{
L e, nb, tnb; B *m, *s;

if (o_5 < FLOORopds) goto baderror;
if (TAG(o_5) != (ARRAY | BYTETYPE)) goto baderror;
if (TAG(o_4) != (NUM | LONGTYPE)) goto baderror;
if (TAG(o_3) != (ARRAY | BYTETYPE)) goto baderror;
if (CLASS(o_2) != NUM) goto baderror;
if (!VALUE(o_2,&e)) goto baderror;
if (TAG(o_1) != (ARRAY | BYTETYPE)) goto baderror;

s = (B *)VALUE_BASE(o_1); tnb = ARRAY_SIZE(o_1);
nb = snprintf(s,tnb,"On %*s port %d: ", (L) ARRAY_SIZE(o_5),
	      (B *)VALUE_BASE(o_5), LONG_VAL(o_4));
 if (nb > tnb) nb = tnb;
s += nb; tnb -= nb;

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
moveframe(o_1,o_5);
FREEopds = o_4;
return(OK);

baderror:
printf("**Error with corrupted error info on operand stack!\n");
return(op_halt());
}

/*--------------------------------------- abort
   - clears the operand stack
   - clears the execution stack
   - drops the dictionary stack to 'userdict'

*/

L op_abort(void)
{
FREEopds = FLOORopds;
FREEexecs = FLOORexecs;
FREEdicts = FLOORdicts + FRAMEBYTES + FRAMEBYTES;
moveframe(msf,cmsf);
return(DONE);
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
  VALUE_BASE(msf) = (L)FREEvm + FRAMEBYTES; ARRAY_SIZE(msf) = 100000;
  moveframe(msf, FREEvm); FREEvm += FRAMEBYTES + DALIGN(100000);
  moveframe(msf,cmsf);
}

/*------------------------------------------------closealllibs
 * walks through the libs at over the vm ceil and closes
 * the associated shared library handle
 */
static void closealllibs(void)
{
    const char * e;
    void* handle;  
    B* lib = NULL;
    while((lib = nextlib(lib)) !=  NULL)
      if ((handle = (void*) LIB_HANDLE(lib)) != NULL) {
	if (lt_dlclose((lt_dlhandle)handle)) {
	  e = lt_dlerror();
	  fprintf(stderr, "dlclose: %s\n", e ? e : "--");
        }
      }

    if (lt_dlexit()) {
      e = lt_dlerror();
      fprintf(stderr, "dlexit: %s\n", e ? e : "--");
    }
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

static L VMRESIZE_ERR(L err, BOOLEAN bool) {
	TAG(o1) = BOOL; ATTR(o1) = 0; BOOL_VAL(o1) = bool;
	FREEopds = o2;
	return err;
}

L op_vmresize(void)
{
  L nb; B *userdict, *sysdict;
	L retc = OK;
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
		if (TAG(o1) != (ARRAY | LONGTYPE)) return VMRESIZE_ERR(OPD_ERR, FALSE);
		if (ARRAY_SIZE(o1) < 5) return VMRESIZE_ERR(RNG_CHK, FALSE);
      moveL((L *)VALUE_BASE(o1), setup, 5);
      if ((setup[0] < 1000) || (setup[1] < 100)
           || (setup[2] < 50) || (setup[3] < 1)
					|| (setup[4] < 200))
				return VMRESIZE_ERR(RNG_CHK, FALSE);
      if ((setup[0] > 100000) || (setup[1] > 10000)
           || (setup[2] > 5000) || (setup[3] > 1000)
           || (setup[4] > 5000))
				return VMRESIZE_ERR(RNG_CHK, FALSE);

      if (!tinymemory) {closealllibs(); maketinysetup();}

      nb = (setup[0] + setup[1] + setup[2]) * FRAMEBYTES
				+ setup[3] * 1000000;
			newDmemory = (B *) realloc(Dmemory, nb+FRAMEBYTES/2+1);
			if (! newDmemory) return VMRESIZE_ERR(VMR_ERR, FALSE);
			Dmemory = newDmemory;
      makeDmemory(Dmemory,setup);

      if ((sysdict = makeopdictbase((B*) sysop,syserrc,syserrm,SYSDICTSIZE)) 
					== (B*) -1L)
				error(EXIT_FAILURE, 0, "systemdict > vm");
      if ((userdict = makedict(setup[4])) == (B *)(-1L))
        error(EXIT_FAILURE, 0, "userdict > vm");
      tinymemory = FALSE;

      moveframe(sysdict-FRAMEBYTES,FREEdicts); 
      FREEdicts += FRAMEBYTES;
      moveframe(userdict-FRAMEBYTES,FREEdicts);
      FREEdicts += FRAMEBYTES;

      setupdirs();

      if (lt_dlinit()) {
				const char* e = lt_dlerror();
				fprintf(stderr, "dlinit: %s\n", e ? e: "--");
				error(EXIT_FAILURE, 0, "Can't dlinit");
      }
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
L op_killsockets(void) {return KILL_SOCKS;}

/***************************************************nextlib
 * dict or null | nextdict true
 *              | false
 * takes a dictionary (of a lib or sysdict) that lives
 * over the ceiling and walks up the tree searching for the next
 * one.  False if no further dicts, and null finds the first
 * one over ceiling.  Dicts are ordered in reverse of loading,
 * i.e., sysdict is last, null returns last lib loaded.
 * */
L op_nextlib(void)
{
    B* lastlib;
    
    if (o_1 < FLOORopds) return OPDS_UNF;
    
    switch (TAG(o_1))
    {
        case (DICT | OPLIBTYPE):
            lastlib = VALUE_PTR(o_1) - FRAMEBYTES;
            if (! LIB_TYPE(lastlib))
            {
                TAG(o_1) = BOOL;
                ATTR(o_1) = 0;
                BOOL_VAL(o_1) = FALSE;
                return OK;
            }
            break;
            
        case NULLOBJ: lastlib = NULL; break;
        default: return OPD_TYP;
    }

    if (CEILopds < o2) return OPDS_OVF;
    if (! (lastlib = nextlib(lastlib))) return CORR_OBJ;

    moveframe(lastlib, o_1);

    TAG(o1) = BOOL;
    ATTR(o1) = 0;
    BOOL_VAL(o1) = TRUE;
    FREEopds = o2;

    return OK;
}

    
    
/******************************************************loadlib
 * The library loading mechanism
 * (dir) (file) |
 * loads the shared library, via its ll_export variable
 * and creates an opdict containing all exported ops
 * placed above the vm ceiling
 * a library can only be loaded once between vmresize's
 * or an error will be signalled
 * */

void* libsym(void* handle, const char* symbol) 
{
    void* r;
    const char* e;
    
    if (! (r = (void*) lt_dlsym((lt_dlhandle) handle, symbol))) {
        e = lt_dlerror(); if (! e) e = "??";
        lt_dlclose((lt_dlhandle) handle);
        fprintf(stderr, "Symbol not found: %s: %s\n", symbol, e);
    }
    return r;
}

#define LIB_IMPORT(var, type, name)				\
  if (! (var = (type) lt_dlsym((lt_dlhandle)handle, #name))) {	\
    fprintf(stderr, "Symbol not found: %s in %s\n",		\
	    #name, FREEvm);					\
    return LIB_EXPORT;						\
  }

L op_loadlib(void)
{
    UL type;
    void *handle;
    B** ops;
    L* errc;
    B** errm;
    UL* libtype;
    B* oldCEILvm;
    B* oldFREEvm;
    B* sysdict;

    B* frame;
    B* dict;

    oldCEILvm = CEILvm;
    oldFREEvm = FREEvm;
    
    if (o_2 < FLOORopds) return OPDS_UNF;
    if (TAG(o_1) != (ARRAY | BYTETYPE)) return OPD_ERR;
    if (TAG(o_2) != (ARRAY | BYTETYPE)) return OPD_ERR;

    if (FREEvm + ARRAY_SIZE(o_1) + ARRAY_SIZE(o_2) + 1 > CEILvm)
      return VM_OVF;
    
    strncpy(FREEvm, VALUE_PTR(o_2), ARRAY_SIZE(o_2));
    strncpy(FREEvm + ARRAY_SIZE(o_2), VALUE_PTR(o_1), ARRAY_SIZE(o_1));
    FREEvm[ARRAY_SIZE(o_2) + ARRAY_SIZE(o_1)] = '\0';
    
    if (! (handle = (void*) lt_dlopen(FREEvm)))
    {                                          
        const char* e;                         
        fprintf(stderr, "%s\n", (e = lt_dlerror()) ? e : "??");
        return LIB_LOAD;
    }

        // loop over super ceil region, looking for first dict for type
        // and looking for sysop to stop
        // check handles on all libs but sysdict
        // assumed that sysdict has already been placed
    type = 0;
    frame = NULL;
  ll_type:
    if (! (frame = nextlib(frame))) return CORR_OBJ;
    if (! type) type = LIB_TYPE(frame) + 1;
    if (LIB_TYPE(frame))
    {
        if ((L) handle == LIB_HANDLE(frame)) return LIB_LOADED;
        goto ll_type;
    }
    
    LIB_IMPORT(ops, B**, ll_export);
    LIB_IMPORT(errc, L*, ll_errc);
    LIB_IMPORT(errm, B**, ll_errm);
    LIB_IMPORT(libtype, UL*, ll_type);

    *libtype = type << 16;
    if ((dict = makeopdict((B*) ops, errc, errm)) == (B*) -1L)
    {
        lt_dlclose((lt_dlhandle)handle);
        FREEvm = oldFREEvm;
        CEILvm = oldCEILvm;
        return VM_OVF;
    }

    LIB_TYPE(dict - FRAMEBYTES) = type;
    LIB_HANDLE(dict - FRAMEBYTES) = (L) handle;
    FREEopds = o_2;

    sysdict = VALUE_PTR(FLOORdicts);
    if (! mergedict(dict, sysdict)) return LIB_MERGE;
    return OK;
}

/*------------------------------------------- Xconnect
     (hostname:screen#) | --

  - establishes an X windows connection to the specified screen of
    the specified host (hostname is the plain host name)
*/

#if ! X_DISPLAY_MISSING
//int xioerrorhandler(Display* display
int xerrorhandler(Display* display, XErrorEvent* event) {
	char msg[80];
	XGetErrorText(display, event->error_code, msg, sizeof(msg));
	fprintf(stderr, "Xerror: %s\n", msg);
	if (x2 <= CEILexecs) {
		makename("Xdisconnect", x1); ATTR(x1) = ACTIVE;
		FREEexecs = x1;
	}
	return 0;
}
#endif
	

L op_Xconnect(void)
{
#if X_DISPLAY_MISSING
	return NO_XWINDOWS;
#else
  if (o_1 < FLOORopds) return(OPDS_UNF);
  if (TAG(o_1) != (ARRAY | BYTETYPE)) return(OPD_ERR);
  if (ARRAY_SIZE(o_1) > 79) return(RNG_CHK);
  moveB((B *)VALUE_BASE(o_1), displayname, ARRAY_SIZE(o_1));
  displayname[ARRAY_SIZE(o_1)] = '\000';

  dvtdisplay = XOpenDisplay(displayname);
  if (dvtdisplay != NULL)
  {
      setenv("DISPLAY", displayname, 1);
      dvtscreen = XDefaultScreenOfDisplay(dvtdisplay);
      dvtrootwindow = XDefaultRootWindow(dvtdisplay);
      if (XGetWindowAttributes(dvtdisplay,dvtrootwindow,&rootwindowattr) == 0)
          error(EXIT_FAILURE,0,"Xwindows: no root window attributes");
      ndvtwindows = 0; ncachedfonts = 0;
      dvtgc = XCreateGC(dvtdisplay,dvtrootwindow,0,NULL);
      xsocket = ConnectionNumber(dvtdisplay);
      FD_SET(xsocket, &sock_fds);
      FREEopds = o_1; 
			XSetErrorHandler(xerrorhandler);
			//XSetIOErrorHandler(xerrorhandler);
			return(OK);
  }
  *displayname = '\0';
  return(X_BADHOST);
#endif
}

/*------------------------------------------- Xdisconnect
     -- | --

 - breaks an existing connection to an X windows server (thus
   removing all windows existing in that connection)
*/

L op_Xdisconnect(void)
{
#if X_DISPLAY_MISSING
	return NO_XWINDOWS;
#else
  if (dvtdisplay != NULL)  {
      XCloseDisplay(dvtdisplay);
      FD_CLR(xsocket, &sock_fds);
      xsocket = -1;
      if (defaultdisplay) setenv("DISPLAY", defaultdisplay, 1);
      else unsetenv("DISPLAY");
      dvtdisplay = NULL;
  }
  *displayname = '\0';
	moreX = FALSE;
  return(OK);
#endif
}

/*------------------------------------------- getmyport
    | serverport/l

returns the host's port (such as for error)
*/

L op_getmyport(void)
{
    if (CEILopds < o2) return OPDS_OVF;
    TAG(o1) = (NUM | LONGTYPE);
    ATTR(o1) = 0;
    LONG_VAL(o1) = serverport - IPPORT_USERRESERVED;
    FREEopds = o2;

    return OK;
}

/*----------------------------------------------- Xwindows_

   -- | bool

  - reports whether Xwindows has been built for initial connection
	  (if not, X windows operators
    will return the error NO_XWINDOWS)
*/

L op_Xwindows_()
{
  if (o1 >= CEILopds) return(OPDS_OVF);
  TAG(o1) = BOOL; ATTR(o1) = 0;
#if X_DISPLAY_MISSING
	BOOL_VAL(o1) = FALSE;
#else
  BOOL_VAL(o1) = TRUE;
#endif
  FREEopds = o2;
  return(OK);
}
