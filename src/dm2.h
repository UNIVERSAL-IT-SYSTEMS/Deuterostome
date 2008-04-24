#ifndef DM_2_H
#define DM_2_H

#include "dm.h"

typedef P (*SourceFunc)(B* buffer, P size);

DLL_SCOPE P fromsource(B* bufferf, SourceFunc r1, SourceFunc r2);
DLL_SCOPE P tosource(B* rootf, BOOLEAN mksave, SourceFunc w1, SourceFunc w2);

DLL_SCOPE void makeDmemory(B *em, LBIG specs[5]);
DLL_SCOPE P wrap_hi(B* hival);
DLL_SCOPE P wrap_libnum(UP libnum);
DLL_SCOPE B* nextlib(B* frame);
DLL_SCOPE B* geterror(P e);
DLL_SCOPE B *makedict(L32 n);
DLL_SCOPE void cleardict(B *dict);
DLL_SCOPE B *makeopdictbase(B *opdefs, P *errc, B **errm, L32 n1);
DLL_SCOPE B *makeopdict(B *opdefs, P *errc, B **errm);
DLL_SCOPE void d_reloc(B *dict, P oldd, P newd);
DLL_SCOPE void d_rreloc(B *dict, P oldd, P newd);
DLL_SCOPE void makename(B *namestring, B *nameframe);
DLL_SCOPE void pullname(B *nameframe, B *namestring);
DLL_SCOPE P compname(B *nameframe1, B *nameframe2);
DLL_SCOPE BOOLEAN matchname(B *nameframe1, B *nameframe2);		
DLL_SCOPE B *lookup(B *nameframe, B *dict);
DLL_SCOPE BOOLEAN insert(B *nameframe, B *dict, B *framedef);
DLL_SCOPE BOOLEAN mergedict(B *socket, B *sink);
DLL_SCOPE P exec(L32 turns);
DLL_SCOPE P foldobj(B *frame, P base, W *depth);
DLL_SCOPE P unfoldobj(B *frame, P base, B isnonnative);
DLL_SCOPE P foldobj_ext(B* frame);
DLL_SCOPE BOOLEAN foldobj_mem(B** base, B** top);
DLL_SCOPE void foldobj_free(void);
DLL_SCOPE P deendian_frame(B *frame, B isnonnative);
//L deendian_array(B* frame, B isnonnative);
//L deendian_list(B* frame, B isnonnative);
//L deendian_dict(B* dict, B isnonnative);
//L deendian_entries(B* doct, B isnonnative);
DLL_SCOPE void setupdirs(void);


#endif //DM_2_H
