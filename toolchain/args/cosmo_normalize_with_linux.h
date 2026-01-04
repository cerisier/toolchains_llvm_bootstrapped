#ifndef TOOLCHAIN_ARGS_COSMO_NORMALIZE_WITH_LINUX_H_
#define TOOLCHAIN_ARGS_COSMO_NORMALIZE_WITH_LINUX_H_

#include "libc/integral/normalize.inc"

// normalize.inc clears the linux macros; restore the ones we actually rely on.
#ifndef __linux__
#define __linux__ 1
#endif
#ifndef __linux
#define __linux 1
#endif

#undef linux

#include "libc/stdio/syscall.h"
#include "libc/sysv/consts/nrlinux.h"

#undef SYS_gettid
#if defined(__NR_linux_gettid)
#define SYS_gettid __NR_linux_gettid
#elif defined(__NR_gettid)
#define SYS_gettid __NR_gettid
#endif

#undef SYS_rt_tgsigqueueinfo
#if defined(__NR_linux_tgsigqueueinfo)
#define SYS_rt_tgsigqueueinfo __NR_linux_tgsigqueueinfo
#elif defined(__NR_tgsigqueueinfo)
#define SYS_rt_tgsigqueueinfo __NR_tgsigqueueinfo
#elif defined(__aarch64__)
#define SYS_rt_tgsigqueueinfo 0xf0
#else
#define SYS_rt_tgsigqueueinfo 0x129
#endif

#ifndef SYS_futex
#if defined(__NR_linux_futex)
#define SYS_futex __NR_linux_futex
#elif defined(__NR_futex)
#define SYS_futex __NR_futex
#endif
#endif

#ifndef MNT_LOCAL
#define MNT_LOCAL 0
#endif

#if defined(__cplusplus) && !defined(COSMO_KEEP_DONOTHING)
#ifdef donothing
#undef donothing
#endif
#endif

#endif  // TOOLCHAIN_ARGS_COSMO_NORMALIZE_WITH_LINUX_H_
