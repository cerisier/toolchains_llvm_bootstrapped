load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@llvm//toolchain/args:llvm_target_triple.bzl", "LLVM_TARGET_TRIPLE")
load("@llvm//toolchain/runtimes:cc_stage0_object.bzl", "cc_stage0_object")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

FREEBSD_RTLD_LIBC_SRCS = [
    "lib/libc/gen/setjmperr.c",
    "lib/libc/sys/lstat.c",
    "lib/libc/sys/stat.c",
]

FREEBSD_COMMON_COPTS = [
    "-std=gnu17",
    "-fPIC",
    "-fno-common",
    "-ftls-model=initial-exec",
    "-Wno-address-of-packed-member",
    "-Wno-deprecated-non-prototype",
    "-Wno-empty-body",
    "-Wno-enum-conversion",
    "-Wno-format-zero-length",
    "-Wno-knr-promoted-parameter",
    "-Wno-parentheses-equality",
    "-Wno-pointer-sign",
    "-Wno-string-plus-int",
    "-Wno-switch",
    "-Wno-switch-enum",
    "-Wno-tautological-compare",
    "-Wno-unused-const-variable",
    "-Wno-unused-function",
    "-Wno-unused-local-typedef",
    "-Wno-unused-value",
    "-Wno-error=unused-but-set-parameter",
    "-Qunused-arguments",
]

FREEBSD_LIBC_DEFINES = [
    "_ACL_PRIVATE",
    "_FORTIFY_SOURCE_read=_read",
    "_USE_LG_VADDR_WIDE",
    "BROKEN_DES",
    "CRT_IRELOC_RELA",
    "DES_BUILTIN",
    "INET6",
    "MALLOC_PRODUCTION",
    "NLS",
    "NO_COMPAT7",
    "NO__RCSID",
    "NO__SCCSID",
    "NS_CACHING",
    "PORTMAP",
    "POSIX_MISTAKE",
    "YP",
    "__DBINTERFACE_PRIVATE",
]

FREEBSD_LIBC_TZCODE_SRCS = [
    "contrib/tzcode/asctime.c",
    "contrib/tzcode/difftime.c",
    "contrib/tzcode/localtime.c",
    "lib/libc/stdtime/strftime.c",
    "lib/libc/stdtime/strptime.c",
    "lib/libc/stdtime/timelocal.c",
]

FREEBSD_LIBC_NONSHARED_SRCS = [
    "lib/libc/iconv/__iconv.c",
    "lib/libc/iconv/__iconv_free_list.c",
    "lib/libc/iconv/__iconv_get_list.c",
    "lib/libc/iconv/iconv.c",
    "lib/libc/iconv/iconv_canonicalize.c",
    "lib/libc/iconv/iconv_close.c",
    "lib/libc/iconv/iconv_open.c",
    "lib/libc/iconv/iconv_open_into.c",
    "lib/libc/iconv/iconv_set_relocation_prefix.c",
    "lib/libc/iconv/iconvctl.c",
    "lib/libc/iconv/iconvlist.c",
    "lib/libc_nonshared/__stub.c",
]

FREEBSD_ROOT_HEADERS = [
    "_semaphore.h",
    "aio.h",
    "errno.h",
    "fcntl.h",
    "float.h",
    "floatingpoint.h",
    "linker_set.h",
    "osreldate.h",
    "poll.h",
    "stdarg.h",
    "stdatomic.h",
    "stdint.h",
    "syslog.h",
    "ucontext.h",
]

_FREEBSD_INTERNAL_INCLUDE_DIRECTORIES = [
    ".",
    "include",
    "sys",
    "sys/crypto/chacha20",
    "lib/libc/include",
    "lib/libc/csu/common",
    "lib/libc/locale",
    "lib/libc/resolv",
    "lib/libc/rpc",
    "lib/libc/stdlib/malloc/jemalloc/include",
    "lib/libc/stdtime",
    "lib/csu/common",
    "lib/libsys",
    "lib/libutil",
    "lib/msun/src",
    "libexec/rtld-elf",
    "contrib/gdtoa",
    "contrib/jemalloc/include",
    "contrib/libc-pwcache",
    "contrib/libc-vis",
    "contrib/tzcode",
]

