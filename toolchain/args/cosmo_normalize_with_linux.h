#ifndef TOOLCHAIN_ARGS_COSMO_NORMALIZE_WITH_LINUX_H_
#define TOOLCHAIN_ARGS_COSMO_NORMALIZE_WITH_LINUX_H_

#include "libc/integral/normalize.inc"

// Restore Linux/Unix feature macros after cosmopolitan's normalization step so
// upstream projects (e.g. LLVM) take the Linux code paths they expect.
#undef linux
#undef __linux
#undef __linux__
#undef __gnu_linux__
#undef unix
#undef __unix__

#define linux 1
#define __linux 1
#define __linux__ 1
#define __gnu_linux__ 1
#define unix 1
#define __unix__ 1

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

#ifdef donothing
#undef donothing
#endif

#endif  // TOOLCHAIN_ARGS_COSMO_NORMALIZE_WITH_LINUX_H_
