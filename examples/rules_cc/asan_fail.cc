#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int *p = (int*)malloc(sizeof(int));
    *p = 123;

    free(p);          // memory freed
    int x = *p;       // <-- Use-after-free (ASan catches)

    printf("%d\n", x);
    return 0;
}
