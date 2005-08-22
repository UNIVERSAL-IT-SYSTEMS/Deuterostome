/*====================== D machine 3.0 (Linux): dm3.c =======================

   network operators and more:

    - connect
    - disconnect
    - send
    - getsocket
    - getmyname

*/

#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>
#include <netdb.h>
#include <fcntl.h>
#include "dm.h"
#include <unistd.h>
#include <string.h>

/* the following ansi bs needs to be here not in dm.h */
L init_sockaddr(struct sockaddr_in *name, const char *hostname, L port);

extern BOOLEAN timeout;
extern fd_set sock_fds;
extern L recsocket;
extern int h_errno;

/*---------------------------- support -------------------------------------*/

/*--------- makeDmemory */ 
 
void makeDmemory(B *em, L specs[5])
{
FREEopds = FLOORopds = (B*)(((((size_t) em) >> 3) + 1) << 3);
CEILopds = FLOORopds + specs[0] * FRAMEBYTES;

FLOORexecs = FREEexecs = CEILopds;
CEILexecs = FLOORexecs + specs[1] * FRAMEBYTES;

FLOORdicts = FREEdicts = CEILexecs;
CEILdicts = FLOORdicts + specs[2] * FRAMEBYTES;

FLOORvm = FREEvm = CEILdicts;
TOPvm = CEILvm  = FLOORvm + specs[3] * 1000000;
}


/*--------------------------- make a server socket */

L make_socket(L port)
{
  L sock;
  struct sockaddr_in name;

  sock = socket(PF_INET, SOCK_STREAM, 0);
  if (sock < 0) return(-1);
  name.sin_family = AF_INET;
  name.sin_port = port;
  name.sin_addr.s_addr = htonl(INADDR_ANY);
  if (bind(sock, (struct sockaddr *) &name, sizeof(name)) < 0)
    return(-1);
  return(sock);
}

/*--------------------------- initialize a socket address */

L init_sockaddr(struct sockaddr_in *name, const char *hostname,
		   L port)
{
  struct hostent *hostinfo;
  name->sin_family = AF_INET;
  name->sin_port = htons((UW)port);
  hostinfo = gethostbyname(hostname);
  if (hostinfo == 0) return(-h_errno);
  name->sin_addr = *(struct in_addr *) hostinfo->h_addr;
  return(OK);
}

/*--------------------------- read a message from a socket
 
 The message format is:
 
   frame   of the message string
   frame   of null or box object
   string  body of message string     (padded to ALIGN)
 [ box of message     ]               (padded to ALIGN)

 The contents of a box object are appended to the VM and the
 root object is pushed on the operand stack, whereas a null object is
 discarded. The string contents are written into the string buffer object,
 and an object representing the substring in the buffer is pushed on the
 operand stack. The return code reflects several overflow conditions,
 closure of the connection  from the other side, and misformatted or
 short messages; normal returns are:

  OK   - a message was read
  DONE - an 'end of file' message was received indicating disconnection
  LOST_CONN - lost connection while receiving message
   
*/

