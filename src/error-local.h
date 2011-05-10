#ifndef ERROR_H
#define ERROR_H

#include "dm.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>

#define DM_IGNORE_RETURN(a) if (a);

static void va_error_local_msg(int errnum,
			       const char* format,
			       va_list ap)
{
  char* str;
  int s;

  if (vasprintf(&str, format, ap) != -1) {
    DM_IGNORE_RETURN(write(DM_STDERR_FILENO, str, strlen(str)));
    free(str);
  }

  if (errnum) s = asprintf(&str, ": %s\n", strerror(errnum));
  else s = asprintf(&str, "\n");

  if (s != -1) {
    DM_IGNORE_RETURN(write(DM_STDERR_FILENO, str, strlen(str)));
    free(str);
  }
}

__attribute__ ((unused, format (printf, 2, 3)))
static void error_local_msg(int errnum,
			    const char* format,
			    ...)
{
  va_list ap;
  va_start(ap, format);
  va_error_local_msg(errnum, format, ap);
  va_end(ap);
}

static void va_error_local(int status,
			   int errnum,
			   const char* format,
			   va_list ap)
{
  va_error_local_msg(errnum, format, ap);
  if (status) exit(status);
}


__attribute__ ((unused, format (printf, 3, 4)))
static void error_local(int status,
			int errnum,
			const char* format,
			...)
{
  va_list ap;
  va_start(ap, format);
  va_error_local(status, errnum, format, ap);
  va_end(ap);
}


#define error MAKEITANERROR

#define DEBUG_(t, format, ...) do {					\
    if (t) {								\
      error_local_msg(0, "%li: " format,				\
		      (long) getpid(), __VA_ARGS__);			\
    };									\
  } while (0)

#ifndef DEBUG_ACTIVE
#define DEBUG_ACTIVE 0
#endif //DEBUG_ACTIVE
#define DEBUG(...) DEBUG_(DEBUG_ACTIVE, __VA_ARGS__)

#endif //ERROR_H
