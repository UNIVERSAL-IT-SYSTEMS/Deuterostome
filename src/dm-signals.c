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

#include <signal.h>
#include <errno.h>

#include "dm-signals.h"
#include "error-local.h"

// these must be kept in the same order as SIGMAP_* in dm-signals.h
// and SIGNALS in startup_common.din
// from
// http://pubs.opengroup.org/onlinepubs/009695399/basedefs/signal.h.html
static int sigmap[] = {
  SIGQUIT,
  SIGKILL,
  SIGTERM,
  SIGHUP,
  SIGINT,
  SIGALRM,
  SIGFPE,
  SIGABRT,
  SIGBUS,
  SIGCHLD,
  SIGCONT,
  SIGILL,
  SIGPIPE,
  SIGSEGV,
  SIGSTOP,
  SIGTSTP,
  SIGTTIN,
  SIGTTOU,
  SIGUSR1,
  SIGUSR2,
  SIGPOLL,
  SIGPROF,
  SIGSYS,
  SIGTRAP,
  SIGURG,
  SIGVTALRM,
  SIGXCPU,
  SIGXFSZ,
};

void propagate_sig(B sig, void (*redirect_sigf)(int sig)) {
  if (sig > (B) (sizeof(sigmap)/sizeof(sigmap[0])) || sig < 0) {
    dm_error_msg(0, "received illegal signal %i", sig);
    return;
  }

  redirect_sigf(sigmap[sig]);
}

UW encodesig(int sig) {
  UB i;
  for (i = 0; i < (UB) SIGMAP_LEN; i++)
    if (sig == sigmap[i]) return (UW) (0x80 | i);

  return (UW) (sig << 8);
}

int decodesig(UW sig) {
  UB subsig;
  if (! (sig & 0xFF)) return sig >> 8;

  subsig = (UB) (sig & 0x7F);
  if (subsig >= (UB) SIGMAP_LEN) return 0;
  return sigmap[subsig];
}

DM_INLINE_STATIC void initsa(struct sigaction* sa, BOOLEAN* init) {
  if (*init) return;
  *init = TRUE;
  sigfillset(&sa->sa_mask);
}
#define initsa(flags)				\
  static BOOLEAN init = FALSE;			\
  static struct sigaction sa = {		\
    .sa_handler = SIG_IGN,			\
    .sa_flags = flags				\
  };						\
  initsa(&sa, &init)

void clearhandler(enum SIGMAP sig)
{
  initsa(0);
  if (sigaction(sigmap[sig], &sa, NULL))
    dm_error(errno, "Unable to set signal handler for %i", sig);
}

void sethandler(enum SIGMAP sig,
		void (*handler)(int sig, siginfo_t* info, void* ucon))
{
  initsa(SA_SIGINFO);
  sa.sa_sigaction = handler;
  if (sigaction(sigmap[sig], &sa, NULL))
    dm_error(errno, "Unable to set signal handler for %i", sig);
}
