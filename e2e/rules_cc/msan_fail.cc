#include <stdio.h>
#include <stdlib.h>

int main(void) {
    printf("hi hi");
    int *p = (int *)malloc(sizeof(int));  // memory is uninitialized

    int x = *p;  // <-- MSan should report an uninitialized read here

    if (x) {     // use the uninitialized value
        printf("x is non-zero: %d\n", x);
    } else {
        printf("x is zero: %d\n", x);
    }

    free(p);
    return 0;
}
