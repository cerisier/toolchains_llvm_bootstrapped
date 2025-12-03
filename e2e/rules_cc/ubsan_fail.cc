#include <limits.h>
#include <stdio.h>

int main(void) {
    volatile int a = INT_MAX;   // volatile keeps the ops from being optimized away
    volatile int one = 1;
    volatile int neg1 = -1;
    volatile int zero = 0;

    // 1) Signed integer overflow
    int s = a + one;

    // 2) Invalid shift (negative shift count)
    int t = 1 << neg1;

    // 3) Integer divide by zero
    int u = 123 / zero;

    // Prevent “unused” warnings and keep code live
    printf("s=%d t=%d u=%d\n", s, t, u);
    return 0;
}
