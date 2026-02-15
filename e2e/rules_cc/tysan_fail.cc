#include <stdio.h>
#include <stdlib.h>

struct A {
    int x;
};

struct B {
    float y;
};

#if defined(__clang__)
__attribute__((optnone))
#endif
__attribute__((noinline)) static float read_as_b(const B *b) {
    return b->y;
}

int main(void) {
    A *a = (A *)malloc(sizeof(A));
    a->x = 123;

    // Deliberate strict-aliasing/type violation.
    float y = read_as_b((const B *)a);
    printf("y=%f\n", y);

    free(a);
    return 0;
}
