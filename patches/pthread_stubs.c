/* SCO has no pthread_cond/create/join. These are the only ones missing
 * from gnulib pthread-mutex.o / pthread-thread.o on SCO. */
int pthread_cond_init(void *a, void *b) { return 0; }
int pthread_cond_destroy(void *a) { return 0; }
int pthread_cond_signal(void *a) { return 0; }
int pthread_cond_broadcast(void *a) { return 0; }
int pthread_cond_wait(void *a, void *b) { return 0; }
