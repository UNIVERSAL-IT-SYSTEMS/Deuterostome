#include "dm.h"

#include <pthread.h>
#include <stdlib.h>
#include <errno.h>
#include <signal.h>

#include "dm.h"
#include "threads.h"
#include "error-local.h"

#if DM_ENABLE_THREADS

// thread[0] is the main thread in all arrays
// Therefore, elements 0 is empty.
pthread_t threads[THREADNUM] = {};
BOOLEAN thread_start[THREADNUM] = {};
UP thread_end = 0;
UP thread_num_ = 1;
UP thread_max_ = 0;
pthread_cond_t thread_wait[THREADNUM] = {};
pthread_mutex_t thread_lock[THREADNUM] = {};
thread_func thread_function = NULL;
P thread_error[THREADNUM] = {};
const void* thread_data_global = NULL;
void* thread_data_local[THREADNUM] = {};
sigset_t sigmask;

//pthread_attr_t attr;
//BOOLEAN attr_i = FALSE;
pthread_cond_t main_wait;
BOOLEAN main_wait_i = FALSE;
pthread_mutex_t main_lock;
BOOLEAN main_lock_i = FALSE;
pthread_mutex_t share_lock;
BOOLEAN share_lock_i = FALSE;

#define THREAD_ERROR_EXIT(func, msg, ...) do {                          \
    int err;                                                            \
    if ((err = func(__VA_ARGS__)))                                      \
      error_local(EXIT_FAILURE, err,                                          \
            "%s in %s:%d with %s(%s)",                                  \
            msg, __FILE__, __LINE__, #func, #__VA_ARGS__);              \
  } while (0)

#define THREADERR(func, ...) THREAD_ERROR_EXIT(func, "thread", __VA_ARGS__)
#define MAINERR(func, ...) THREAD_ERROR_EXIT(func, "main", __VA_ARGS__)

void thread_unlock_lock(void* arg) {
  UP thread_id = (UP) arg;
  THREADERR(pthread_mutex_unlock, thread_lock+thread_id);
}

void thread_destroy_lock(void* arg) {
  UP thread_id = (UP) arg;
  THREADERR(pthread_mutex_destroy, thread_lock+thread_id);
}

void thread_destroy_wait(void* arg) {
  UP thread_id = (UP) arg;
  THREADERR(pthread_cond_destroy, thread_wait+thread_id);
}

void* thread_routine(void* arg) {
  UP thread_id = (UP) arg;

  THREADERR(pthread_cond_init, thread_wait+thread_id, NULL);
  pthread_cleanup_push(thread_destroy_wait, (void*) thread_id);

  THREADERR(pthread_mutex_init, thread_lock+thread_id, NULL);
  pthread_cleanup_push(thread_destroy_lock, (void*) thread_id);

  THREADERR(pthread_mutex_lock, thread_lock+thread_id);
  pthread_cleanup_push(thread_unlock_lock, (void*) thread_id);

  THREADERR(pthread_sigmask, SIG_BLOCK, &sigmask, NULL);

  THREADERR(pthread_mutex_lock, &main_lock);
  --thread_end;
  THREADERR(pthread_cond_signal, &main_wait);
  THREADERR(pthread_mutex_unlock, &main_lock);

  while (TRUE) {
        thread_start[thread_id] = FALSE;
        do {          
          THREADERR(pthread_cond_wait, 
                    thread_wait+thread_id, 
                    thread_lock+thread_id);
          // The following is due to fucked up osx pthread_cancel
          pthread_testcancel();
        } while (! thread_start[thread_id]);

	thread_error[thread_id]
            = thread_function(thread_id, thread_data_global,
                              thread_data_local[thread_id]);
	THREADERR(pthread_mutex_lock, &main_lock);
        --thread_end;
	THREADERR(pthread_cond_signal, &main_wait);
	THREADERR(pthread_mutex_unlock, &main_lock);
  }

  pthread_cleanup_pop(1);
  pthread_cleanup_pop(1);
  pthread_cleanup_pop(1);

  return NULL;
}

P threads_do_int(UP nways, thread_func func,
                 const void* global,
                 void* local, size_t s) {
  UP i;
  if (nways > thread_num()) return RNG_CHK;
  
  thread_max_ = nways-1;
  thread_function = func;
  thread_data_global = global;
  if (local) for (i = nways; i--;) thread_data_local[i] = local+s*i;
  else       for (i = nways; i--;) thread_data_local[i] = NULL;

  MAINERR(pthread_mutex_lock, &main_lock);
  for (i = 1; i < nways; ++i) {
    MAINERR(pthread_mutex_lock, thread_lock+i);
    thread_start[i] = TRUE;
    MAINERR(pthread_cond_signal, thread_wait+i);
    MAINERR(pthread_mutex_unlock, thread_lock+i);
  }

  thread_error[0] = thread_function(0, thread_data_global,
                                    thread_data_local[0]);

  thread_end = thread_max();
  while (thread_end)    
    MAINERR(pthread_cond_wait, &main_wait, &main_lock);
  MAINERR(pthread_mutex_unlock, &main_lock);

  for (i = 0; i < nways; ++i)
    if (thread_error[i]) return thread_error[i];

  return OK;
}

