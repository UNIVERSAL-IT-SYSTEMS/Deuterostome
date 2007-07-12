#ifndef NEWFUNC_H
#define NEWFUNC_H

// This header is not intended to be included by cpp code, but by c-code.
// -- newfunc.cpp includes it and redefines the global new operator
// -- for cpp code, which then affects that code by being linked in
// -- as a library.
// The plugin C code includes this header to set the pool associated with
// -- each opaque object which will be used by associated C functions that
// -- then call into a cpp library.
// The calls for C are makeAllocator and setAllocator.

#if __cplusplus
#include <new>
#include "dmalloc-abort.h"

namespace Plugins
{
		using namespace std;
		using namespace Dmalloc;

		class SizeChecker 
		{
			protected:
				SizeChecker(size_t size) throw (bad_alloc) {
						if (size <= 128*sizeof(size_t)) throw bad_alloc();
				};
		};
		

		// Allocator takes a chunk of buffer as defined by a d-machine,
		//   - and then creates a mechanism for allocating it via C++ new.
		// Each Allocator is a global object - the current one set statically.
		// When global new and delete are called, they are redirected
		//   - to addNode and removeNode.
		// The C interface is defined at the end of the header.
		// The associated new and delete operators are defined in
		//   - newfunc.cpp; the library should be linked into the plugin
		//   - to replace the standard operators.
		class Allocator : protected SizeChecker
		{
			private:
				// Keep us from accidentally copying an Allocator
				Allocator& operator=(const Allocator& alloc);
				Allocator(const Allocator& alloc);
				
			public:
				// Create an Allocator with a pool starting at start buffer
				//   - with up to size bytes
				Allocator(void* start, size_t size) throw(bad_alloc);
				virtual ~Allocator(void) throw();

				// set the current Allocator used for new's
				//   - and return previous one.
				static Allocator* set(Allocator* alloc) throw();
				// get the current Allocator used for new's
				static Allocator* get(void) throw();
				
				// new operator for allocator; shifts start and size to
				//   - account for Allocator, and checks that that some size
				//   - is left.
				void* operator new(size_t s, void*& start, size_t& size)
						throw(bad_alloc);

				int leaked(void);

				void* malloc(size_t) throw();
				void  free(void*) throw();

		protected:
				// The current allocator used by new's
				static Allocator* currAlloc;

				void* space;
				size_t init_footprint;
		};

		struct Wrapper 
		{
				Wrapper(void) {};
				virtual ~Wrapper(void) {};

				enum errs {OK = 0, BAD_ALLOC = 1, ABORT_ALLOC = 2};
				
				errs operator()(void) {
						try {run();}
						catch (bad_alloc&) {return BAD_ALLOC;}
						catch (Abort&) {return ABORT_ALLOC;}
						return OK;
				};

				virtual void run(void) = 0;
		};
		
#define WrapperM(name, func)										\
		struct name: public Wrapper									\
		{																						\
				void run(void) func;										\
		}																						
#define WrapperMF(name, Name, func)							\
		int name(void) {WrapperM(Name, func); return (Name())();}
				
		template<typename A> struct Wrapper1 : public Wrapper
		{
				typedef Wrapper1<A> T;
				A a;
				Wrapper1(A a): a(a) {};
		};

#define Wrapper1M(name, type, func)												\
		struct	name: public Wrapper1<type> {									\
				name(type a): T(a) {};														\
				void run(void) func;															\
		}
#define Wrapper1MF(name, Name, type, func)\
		int name(type a) {Wrapper1M(Name, type, func); return (Name(a))();}
		
		template<typename A, typename B> struct Wrapper2 : public Wrapper
		{
				typedef Wrapper2<A, B> T;
				A a;
				B b;
				Wrapper2(A a, B b): a(a), b(b) {};
		};
#define Wrapper2M(name, type1, type2, func)								\
		struct	name: public Wrapper2<type1, type2> {					\
				name(type1 a, type2 b): T(a, b) {};								\
				void run(void) func;															\
		}
#define Wrapper2MF(name, Name, type1, type2, func)\
		int name(type1 a, type2 b) {									\
				Wrapper2M(Name, type1, type2, func);			\
				return (Name(a, b))();										\
		}
};

// Our C interface
extern "C" 
{
		// the versions for cpp compiler
		void*   makeAllocator(void* start, size_t size);
		void*   setAllocator(void* alloc);
#else
#include <stdlib.h>
		// a little sugar for the plugin library...
		typedef struct Allocator {} Allocator;
		// create a new Allocator at start, of size bytes.
		//   - The whole thing may get padding, then the
		//   - allocator itself gets built, then a little more
		//   - padding may be added.
		Allocator*   makeAllocator(void* start, size_t size);
		// set the current allocator (as returned by makeAllocator)
		//   - and return any previous allocator.
		Allocator*   setAllocator(Allocator* alloc);
		int leaked(void);
#endif
#if __cplusplus
}
#endif

#endif // NEWFUNC_H
