#include <stdint.h>
#include <stdlib.h>

#if defined(__clang__)
__attribute__((optnone))
#endif
__attribute__((noinline)) static void leak_memory(void) {
    char *p = (char *)malloc(64);
    p[0] = 42;
}

int main(void) {
    leak_memory();

    // Clobber stack state a bit so the leaked pointer is less likely to stay
    // conservatively reachable in stale stack slots.
    volatile uintptr_t sink = 0;
    for (uintptr_t i = 0; i < 256; ++i) {
        sink += i;
    }
    return (int)sink;
}
