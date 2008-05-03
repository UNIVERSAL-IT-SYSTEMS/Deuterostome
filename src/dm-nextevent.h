#ifndef DM_NEXTEVENT_H
#define DM_NEXTEVENT_H

#include "dm.h"

#include <sys/select.h>

#define NEXTEVENT_NOEVENT (NEXTEVENT_ERRS+0) /* no event available */

DLL_SCOPE P nextevent(B* buffer);
DLL_SCOPE P makesocketdead(P retc, P socketfd, B* error_source);
DLL_SCOPE P op_send(void);

// There are defined externally
DLL_SCOPE BOOLEAN masterinput(P* retc, B* bufferf);
DLL_SCOPE P clientinput(void);
DLL_SCOPE BOOLEAN pending(void);
DLL_SCOPE void makeerror(P retc, B* error_source);

DLL_SCOPE P waitsocket(BOOLEAN ispending, fd_set* out_fds);
DLL_SCOPE P fromsocket(P socket, B* buffer);
DLL_SCOPE P nextXevent(void);
DLL_SCOPE BOOLEAN moreX(void);

#endif //DM_NEXTEVENT_H
