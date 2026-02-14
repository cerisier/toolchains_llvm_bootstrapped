#include <pthread.h>
#include <stdio.h>

static int shared_counter = 0;

#if defined(__clang__)
__attribute__((optnone))
#endif
__attribute__((noinline)) static void *race_worker(void *unused) {
    (void)unused;
    for (int i = 0; i < 100000; ++i) {
        shared_counter++;
    }
    return NULL;
}

int main(void) {
    pthread_t t1;
    pthread_t t2;

    pthread_create(&t1, NULL, race_worker, NULL);
    pthread_create(&t2, NULL, race_worker, NULL);

    pthread_join(t1, NULL);
    pthread_join(t2, NULL);

    // Keep a visible side effect so the raced variable is used.
    printf("counter=%d\n", shared_counter);
    return 0;
}
