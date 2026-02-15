#include <stdio.h>

int main(void) {
    void *unsafe_ptr = __builtin___get_unsafe_stack_ptr();
    if (unsafe_ptr == nullptr) {
        fprintf(stderr, "unsafe_stack_ptr=null\n");
        return 1;
    }

    printf("unsafe_stack_ptr=%p\n", unsafe_ptr);
    return 0;
}
