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
#ifndef DM3_H
#define DM3_H

#include "dm.h"
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>


struct SocketType {
  BOOLEAN resize;   // close on vmresize
  BOOLEAN fork;     // close on fork (or spawns)
  BOOLEAN exec;     // close on exec
  BOOLEAN proc;     // close in proc
  BOOLEAN listener; // used as a D-command socket
  char stdin;       // 1 if stdin, 0 if stderr/stdout, -1 else.
};

union SocketInfo {
  struct {
    P unixport;       // port number to construct unix file string (or 0)
    P sigfd;
    P recsigfd;
    P trecsigfd;
  } listener;
};

static const struct SocketType stdtype = {
  .listener = FALSE,
  .resize   = FALSE,
  .fork     = FALSE,
  .exec     = TRUE,
  .proc     = FALSE,
  .stdin    = -1
};

static const struct SocketType stdintype = {
  .listener = FALSE,
  .resize   = FALSE,
  .fork     = FALSE,
  .exec     = TRUE,
  .proc     = FALSE,
  .stdin    = 1
};

static const struct SocketType stdouttype = {
  .listener = FALSE,
  .resize   = FALSE,
  .fork     = FALSE,
  .exec     = TRUE,
  .proc     = FALSE,
  .stdin    = 0
};

static const struct SocketType stderrtype = {
  .listener = FALSE,
  .resize   = FALSE,
  .fork     = FALSE,
  .exec     = FALSE,
  .proc     = FALSE,
  .stdin    = 0
};

static const struct SocketType pipetype = {
  .listener = FALSE,
  .resize   = TRUE,
  .fork     = FALSE,
  .exec     = TRUE,
  .proc     = TRUE,
  .stdin    = -1
};

static const struct SocketType sockettype = {
  .listener = TRUE,
  .resize   = FALSE, // sockets closes are self-handling
  .fork     = TRUE,
  .exec     = TRUE,
  .proc     = FALSE,
  .stdin    = -1
};

static const union SocketInfo defaultsocketinfo = {
  .listener.unixport  = -1,
  .listener.sigfd     = -1,
  .listener.recsigfd  = -1,
  .listener.trecsigfd = -1,
};


DLL_SCOPE P make_socket(UW* port, BOOLEAN tcp, P packet_size, P* retc);
DLL_SCOPE P make_unix_socket(UW port, BOOLEAN isseq, P* retc);
DLL_SCOPE P toconsole(B *string, P stringlength);
DLL_SCOPE P fromsocket(P socket, B* buffer);
DLL_SCOPE P tosocket(P socket, B* rootf);

DLL_SCOPE P op_connect(void);
DLL_SCOPE P op_disconnect(void);
DLL_SCOPE P op_send(void);
DLL_SCOPE P op_sendsig(void);
DLL_SCOPE P op_getsocket(void);

DLL_SCOPE P readfd(P fd, B* where, P n, P secs);
DLL_SCOPE P writefd(P fd, B* where, P n, P secs);

DLL_SCOPE P nocloseonexec_simple(P fd);
DLL_SCOPE P closeonexec_simple(P fd);
DLL_SCOPE P closeonexec(P fd);
DLL_SCOPE P nocloseonexec(P fd);

DLL_SCOPE P op_socketdead(void);

DLL_SCOPE P addsocket(P fd, const struct SocketType* type, 
		      const union SocketInfo* info);
DLL_SCOPE P addsocket_dup(P fd);
DLL_SCOPE P delsocket_force(P fd);
DLL_SCOPE P delsocket_fork(P fd);
DLL_SCOPE P delsocket_exec(P fd);
DLL_SCOPE P delsocket_proc(P fd);

DLL_SCOPE void clearsocket(P fd);
DLL_SCOPE void clearsocket_special(P fd); //defined by dvt or dnode

DLL_SCOPE P closesockets_force(void);
DLL_SCOPE P closesockets_proc(void);
DLL_SCOPE P closesockets_fork(void);
DLL_SCOPE P closesockets_exec(void);
DLL_SCOPE P closesockets_resize(void);

DLL_SCOPE void set_closesockets_atexit(void);
DLL_SCOPE P dm_setsockopts(P fd, P size);

DLL_SCOPE P init_sockaddr(struct sockaddr_in *name, 
			  const char *hostname, 
			  UW port);

DLL_SCOPE P forksighandler(P sigsocket, P tcp_sigsocket, P serverport, P* pid);
DLL_SCOPE void initfds(void);

DLL_SCOPE void closedisplay(void);

#if ! DM_X_DISPLAY_MISSING

DLL_SCOPE P wm_take_focus_(XEvent* event, B* userdict);
DLL_SCOPE P wm_configure_notify_(XEvent* event, B* userdict);
DLL_SCOPE P wm_expose_(XEvent* event, B* userdict);
DLL_SCOPE P wm_button_press_(XEvent* event, B* userdict);

// everything below here is defined in the main modules (such as dvt or dnode)
// to be available in dm-nextevent.c
DLL_SCOPE P wm_delete_window(XEvent* event, B* userdict);
DLL_SCOPE P wm_take_focus(XEvent* event, B* userdict);
DLL_SCOPE P wm_configure_notify(XEvent* event, B* userdict);
DLL_SCOPE P wm_expose(XEvent* event, B* userdict);
DLL_SCOPE P wm_button_press(XEvent* event, B* userdict);

#endif //! DM_X_DISPLAY_MISSING

#endif //DM3_H