L fromsocket(L sock, B *bsf)
{
  L nb, nsbuf, atmost, retc;
  B *p, sf[2*FRAMEBYTES], *bf, *sbuf, sbsf[FRAMEBYTES];
  BOOLEAN isnative;

  moveframe(bsf,sbsf);
  nsbuf = ARRAY_SIZE(sbsf);
  sbuf = (B *)VALUE_BASE(sbsf);
  bf = sf + FRAMEBYTES;
  
  /*----- we give ourselves 10 sec */
  alarm(10);
  timeout = FALSE;

  /*----- get the string and box/null frames and evaluate */
  //rd0: 
  p = sf; atmost = 2*FRAMEBYTES;
rd1:
  if (timeout) return(BAD_MSG);
  nb = read(sock, p, atmost);
  if (nb < 0)
    { if((errno == EINTR) || (errno == EAGAIN)) goto rd1;
      else return(-errno);
    }
  if (nb == 0) return(DONE);
  p += nb;
  if ((atmost -= nb) > 0) goto rd1;
  
  if (! GETNATIVEFORMAT(sf) || ! GETNATIVEUNDEF(sf)) return BAD_FMT;
  if (! (isnative = GETNATIVEENDIAN(sf))) {
    if ((retc = deendian_frame(sf)) != OK) return retc; 
    if ((retc = deendian_frame(bf)) != OK) return retc;
  };
  FORMAT(sf) = 0;

  if (TAG(sf) != (ARRAY | BYTETYPE)) return(BAD_MSG);
  if (VALUE_BASE(sf) != 0 ) return(BAD_MSG);
  if (ARRAY_SIZE(sf) <= 0) return(BAD_MSG);
  if (ARRAY_SIZE(sf) > nsbuf) return(RNG_CHK);
  if ((CLASS(bf) != NULLOBJ) && (CLASS(bf) != BOX)) return(BAD_MSG);

/*----- get the string body */
p = sbuf; atmost = (L)DALIGN(ARRAY_SIZE(sf));
rd2:
  if (timeout) return(BAD_MSG);
  nb = read(sock, p, atmost);
  if (nb < 0)
    { if((errno == EINTR) || (errno == EAGAIN)) goto rd2;
      else return(-errno);
    }
  if (nb == 0) { return(LOST_CONN); }               /* connection blew up */
  p += nb;
  if ((atmost -= nb) > 0) goto rd2;

/*----- read the body of a received box */
  if (CLASS(bf) == NULLOBJ) goto ev3;
  if ((FREEvm + DALIGN(BOX_NB(bf))) > CEILvm) return(VM_OVF);
  p = FREEvm; atmost = BOX_NB(bf);
rd3:
  if (timeout) return(BAD_MSG);
  nb = read(sock, p, atmost);
  if (nb < 0)
    { if((errno == EINTR) || (errno == EAGAIN)) goto rd3;
      else return(-errno);
    }
  if (nb == 0) return(LOST_CONN);                 /* connection blew up */
  p += nb;
  if ((atmost -= nb) > 0) goto rd3;
 
/*----- relocate object tree of box and push root object on operand
        stack
*/
  if (! isnative && ((retc = deendian_frame(FREEvm)) != OK)) return retc;
  if ((retc = unfoldobj(FREEvm,(L)FREEvm, isnative)) != OK) return retc;
  if (o2 >= CEILopds) return(OPDS_OVF);
  moveframe(FREEvm,o1);                    /* root obj of box -> opds */
  FREEvm += BOX_NB(bf); 
  FREEopds = o2;
ev3:  /* push frame for substring in buffer on operand stack */
  moveframe(sbsf,o1); ARRAY_SIZE(o1) = ARRAY_SIZE(sf);
  FREEopds = o2;
return(OK);
}

/*------------------------------- write a message to a socket
   receives a string frame and either a nullframe or a composite-object
   frame; assembles a message in free VM (see 'fromsocket' above). Sends
   the message to the socket and returns after the complete message has
   been sent. Besides error conditions, return codes are:

    OK        - the message has been sent
    LOST_CONN - the message could not be sent due to a broken connection
*/

L tosocket(L sock, B *sf, B *cf)
{
  static B frame[FRAMEBYTES];
  L nb, atmost, retc; W d;
  B *p, *oldFREEvm, *bf;
  
  p = oldFREEvm = FREEvm;
  if (p + FRAMEBYTES > CEILvm) return VM_OVF;
  nb = FRAMEBYTES + FRAMEBYTES + DALIGN(ARRAY_SIZE(sf));
  if (p + nb > CEILvm) return(VM_OVF);
  moveframe(sf,p); VALUE_BASE(p) = 0; SETNATIVE(p);
  p += FRAMEBYTES; 
  bf = p; moveframe(cf,bf);   p += FRAMEBYTES;
  moveB((B *)VALUE_BASE(sf),p,ARRAY_SIZE(sf));
  p += DALIGN(ARRAY_SIZE(sf));
  if (CLASS(cf) != NULLOBJ)
    { 
      FREEvm = p; d = 0;
      moveframe(cf, frame);
      retc = foldobj(frame,(L)p,&d);
      TAG(bf) = BOX; ATTR(bf) = 0; 
      VALUE_BASE(bf) = 0; BOX_NB(bf) = FREEvm - p;
      nb += FREEvm - p;
      FREEvm = oldFREEvm;
      if (retc != OK) return(retc);
    }
  atmost = nb; p = FREEvm;

/*----- we give ourselves 10 sec to get this out */
  alarm(10);
  timeout = FALSE;
 wr1:
  if (timeout) return(TIMER);
  nb = write(sock, p, atmost);
  if (nb < 0) {
      if((errno == EAGAIN) || (errno == EINTR)) goto wr1;
      else if (errno == EPIPE) return(LOST_CONN); else return(-errno);
  }
  
  p += nb;
  if ((atmost -= nb) > 0) goto wr1;
  return(OK);
}

/*----------------------------------------------- connect
    servername port | socket

    NOTE: the socket is returned in the form of a NULL object of type
    SOCKETTYPE; such an object can be made or evaluated only by the
    network operators.
*/