def freebsd_internal_include_directories(arch):
    directories = _FREEBSD_INTERNAL_INCLUDE_DIRECTORIES + [
        "lib/libc/{}".format(arch),
        "lib/libc/{}/gen".format(arch),
        "lib/libc/{}/string".format(arch),
        "lib/libc/csu/{}".format(arch),
        "lib/libsys/{}".format(arch),
        "lib/msun/{}".format(arch),
        "lib/csu/{}".format(arch),
        "libexec/rtld-elf/{}".format(arch),
    ]
    if arch == "aarch64":
        return directories + [
            "lib/msun/ld128",
            "contrib/arm-optimized-routines/string",
            "contrib/arm-optimized-routines/math",
        ]
    return directories + [
        "lib/libc/x86/gen",
        "lib/libsys/x86",
        "lib/msun/ld80",
        "lib/msun/x86",
    ]

def freebsd_libc_objects(
        name,
        arch,
        srcs,
        tzcode_srcs,
        common_copts,
        local_defines,
        pic):
    defines = local_defines + ([
        "PIC",
        "_SYSCALL_BODY(name)=",
    ] if pic else [])
    cc_library(
        name = name + "_objects",
        srcs = srcs,
        copts = common_copts,
        local_defines = defines,
        textual_hdrs = native.glob(["lib/libc/**/*.c"] + (
            ["contrib/arm-optimized-routines/**/*.S"] if arch == "aarch64" else []
        )) + ([
            "lib/libc/amd64/string/memcmp.S",
            "lib/libc/amd64/string/memmove.S",
        ] if arch == "amd64" else []) + [
            "lib/msun/src/s_scalbn.c",
            "sys/crypto/chacha20/chacha.c",
        ],
        deps = ["internal_headers"],
    )
    cc_library(
        name = name + "_tzcode_objects",
        srcs = tzcode_srcs,
        copts = common_copts + [
            "-include",
            "tzconfig.h",
        ],
        local_defines = defines + [
            "ALL_STATE",
            "DETECT_TZ_CHANGES",
            "THREAD_SAFE",
        ],
        deps = ["internal_headers"],
    )

def freebsd_crt1_object(name, arch, pic, common_copts):
    cc_library(
        name = name + "_c_source",
        srcs = ["lib/csu/{}/crt1_c.c".format(arch)],
        copts = common_copts + ["-fno-omit-frame-pointer"],
        local_defines = ["STRIP_FBSDID"] + (["PIC"] if pic else []),
        deps = ["internal_headers"],
    )
    cc_stage0_object(
        name = name + ".object",
        srcs = [
            "crt1_asm_sources",
            name + "_c_source",
        ],
        out = name + ".o",
        copts = ["-target"] + LLVM_TARGET_TRIPLE,
    )

def freebsd_crt_object(name, source, common_copts, shared = False):
    is_assembly = source.endswith(".S")
    cc_library(
        name = name + "_sources",
        srcs = [source] + (["lib/csu/common/crtbrand.S"] if name == "crti" else []),
        copts = ["-fPIC"] if is_assembly else common_copts,
        local_defines = (
            ["LOCORE"] if is_assembly else ["STRIP_FBSDID"] + (["PIC", "SHARED"] if shared else [])
        ),
        deps = ["internal_headers"],
    )
    cc_stage0_object(
        name = name + ".object",
        srcs = [name + "_sources"],
        out = name + ".o",
        copts = ["-target"] + LLVM_TARGET_TRIPLE,
    )

def freebsd_runtime_copy(name, src, out):
    copy_file(
        name = name,
        src = src,
        out = "runtime/" + out,
        allow_symlink = True,
    )
