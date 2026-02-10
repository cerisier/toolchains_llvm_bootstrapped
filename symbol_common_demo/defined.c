#include <stdio.h>

int shared_symbol = 1234;  // Strong definition in C

int main(void) {
    printf("shared_symbol = %d\n", shared_symbol);
    return 0;
}
