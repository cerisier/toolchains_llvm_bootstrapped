#include <stdio.h>

#if defined(__clang__)
__attribute__((optnone))
#endif
__attribute__((noinline)) static int target(double value) {
    return (int)value;
}

int main(void) {
    typedef int (*int_fn)(int);
    int_fn fn = (int_fn)(void *)&target;

    // Mismatched function pointer call should trigger CFI icall checks.
    int result = fn(42);
    printf("result=%d\n", result);
    return 0;
}
