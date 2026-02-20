#include <string.h>

int main(int argc, char **argv) {
    if (argc > 1) {
        return strcmp(argv[1], "picolibc");
    }
    return strcmp("picolibc", "picolibc");
}
