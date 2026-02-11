#include <stdio.h>
#include <stdlib.h>

// Keep the faulting load in a non-inlined function so -O2 does not collapse
// the test into a tiny stub that never executes the interesting path.
#if defined(__clang__)
__attribute__((optnone))
#endif
__attribute__((noinline)) static int read_uninitialized(const int *p) {
    return *p;
}

int main(void) {
    printf("hi hi");
    int *p = (int *)malloc(sizeof(int));  // memory is uninitialized

    int x = read_uninitialized(p);  // <-- MSan should report here

    if (x) {     // use the uninitialized value
        printf("x is non-zero: %d\n", x);
    } else {
        printf("x is zero: %d\n", x);
    }

    free(p);
    return 0;
}
