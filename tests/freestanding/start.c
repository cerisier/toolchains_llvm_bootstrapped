__attribute__((noreturn)) void _start(void) {
    for (;;) {
        __asm__ volatile("" ::: "memory");
    }
}