DM_INLINE_STATIC P threads_do_pool_int_(UP nways, thread_func func, 
                              const void* global, 
                              void* local, size_t s) {
  UP i; P r;
  if ((P) nways < 0) return RNG_CHK;
    
  for (i = (P) nways; i > 0; i -= thread_num()) {
    if ((r = threads_do_int((i < thread_num()) ? i : thread_num(), 
                            func, global, local, s)) != OK)
      return r;
    local += s*thread_num();
  }
  return OK;
}

P threads_do_pool_int(UP nways, thread_func func, 
                      const void* global, 
                      void* local, size_t s) {
  UP i; P r; void* alloc = NULL;
  if (! local) {
    if (! (local = alloc = malloc(sizeof(UP)*nways))) return MEM_OVF;
    for (i = nways; i--;) ((UP*) local)[i] = i;
    s = sizeof(UP);
  }
  r = threads_do_pool_int_(nways, func, global, local, s);
  free(alloc);
  return r;
}

#define PRINT_ERRNO(func, ...)                             \
  error_local(0, _errno, "At %s:%d with %s(%s)",                 \
        __FILE__, __LINE__, #func, #__VA_ARGS__)


#define THREADS_DESTROY(func, ...) do {                       \
    int _errno;                                               \
    if ((_errno = func(__VA_ARGS__))) {                       \
      if (! errno_) errno_ = _errno;                          \
      PRINT_ERRNO(func, __VA_ARGS__);                         \
    }                                                         \
  } while (0)

P threads_destroy(P errno_) {
  P n = thread_num_-1;
  if (thread_num_ == 1) return OK;
    
  while (thread_num_ > 1) {
    --thread_num_;
    // The following is due to fucked up osx pthread_cancel
    MAINERR(pthread_mutex_lock, thread_lock+thread_num_);
    THREADS_DESTROY(pthread_cancel, threads[thread_num_]);
    MAINERR(pthread_cond_signal, thread_wait+thread_num_);
    MAINERR(pthread_mutex_unlock, thread_lock+thread_num_);
  }
  
  for (; n; --n)
    THREADS_DESTROY(pthread_join, threads[n], NULL);
  
  return -errno_;
}

#define THREADS_INIT_TEST(p, func, ...) do {             \
    if (! p##_i) {                                       \
      int _errno;                                        \
      if ((_errno = func(&p, __VA_ARGS__))) {            \
        PRINT_ERRNO(func, &p, __VA_ARGS__);              \
        return threads_destroy(_errno);                  \
      }                                                  \
      p##_i = TRUE;                                      \
    }                                                    \
  } while (0)

#define THREADS_INITD() do {                                            \
    thread_end = thread_num_-1;                                         \
    while(thread_end)                                                   \
      MAINERR(pthread_cond_wait, &main_wait, &main_lock);               \
    MAINERR(pthread_mutex_unlock, &main_lock);                          \
  } while (0)

#define THREADS_INIT(func, ...) do {              \
    int _errno;                                   \
    if ((_errno = func(__VA_ARGS__))) {           \
      PRINT_ERRNO(func, __VA_ARGS__);             \
      THREADS_INITD();                            \
      return threads_destroy(_errno);             \
    }                                             \
  } while (0)



P threads_init(P num) {
  if (num < 1 || num > THREADNUM) return RNG_CHK;
  if (num == 1) return OK;

  if (sigfillset(&sigmask)) return -errno;
  THREADS_INIT_TEST(share_lock, pthread_mutex_init, NULL);
  THREADS_INIT_TEST(main_lock, pthread_mutex_init, NULL);
  THREADS_INIT_TEST(main_wait, pthread_cond_init, NULL);

  MAINERR(pthread_mutex_lock, &main_lock);
  for (; thread_num_ < (UP)num; thread_num_++)
    THREADS_INIT(pthread_create,
                 threads + thread_num_,
                 NULL, //&attr,
                 thread_routine,
                 (void*) thread_num_);
  THREADS_INITD();
  
  return OK;
}

void thread_share_unlock_f(void) {
  THREADERR(pthread_mutex_unlock, &share_lock);
}

void thread_share_lock_f(void) {
    THREADERR(pthread_mutex_lock, &share_lock);
}


/**************************************** op_threads
 *
 * -- | n
 * returns the number of threads (1 <= n <= THREADNUM)
 */
P op_threads(void) {
  if (o2 > CEILopds) return OPDS_OVF;
  TAG(o1) = NUM | LONGBIGTYPE; 
  ATTR(o1) = 0;
  LONGBIG_VAL(o1) = thread_num();
  FREEopds = o2;
  return OK;
}

/**************************************** op_makethreads
 *
 * n | --
 * if n==1, destroy all threads but main
 * else destroy current threads, create n-1 new threads
 *
 */
P op_makethreads(void) {
  LBIG n; 
  P ret;

  if (FLOORopds > o_1) return OPDS_UNF;
  if (CLASS(o_1) != NUM) return OPD_CLA;
  if (! VALUE(o_1, &n)) return UNDF_VAL;

  if ((ret = threads_destroy(0)) == OK 
      && (ret = threads_init((P)n)) == OK)
    FREEopds = o_1;
  return ret;
}

#endif
