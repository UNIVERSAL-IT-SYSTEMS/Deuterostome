#ifndef XHACK_H
#define XHACK_H

#if ! DM_X_DISPLAY_MISSING

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <setjmp.h>

extern jmp_buf xhack_buf;

#define H(...) __VA_ARGS__

#define xhackr(name, type, err, paramslist, params)		\
  DM_INLINE_STATIC type H##name(Display* d, paramslist) {	\
    if (! d) return (err);					\
    if (setjmp(xhack_buf)) return (err);			\
    return name(d, params);					\
  }

#define xhack(name, paramslist, params)			\
  xhackr(name, int, 0, H(paramslist), H(params))

#define xhack0(name)				\
  DM_INLINE_STATIC int H##name(Display* d) {	\
    if (! d) return 0;				\
    if (setjmp(xhack_buf)) return 0;		\
    return name(d);				\
  }

#define xhack0r(name, type, err)		\
  DM_INLINE_STATIC type H##name(Display* d) {	\
    if (! d) return (err);			\
    if (setjmp(xhack_buf)) return (err);	\
    return name(d);				\
  }

#define xhackv(name, paramslist, params)			\
  DM_INLINE_STATIC void H##name(Display* d, paramslist) {	\
    if (! d) return;						\
    if (setjmp(xhack_buf)) return;				\
    name(d, params);						\
  }

#define xhacks(name, paramslist, params)	\
  xhackr(name, Status, 0, H(paramslist), H(params))

#define xhackd(name, paramlist, params)		\
  xhack(name, H(Drawable dr, GC g, paramlist), H(dr, g, params))

xhack0(XCloseDisplay);
xhack0(XFlush);
xhack0(QLength);
xhack(XNextEvent, H(XEvent* x), H(x));
xhackr(XInternAtom, Atom, 0, H(char* a, Bool b), H(a, b));

xhack(XSetForeground, H(GC g, unsigned long p), H(g, p));
xhackr(XCreateWindow, Window, 0,
       H(Window parent, int x, int y,
	 unsigned int width, unsigned int height, 
	 unsigned int border_width, int depth, unsigned int classs, 
	 Visual *visual, unsigned long valuemask, 
	 XSetWindowAttributes *attributes),
       H(parent, x, y,
	 width, height, border_width, depth, classs, visual,
	 valuemask, attributes));

xhackv(XSetWMName, 
       H(Window w, XTextProperty *text_prop),
       H(w, text_prop));
xhackv(XSetWMIconName, 
       H(Window w, XTextProperty *text_prop),
       H(w, text_prop));

xhack(XSetClassHint, H(Window w, XClassHint *c), H(w, c));

xhacks(XSetWMProtocols, H(Window w, Atom* p, int c), H(w, p, c));
xhack(XSetWMHints, H(Window w, XWMHints* h), H(w, h));
xhacks(XSendEvent, H(Window w, Bool p, long l, XEvent* e), H(w, p, l, e));
xhack(XDestroyWindow, H(Window w), H(w));
xhack(XMapWindow, H(Window w), H(w));
xhack(XUnmapWindow, H(Window w), H(w));
xhack(XMapRaised, H(Window w), H(w));
xhack(XResizeWindow, H(Window w, unsigned w_, unsigned h), H(w, w_, h));
xhacks(XAllocColor, H(Colormap c, XColor* s), H(c, s));
xhackd(XFillRectangles, H(XRectangle* r, int n), H(r, n));
xhackd(XDrawLine, 
       H(int px1, int py1, int px2, int py2), H(px1, py1, px2, py2));
xhackd(XDrawPoint, H(int x, int y), H(x, y));
xhackd(XFillRectangle, 
       H(int x, int y, unsigned int w, unsigned int h), H(x, y, w, h));
xhackd(XDrawRectangle, H(int x, int y, int w, int h), H(x, y, w, h));
xhackd(XDrawLines, H(XPoint* p, int n, int m), H(p, n, m));
xhackd(XDrawSegments, H(XSegment* s, int n), H(s, n));
xhackd(XFillArc, 
       H(int x, int y, int w, int h, int a1, int a2), H(x, y, w, h, a1, a2));
xhackd(XDrawArc, 
       H(int x, int y, int w, int h, int a1, int a2), H(x, y, w, h, a1, a2));
xhack(XSetInputFocus, H(Window f, int r, Time t), H(f, r, t));
xhack(XFreeFont, H(XFontStruct* f), H(f));
xhackr(XLoadQueryFont, XFontStruct*, NULL, H(char* n), H(n));
xhack(XSetFont, H(GC g, Font f), H(g, f));
xhackd(XDrawString, H(int x, int y, char* s, int l), H(x, y, s, l));
xhackr(XCreateGC, GC, 0,
       H(Drawable dr, unsigned long v, XGCValues* x), H(dr, v, x))
xhack(XBell, H(int p), H(p));
xhack(XGetErrorText, H(int c, char* b, int l), H(c, b, l));
xhack(XGetErrorDatabaseText, 
      H(char* n, char* m, char* ds, char* b, int l), H(n, m, ds, b, l));
xhack0r(XDefaultScreenOfDisplay, Screen*, NULL);
xhack0r(XDefaultRootWindow, Window, 0);
xhacks(XGetWindowAttributes, H(Window w, XWindowAttributes* a), H(w, a));

#undef xhackd
#undef xhacks
#undef xhackv
#undef xhack0r
#undef xhack0
#undef xhack
#undef xhackr

#undef h

#endif // ! DM_X_DISPLAY_MISSING
#endif // XHACK_H
