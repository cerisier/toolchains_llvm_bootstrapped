#ifndef FREEBSD_M4_COMPAT_H
#define FREEBSD_M4_COMPAT_H

#include <stddef.h>
#include <stdint.h>

#ifndef __dead2
#define __dead2 __attribute__((__noreturn__))
#endif

#ifndef __printf0like
#define __printf0like(format_index, first_argument) \
  __attribute__((__format__(__printf__, format_index, first_argument)))
#endif

#ifndef __unused
#define __unused __attribute__((__unused__))
#endif

#ifndef __nonstring
#define __nonstring
#endif

#ifndef __DECONST
#define __DECONST(type, value) ((type)(uintptr_t)(const void *)(value))
#endif

void *reallocarray(void *pointer, size_t count, size_t size);
size_t strlcat(char *destination, const char *source, size_t size);
size_t strlcpy(char *destination, const char *source, size_t size);
long long strtonum(const char *value, long long minimum, long long maximum,
                   const char **error);

#endif