L op_connect(void)
{
  L port, sock, retc, size = PACKET_SIZE;
  struct sockaddr_in serveraddr;

  if (o_2 < FLOORopds) return(OPDS_UNF);
  if (TAG(o_2) != (ARRAY | BYTETYPE)) return(OPD_ERR);
  if (CLASS(o_1) != NUM) return(OPD_CLA);
  if (!VALUE(o_1,&port)) return(UNDF_VAL);
  port += IPPORT_USERRESERVED;
  if ((FREEvm + ARRAY_SIZE(o_2) + 1) > CEILvm) return(VM_OVF);
  moveB((B *)VALUE_BASE(o_2),FREEvm,ARRAY_SIZE(o_2));
  FREEvm[ARRAY_SIZE(o_2)] = '\000';
  
  if ((sock = socket(PF_INET, SOCK_STREAM, 0)) < 0) return(-errno);
  if ((retc =                              /* set packet buffers size  */
      setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &size, sizeof(L))) == -1)
        return(-errno);
  if ((retc =
      setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &size, sizeof(L))) == -1)
        return(-errno);
  if ((retc = init_sockaddr(&serveraddr, FREEvm, port)) != OK)
    return(retc);
  if (connect(sock, (struct sockaddr *)&serveraddr,sizeof(serveraddr)) < 0)
    return(-errno);
   if (fcntl(sock, F_SETFL, O_NONBLOCK) == -1)   /* make non-blocking  */
      error(EXIT_FAILURE, errno, "fcntl");
  FD_SET(sock, &sock_fds);                      /* register the socket */
  TAG(o_2) = NULLOBJ | SOCKETTYPE; ATTR(o_2) = 0;
  LONG_VAL(o_2) = sock;
  FREEopds = o_1;
  return(OK);
}


/*----------------------------------------------- disconnect
    socket | --
*/

L op_disconnect(void)
{
  if (o_1 < FLOORopds) return(OPDS_UNF);
  if (TAG(o_1) != (NULLOBJ | SOCKETTYPE)) return(OPD_ERR);
  FD_CLR(LONG_VAL(o_1), &sock_fds);
  close(LONG_VAL(o_1));
  FREEopds = o_1;
  return(OK);
}

/*----------------------------------------------- send
    socket (string) | --
    socket [ rootobj (string) ] | --
*/

L op_send(void)
{
  L sock, retc; B * root, *string, nf[FRAMEBYTES];

  if (o_2 < FLOORopds) return(OPDS_UNF);
  if (TAG(o_2) != (NULLOBJ | SOCKETTYPE)) return(OPD_ERR);
  sock = LONG_VAL(o_2);
  if (TAG(o_1) == (ARRAY | BYTETYPE))
    { if (FREEvm + FRAMEBYTES > CEILvm) return(VM_OVF);
      TAG(nf) = NULLOBJ; ATTR(nf) = 0;
      root = nf; string = o_1; 
      goto send1;
    }
  else
    if (CLASS(o_1) == LIST)
      {
	root = (B *)VALUE_BASE(o_1);
	if ((CLASS(root) != LIST) && (CLASS(root) != DICT) &&
	    (CLASS(root) != ARRAY)) return(INV_MSG);
	string = root + FRAMEBYTES;
	if (TAG(string) != (ARRAY | BYTETYPE)) return(INV_MSG);
	if (string > (B *)LIST_CEIL(o_1)) return(INV_MSG);
        goto send1;
      }
    else return(OPD_CLA);

 send1:
 if ((retc = tosocket(sock,string,root)) != OK)
 {
   if (retc == LOST_CONN)
     { 
       close(sock); FD_CLR(sock, &sock_fds);
       return(retc);
     }
   else return(retc);
 }
 
 FREEopds = o_2; return(OK);
}

/*------------------------------------------- getsocket
    -- | socket

The socket is opaquely encoded in a null object of type socket.
*/

L op_getsocket(void)
{
  if (o1 >= CEILopds) return(OPDS_OVF);
  TAG(o1) = NULLOBJ | SOCKETTYPE; ATTR(o1) = 0;
  LONG_VAL(o1) = recsocket;
  FREEopds = o2;
  return(OK);
}

/*------------------------------------------- getmyname
    stringbuf | substring

returns the host's name
*/

L op_getmyname(void)
{
  if (o_1 < FLOORopds) return(OPDS_UNF);
  if (TAG(o_1) != (ARRAY | BYTETYPE)) return(OPD_ERR);
  if (gethostname((B *)VALUE_BASE(o_1),ARRAY_SIZE(o_1)) == -1)
      return(-errno);
      ARRAY_SIZE(o_1) = strlen((B *)VALUE_BASE(o_1));
      return(OK);
}


