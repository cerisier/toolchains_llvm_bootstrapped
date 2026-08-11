#ifndef HERMETIC_LLVM_FREEBSD_RPCGEN_COMPAT_H
#define HERMETIC_LLVM_FREEBSD_RPCGEN_COMPAT_H

#include <stddef.h>
#include <string.h>

#ifndef __dead2
#define __dead2 __attribute__((noreturn))
#endif
#ifndef __unused
#define __unused __attribute__((unused))
#endif
#ifndef MAXPATHLEN
#define MAXPATHLEN 4096
#endif
#ifndef nitems
#define nitems(array) (sizeof(array) / sizeof((array)[0]))
#endif

static inline size_t
freebsd_rpcgen_strlcpy(char *destination, const char *source, size_t size)
{
    size_t source_length = strlen(source);
    if (size != 0) {
        size_t copy_length = source_length >= size ? size - 1 : source_length;
        memcpy(destination, source, copy_length);
        destination[copy_length] = '\0';
    }
    return source_length;
}

static inline size_t
freebsd_rpcgen_strlcat(char *destination, const char *source, size_t size)
{
    size_t destination_length = 0;
    size_t source_length = strlen(source);
    while (destination_length < size && destination[destination_length] != '\0')
        ++destination_length;
    if (destination_length < size) {
        size_t remaining = size - destination_length;
        size_t copy_length = source_length >= remaining ? remaining - 1 : source_length;
        memcpy(destination + destination_length, source, copy_length);
        destination[destination_length + copy_length] = '\0';
    }
    return destination_length + source_length;
}

#define strlcpy freebsd_rpcgen_strlcpy
#define strlcat freebsd_rpcgen_strlcat

#endif
