load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_object.bzl", "cc_stage2_object")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_static_library.bzl", "cc_stage2_static_library")
load("@toolchains_llvm_bootstrapped//toolchain/args:llvm_target_triple.bzl", "LLVM_TARGET_TRIPLE")
load("@toolchains_llvm_bootstrapped//runtimes/cosmo:cosmo_cc_library.bzl", "COSMO_COMMON_COPTS", "NO_MAGIC_COPTS", "cosmo_cc_library")
load("@toolchains_llvm_bootstrapped//runtimes/cosmo:static_archive_file.bzl", "cc_static_lib_file")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "normalize_inc",
    srcs = ["libc/integral/normalize.inc"],
)

"""
Build file for the Cosmopolitan libc release (4.0.2).

This mirrors the upstream Makefile structure:
 - `crt` entry object (libc/crt/crt.S)
 - `cosmopolitan` static archive
 - headers and tzdata exports
"""

COSMO_LIBRARY_DIRS = [
    "ctl",
    "dsp/audio",
    "libc/calls",
    "libc/dlopen",
    "libc/elf",
    "libc/fmt",
    "libc/intrin",
    "libc/irq",
    "libc/log",
    "libc/mem",
    "libc/nexgen32e",
    "libc/nt",
    "libc/proc",
    "libc/runtime",
    "libc/sock",
    "libc/stdio",
    "libc/str",
    "libc/system",
    "libc/sysv",
    "libc/thread",
    "libc/tinymath",
    "libc/vga",
    "libc/x",
    "net/http",
    "third_party/compiler_rt",
    "third_party/dlmalloc",
    "third_party/double-conversion",
    "third_party/gdtoa",
    "third_party/getopt",
    "third_party/musl",
    "third_party/nsync",
    #"third_party/openmp",
    "third_party/puff",
    #"third_party/regex",
    "third_party/tz",
    "third_party/xed",
    "third_party/zlib",
    "tool/args",
]

# Headers and textual includes used across the COSMOPOLITAN packages.
filegroup(
    name = "libc_hdrs",
    srcs = glob(
        ["%s/**/*.%s" % (d, ext) for d in COSMO_LIBRARY_DIRS + [
            "libc",
            "libc/isystem",
            "ape",
            "third_party/musl",
            "third_party/openmp",
        ] for ext in ["h", "inc"]] + [
            "third_party/xed/**/*.def",
            "third_party/xed/**/*.tbl",
        ],
        exclude = [
            "libc/crt/**",
            "third_party/libcxx/**",
            "third_party/libcxx/build/**",
            "third_party/libcxx/test/**",
            "third_party/libcxx/**/test/**",
            "third_party/libcxx/examples/**",
            "examples/**",
            "test/**",
            "**/test/**",
            "build/**",
        ],
        allow_empty = True,
    ) + glob(
        ["tool/decode/**/*.h"],
        allow_empty = True,
    ) + glob(
        ["third_party/make/**/*.h"],
        allow_empty = True,
    ) + glob(
        ["third_party/intel/**/*.%s" % ext for ext in ["h", "inc"]],
        allow_empty = True,
    ) + glob(
        ["third_party/aarch64/**/*.%s" % ext for ext in ["h", "inc"]],
        allow_empty = True,
    ) + glob(
        ["third_party/linenoise/**/*.h"],
        allow_empty = True,
    ) + glob(
        ["third_party/libcxxabi/**"],
        exclude = [
            "third_party/libcxxabi/test/**",
            "third_party/libcxxabi/build/**",
        ],
        allow_empty = True,
    ) + glob(
        ["third_party/libunwind/**"],
        exclude = [
            "third_party/libunwind/test/**",
            "third_party/libunwind/build/**",
        ],
        allow_empty = True,
    ) + glob(
        ["third_party/libcxx/**"],
        exclude = [
            "third_party/libcxx/build/**",
            "third_party/libcxx/test/**",
            "third_party/libcxx/**/test/**",
            "third_party/libcxx/examples/**",
        ],
        allow_empty = True,
    ) + glob(
        ["third_party/lua/**/*.h"],
        allow_empty = True,
    ),
)

# tzdata ships in the release and is needed by libc/timezone code.
filegroup(
    name = "tzdata",
    srcs = glob(["usr/share/zoneinfo/**"]),
)

COSMO_AUDIO_COPTS = COSMO_COMMON_COPTS + [
    "-include",
    "libc/isystem/windowsesque.h",
    "-include",
    "libc/isystem/sys/time.h",
]

COSMO_COMMON_EXCLUDES = [
    "libc/crt/**",
    "dsp/audio/cosmoaudio/**",
    "ctl/new.cc",
    "examples/**",
    "test/**",
    "**/test/**",
    "build/**",
]

_COMPILER_RT_DEP = ":third_party_compiler_rt"

ZLIB_COMMON_COPTS = COSMO_COMMON_COPTS + [
    "-ffunction-sections",
    "-fdata-sections",
] + select({
    "@platforms//cpu:aarch64": [
        "-DADLER32_SIMD_NEON",
        "-DDEFLATE_SLIDE_HASH_NEON",
        "-DINFLATE_CHUNK_SIMD_NEON",
        "-DINFLATE_CHUNK_READ_64LE",
    ],
    "//conditions:default": [],
})

ZLIB_BASE_SRCS = [
    "third_party/zlib/adler32.c",
    "third_party/zlib/compress.c",
    "third_party/zlib/cpu_features.c",
    "third_party/zlib/crc32.c",
    "third_party/zlib/infback.c",
    "third_party/zlib/inffast.c",
    "third_party/zlib/inflate.c",
    "third_party/zlib/inftrees.c",
    "third_party/zlib/notice.c",
    "third_party/zlib/treeconst.c",
    "third_party/zlib/trees.c",
    "third_party/zlib/uncompr.c",
    "third_party/zlib/zutil.c",
]

ZLIB_X86_SIMD_SRCS = [
    "third_party/zlib/adler32_simd.c",
    "third_party/zlib/crc_folding.c",
    "third_party/zlib/crc32_simd_sse42.c",
    "third_party/zlib/crc32_simd_avx512.c",
]

ZLIB_AARCH64_SIMD_SRCS = [
    "third_party/zlib/crc32_simd_neon.c",
]

ZLIB_DEFLATE_SRC = "third_party/zlib/deflate.c"

ZLIB_DEPS = [
    ":libc_intrin",
    ":libc_nexgen32e",
    ":libc_mem",
    ":libc_str",
    ":libc_sysv",
]

# GCC-only -Walloca-larger-than is skipped since clang reports it as unknown.
TZ_COMMON_COPTS = COSMO_COMMON_COPTS + [
    "-Wframe-larger-than=4096",
]

TZ_BASE_SRCS = [
    "third_party/tz/daylight.c",
    "third_party/tz/difftime.c",
    "third_party/tz/timezone.c",
    "third_party/tz/tzname.c",
]

TZ_LOCALTIME_SRC = "third_party/tz/localtime.c"

TZ_DEPS = [
    ":libc_intrin",
    ":libc_calls",
    ":libc_mem",
    ":libc_nexgen32e",
    ":libc_nt",
    ":libc_runtime",
    ":libc_stdio",
    ":libc_str",
    ":libc_sysv",
]

MUSL_COMMON_COPTS = COSMO_COMMON_COPTS + [
    "-Wframe-larger-than=4096",
]

MUSL_PORTCOSMO_SRCS = [
    "third_party/musl/getnameinfo.c",
    "third_party/musl/lookup_name.c",
    "third_party/musl/lookup_serv.c",
]

MUSL_DEPS = [
    ":libc_calls",
    ":libc_fmt",
    ":libc_intrin",
    ":libc_mem",
    ":libc_nexgen32e",
    ":libc_nt",
    ":libc_proc",
    ":libc_runtime",
    ":libc_sock",
    ":libc_stdio",
    ":libc_str",
    ":libc_sysv",
    ":libc_thread",
    ":third_party_tz",
    ":third_party_zlib",
]

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/calls/BUILD.mk
cosmo_cc_library(
    name = "libc_calls",
    dir = "libc/calls",
    textual_hdrs = [":libc_hdrs"],
    copts = [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
        #"-Walloca-larger-than=4096",
    ],
    aarch64_safe_assembly_srcs = [
        #"libc/calls/stackjump.S",
    ],
    aarch64_srcs_excludes = [
        "libc/calls/rdrand.c",
    ],
    per_file_copts = {
        "libc/calls/termios2host.c": [
            "-O3",
            "-ffreestanding",
            "-mgeneral-regs-only",
        ],
        "libc/calls/siginfo2cosmo.c": [
            "-O3",
            "-ffreestanding",
            "-mgeneral-regs-only",
        ],
        "libc/calls/sigenter-freebsd.c": [
            "-O3",
            "-ffreestanding",
            "-mgeneral-regs-only",
        ],
        "libc/calls/sigenter-netbsd.c": [
            "-O3",
            "-ffreestanding",
            "-mgeneral-regs-only",
        ],
        "libc/calls/sigenter-openbsd.c": [
            "-O3",
            "-ffreestanding",
            "-mgeneral-regs-only",
        ],
        "libc/calls/sigenter-xnu.c": [
            "-O3",
            "-ffreestanding",
            "-mgeneral-regs-only",
        ],
        # "libc/calls/ntcontext2linux.c": [
        #     "-O3",
        #     "-ffreestanding",
        #     "-mgeneral-regs-only",
        # ] + select({
        #     "@platforms//cpu:x86_64": ["-mstringop-strategy=loop"],
        #     "//conditions:default": [],
        # }),

        "libc/calls/open.c": ["-Os"],
        "libc/calls/openat.c": ["-Os"],
        "libc/calls/prctl.c": ["-Os"],

        "libc/calls/getcwd.greg.c": ["-Os"],
        "libc/calls/statfs2cosmo.c": [
            "-Os",
            "-mgeneral-regs-only",
        ],

        "libc/calls/gettimeofday.c": [
            "-O2",
            "-mgeneral-regs-only",
        ],
        # "libc/calls/clock.c": ["-O2"],
        # "libc/calls/clock_gettime-mono.c": ["-O2"],
        # "libc/calls/timespec_tomillis.c": ["-O2"],
        # "libc/calls/timespec_tomicros.c": ["-O2"],
        # "libc/calls/timespec_totimeval.c": ["-O2"],
        # "libc/calls/timespec_fromnanos.c": ["-O2"],
        # "libc/calls/timespec_frommillis.c": ["-O2"],
        # "libc/calls/timespec_frommicros.c": ["-O2"],
        # "libc/calls/timeval_tomillis.c": ["-O2"],
        # "libc/calls/timeval_frommillis.c": ["-O2"],
        # "libc/calls/timeval_frommicros.c": ["-O2"],

        "libc/calls/sigaction.c": [
            "-mgeneral-regs-only",
        ] + select({
            "@platforms//cpu:aarch64": [
                "-mcmodel=large",
                "-fno-pic",
            ],
            "//conditions:default": [],
        }),
        "libc/calls/getloadavg-nt.c": select({
            "@platforms//cpu:aarch64": ["-ffreestanding"],
            "//conditions:default": [],
        }),

        "libc/calls/pledge-linux.c": [
            "-Os",
            "-fPIC",
            "-ffreestanding",
            "-mgeneral-regs-only",
        ],
        # "libc/calls/sigcrashsig.c": ["-Os"],

        "libc/calls/cfmakeraw.c": ["-mgeneral-regs-only"],
        # "libc/calls/clock_gettime-xnu.c": ["-mgeneral-regs-only"],
        "libc/calls/CPU_AND.c": ["-mgeneral-regs-only"],
        "libc/calls/CPU_OR.c": ["-mgeneral-regs-only"],
        "libc/calls/CPU_XOR.c": ["-mgeneral-regs-only"],
        "libc/calls/dl_iterate_phdr.c": ["-mgeneral-regs-only"],
        "libc/calls/dup-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/fcntl-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/flock-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/fstatfs-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/fstat-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/futimesat.c": ["-mgeneral-regs-only"],
        "libc/calls/futimes.c": ["-mgeneral-regs-only"],
        "libc/calls/getrlimit.c": ["-mgeneral-regs-only"],
        "libc/calls/ioctl.c": ["-mgeneral-regs-only"],
        "libc/calls/lutimes.c": ["-mgeneral-regs-only"],
        "libc/calls/metaflock.c": ["-mgeneral-regs-only"],
        "libc/calls/ntaccesscheck.c": ["-mgeneral-regs-only"],
        "libc/calls/ntspawn.c": ["-mgeneral-regs-only"],
        "libc/calls/open-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/ppoll.c": ["-mgeneral-regs-only"],
        "libc/calls/preadv.c": ["-mgeneral-regs-only"],
        "libc/calls/pselect.c": ["-mgeneral-regs-only"],
        "libc/calls/pwritev.c": ["-mgeneral-regs-only"],
        "libc/calls/read-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/readv.c": ["-mgeneral-regs-only"],
        "libc/calls/readwrite-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/releasefd.c": ["-mgeneral-regs-only"],
        "libc/calls/select.c": ["-mgeneral-regs-only"],
        "libc/calls/sigignore.c": ["-mgeneral-regs-only"],
        "libc/calls/signal.c": ["-mgeneral-regs-only"],
        # "libc/calls/sig.c": ["-mgeneral-regs-only"],
        "libc/calls/sigtimedwait.c": ["-mgeneral-regs-only"],
        "libc/calls/stat2cosmo.c": ["-mgeneral-regs-only"],
        "libc/calls/statfs2statvfs.c": ["-mgeneral-regs-only"],
        "libc/calls/tcgetattr-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/tcgetattr.c": ["-mgeneral-regs-only"],
        "libc/calls/tcgetwinsize-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/tcsetattr-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/tcsetwinsize-nt.c": ["-mgeneral-regs-only"],
        "libc/calls/timespec_sleep.c": ["-mgeneral-regs-only"],
        "libc/calls/uname.c": ["-mgeneral-regs-only"],
        "libc/calls/utimensat-old.c": ["-mgeneral-regs-only"],
        "libc/calls/utimes.c": ["-mgeneral-regs-only"],
        "libc/calls/winexec.c": ["-mgeneral-regs-only"],
        "libc/calls/writev.c": ["-mgeneral-regs-only"],
    },
    deps = [
        ":libc_fmt",
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_str",
        ":libc_sysv",
        _COMPILER_RT_DEP,
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_crt",
    srcs = glob(
        ["libc/crt/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_calls",
        ":libc_elf",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_proc",
        ":libc_runtime",
        ":libc_stdio",
        ":libc_str",
        ":libc_sysv",
        ":libc_thread",
        ":libc_tinymath",
        _COMPILER_RT_DEP,
        ":third_party_dlmalloc",
        ":third_party_gdtoa",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_dlopen",
    srcs = glob(
        ["libc/dlopen/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-Wframe-larger-than=4096",
    ],
    deps = [":libc_sysv"],
    visibility = ["//visibility:private"],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/elf/BUILD.mk
cosmo_cc_library(
    name = "libc_elf",
    dir = "libc/elf",
    textual_hdrs = [":libc_hdrs"],
    copts = [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_str",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/intrin/BUILD.mk
cosmo_cc_library(
    name = "libc_fmt",
    dir = "libc/fmt",
    textual_hdrs = [":libc_hdrs"],
    copts = [
        "-fno-jump-tables",
    ],
    per_file_copts = {
        #"libc/fmt/formatint64.c": ["-O3"],
        "libc/fmt/formatint64thousands.c": ["-O3"],
        #"libc/fmt/dosdatetimetounix.c": ["-O3"],
        #"libc/fmt/itoa64radix10.greg.c": ["-O3"],

        "libc/fmt/atoi.c": ["-Os"],
        #"libc/fmt/strtol.c": ["-Os"],
        #"libc/fmt/strtoul.c": ["-Os"],
        "libc/fmt/wcstol.c": ["-Os"],
        "libc/fmt/wcstoul.c": ["-Os"],
        #"libc/fmt/strtoimax.c": ["-Os"],
        #"libc/fmt/strtoumax.c": ["-Os"],
        #"libc/fmt/wcstoimax.c": ["-Os"],
        #"libc/fmt/wcstoumax.c": ["-Os"],
    },
    deps = [
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_nt_kernel32",
        ":libc_nt_realtime",
        ":libc_nt_synchronization",
        ":libc_nt_ws2_32",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
        ":libc_tinymath",
        ":third_party_compiler_rt",
    ],
    visibility = ["//visibility:private"],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/intrin/BUILD.mk
cosmo_cc_library(
    name = "libc_intrin",
    dir = "libc/intrin",
    copts = [
        # -x-no-pg
        "-ffreestanding",
        "-fno-sanitize=all",
        "-fno-stack-protector",
        "-Wframe-larger-than=4096",
        #"-Walloca-larger-than=4096",
    ],
    aarch64_safe_assembly_srcs = [
        "libc/intrin/getcontext.S",
        "libc/intrin/swapcontext.S",
        "libc/intrin/tailcontext.S",
        "libc/intrin/fenv.S",
        "libc/intrin/gcov.S",
        "libc/intrin/cosmo_futex_thunk.S",
        #"libc/intrin/typeinfo.S",
        "libc/intrin/kclocknames.S",
        "libc/intrin/kdos2errno.S",
        "libc/intrin/kerrnodocs.S",
        "libc/intrin/kipoptnames.S",
        "libc/intrin/kipv6optnames.S",
        "libc/intrin/kerrnonames.S",
        "libc/intrin/kfcntlcmds.S",
        "libc/intrin/kopenflags.S",
        "libc/intrin/krlimitnames.S",
        "libc/intrin/ksignalnames.S",
        "libc/intrin/ksockoptnames.S",
        "libc/intrin/ktcpoptnames.S",
        "libc/intrin/stackcall.S",
        "libc/intrin/kmonthname.S",
        "libc/intrin/kmonthnameshort.S",
        "libc/intrin/kweekdayname.S",
        "libc/intrin/kweekdaynameshort.S",
        #"libc/intrin/sched_yield.S",
        "libc/intrin/dsohandle.S",
        # "libc/intrin/getpagesize_freebsd.S",
    ] + glob(["libc/intrin/aarch64/*.S"]),
    per_file_copts = {
        "libc/intrin/mman.greg.c": ["-Os"],
        # TODO(zbarsky): kprint.c in the makefile?
        "libc/intrin/kprintf.greg.c": [
            "-Wframe-larger-than=128",
            #"-Walloca-larger-than=128",
        ],
        "libc/intrin/cursor.c": ["-ffunction-sections"],
        "libc/intrin/mmap.c": [
            "-ffunction-sections",
            "-mgeneral-regs-only",
        ],
        "libc/intrin/tree.c": ["-ffunction-sections"],
        "libc/intrin/memmove.c": [
            # TODO(zbarsky): what happens when this is disabled...
            #"-fno-toplevel-reorder",
            "-O2",
            "-finline",
            "-foptimize-sibling-calls",
            "-fpie",
        ],
        "libc/intrin/bzero.c": [
            "-O2",
            "-finline",
            "-foptimize-sibling-calls",
            "-fpie",
        ],
        "libc/intrin/strlen.c": [
            "-O2",
            "-finline",
            "-foptimize-sibling-calls",
        ],
        "libc/intrin/strchr.c": [
            "-O2",
            "-finline",
            "-foptimize-sibling-calls",
        ],
        "libc/intrin/memchr.c": [
            "-O2",
            "-finline",
            "-foptimize-sibling-calls",
        ],
        "libc/intrin/memrchr.c": [
            "-O2",
            "-finline",
            "-foptimize-sibling-calls",
        ],
        "libc/intrin/memcmp.c": [
            "-O2",
            "-finline",
            "-foptimize-sibling-calls",
            "-fpie",
        ],
        "libc/intrin/memset.c": [
            "-O2",
            "-finline",
            "-foptimize-sibling-calls",
        ],
        "libc/intrin/x86.c": [
            "-ffreestanding",
            "-fno-jump-tables",
            "-fpatchable-function-entry=0",
            "-Os",
        ],
        "libc/intrin/dll.c": ["-mgeneral-regs-only"],
        "libc/intrin/fds.c": ["-mgeneral-regs-only"],
        "libc/intrin/demangle.c": ["-mgeneral-regs-only"],
        "libc/intrin/windowsdurationtotimeval.c": ["-O2"],
        "libc/intrin/windowsdurationtotimespec.c": ["-O2"],
        "libc/intrin/timevaltowindowstime.c": ["-O2"],
        "libc/intrin/timespectowindowstime.c": ["-O2"],
        "libc/intrin/windowstimetotimeval.c": ["-O2"],
        "libc/intrin/windowstimetotimespec.c": ["-O2"],
    },
    x86_64_assembly_excludes = ["libc/intrin/aarch64/**"],
    deps = [
        ":libc_nexgen32e",
        ":libc_nt_kernel32",
        ":libc_nt_realtime",
        ":libc_nt_synchronization",
        ":libc_nt_ws2_32",
        ":libc_sysv",
        ":libc_sysv_calls",
    ],
    textual_hdrs = [":libc_hdrs"],
)

cc_stage2_library(
    name = "libc_irq",
    srcs = select({
        "@platforms//cpu:x86_64": glob(
            ["libc/irq/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
            exclude = COSMO_COMMON_EXCLUDES,
            allow_empty = True,
        ),
        "@platforms//cpu:aarch64": glob(
            ["libc/irq/**/*.%s" % ext for ext in ["c", "cc", "cpp"]],
            exclude = COSMO_COMMON_EXCLUDES,
            allow_empty = True,
        ),
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    deps = [
        ":libc_calls",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_proc",
        ":libc_runtime",
        ":libc_str",
        ":libc_sysv",
        ":third_party_dlmalloc",
        ":third_party_gdtoa",
    ],
    visibility = ["//visibility:private"],
)


# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/log/BUILD.mk
cosmo_cc_library(
    name = "libc_log",
    dir = "libc/log",
    textual_hdrs = [":libc_hdrs"],
    copts = [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
    ],
    per_file_copts = {
        "libc/log/checkfail.c": ["-mgeneral-regs-only"],
        "libc/log/watch.c": ["-ffreestanding"],
    },
    deps = [
        ":libc_calls",
        ":libc_elf",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt_kernel32",
        ":libc_nt_ntdll",
        ":libc_proc",
        ":libc_runtime",
        ":libc_stdio",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
        ":libc_thread",
        ":libc_tinymath",
        ":third_party_compiler_rt",
        ":third_party_dlmalloc",
        ":third_party_gdtoa",
        ":third_party_tz",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/mem/BUILD.mk
cosmo_cc_library(
    name = "libc_mem",
    dir = "libc/mem",
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
        "-fexceptions",
    ],
    per_file_copts = {
        #"libc/mem/asan.c": [
        #    "-O2",
        #    "-finline",
        #    "-finline-functions",
        #    "-x-no-pg",
        #    "-ffreestanding",
        #    "-fno-sanitize=all",
        #    "-fno-stack-protector",
        #    "-Wframe-larger-than=4096",
        #],
        #"libc/mem/asanthunk.c": ["-Os"] + NO_MAGIC_COPTS + ["-foptimize-sibling-calls"],
    },
    deps = [
        ":libc_calls",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_runtime",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
        ":third_party_dlmalloc",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/nexgen32e/BUILD.mk
cosmo_cc_library(
    name = "libc_nexgen32e",
    dir = "libc/nexgen32e",
    aarch64_safe_assembly_srcs = [
        "libc/nexgen32e/gc.S",
        "libc/nexgen32e/zip.S",
        "libc/nexgen32e/mcount.S",
        "libc/nexgen32e/ksha256.S",
        "libc/nexgen32e/ksha512.S",
        "libc/nexgen32e/kcp437.S",
        "libc/nexgen32e/ktensindex.S",
        "libc/nexgen32e/longjmp.S",
        "libc/nexgen32e/setjmp.S",
        #"libc/nexgen32e/missingno.S",
        "libc/nexgen32e/khalfcache3.S",
        "libc/nexgen32e/gclongjmp.S",
        "libc/nexgen32e/checkstackalign.S",
    ],
    textual_hdrs = [":libc_hdrs"],
    per_file_copts = {
        "libc/nexgen32e/envp.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/argc2.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/argv2.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/auxv2.c": NO_MAGIC_COPTS,
        #"libc/nexgen32e/cescapec.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/crc32init.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/environ2.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/kbase36.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/ktens.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/ktolower.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/ktoupper.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/runlevel.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/pid.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/program_executable_name.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/program_invocation_name2.c": NO_MAGIC_COPTS,
        "libc/nexgen32e/threaded.c": NO_MAGIC_COPTS,
    },
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/nt/BUILD.mk
cosmo_cc_library(
    name = "libc_nt_kernel32",
    dir = "libc/nt/kernel32",
    extra_srcs = glob(["ape/*.h"]) + [
        "libc/macros.h",
        "libc/nt/codegen.h",
        "libc/nt/sysv2nt.S",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/nt/BUILD.mk
cosmo_cc_library(
    name = "libc_nt_advapi32",
    dir = "libc/nt/advapi32",
    extra_srcs = glob(["ape/*.h"]) + [
        "libc/macros.h",
        "libc/nt/codegen.h",
    ],
    deps = [
        ":libc_nt_kernel32",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/nt/BUILD.mk
cosmo_cc_library(
    name = "libc_nt_ntdll",
    dir = "libc/nt/ntdll",
    extra_srcs = glob(["ape/*.h", "libc/nt/**/*.h"]) + [
        "libc/nt/ntdllimport.S",
        "libc/dce.h",
        "libc/macros.h",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/nt/BUILD.mk
cosmo_cc_library(
    name = "libc_nt_synchronization",
    dir = "libc/nt/API-MS-Win-Core-Synch-l1-2-0",
    extra_srcs = glob(["ape/*.h"]) + [
        "libc/macros.h",
        "libc/nt/codegen.h",
    ],
    deps = [
        ":libc_nt_kernel32",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/nt/BUILD.mk
cosmo_cc_library(
    name = "libc_nt_realtime",
    dir = "libc/nt/API-MS-Win-Core-Realtime-l1-1-1",
    extra_srcs = glob(["ape/*.h"]) + [
        "libc/macros.h",
        "libc/nt/codegen.h",
    ],
    deps = [
        ":libc_nt_kernel32",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/nt/BUILD.mk
cosmo_cc_library(
    name = "libc_nt_ws2_32",
    dir = "libc/nt/ws2_32",
    extra_srcs = glob(["ape/*.h"]) + [
        "libc/macros.h",
        "libc/nt/codegen.h",
    ],
    deps = [
        ":libc_nt_kernel32",
    ],
)

cc_stage2_library(
    name = "libc_nt",
    srcs = select({
        "@platforms//cpu:x86_64": glob(
            ["libc/nt/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
            exclude = COSMO_COMMON_EXCLUDES,
            allow_empty = True,
        ),
        "@platforms//cpu:aarch64": glob(
            ["libc/nt/**/*.%s" % ext for ext in ["c", "cc", "cpp"]],
            exclude = COSMO_COMMON_EXCLUDES,
            allow_empty = True,
        ),
        "//conditions:default": [],
    }),

    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/proc/BUILD.mk
cosmo_cc_library(
    name = "libc_proc",
    dir = "libc/proc",
    aarch64_safe_assembly_srcs = [
        "libc/proc/vfork.S",
    ],
    textual_hdrs = [":libc_hdrs"],
    copts = [
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_calls",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_nt_kernel32",
        ":libc_nt_ntdll",
        # LIBC_NT_PSAPI					\
        ":libc_runtime",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
        ":third_party_dlmalloc",
        ":third_party_gdtoa",
        ":third_party_nsync",
    ],
    visibility = ["//visibility:private"],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/runtime/BUILD.mk
cosmo_cc_library(
    name = "libc_runtime",
    dir = "libc/runtime",
    textual_hdrs = [":libc_hdrs"],
    copts = [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
    ],
    aarch64_safe_assembly_srcs = [
        "libc/runtime/init.S",
        #"libc/runtime/wipe.S",
        "libc/runtime/clone-linux.S",
        "libc/runtime/ftrace-hook.S",
        "libc/runtime/zipos.S",
        #"libc/runtime/switchstacks.S",
        "libc/runtime/sigsetjmp.S",
    ],
    per_file_copts = {
        "libc/runtime/cosmo2.c": ["-O0"],
        #"libc/runtime/qsort.c": ["-Og"],
        #"libc/runtime/mmap.c": ["-Os"] + select({
        #    "@platforms//cpu:aarch64": ["-mcmodel=large"],
        #    "@platforms//cpu:x86_64": [],
        #}),
        #"libc/runtime/munmap.c": ["-Os"],
        #"libc/runtime/memtrack.greg.c": ["-Os"],
        "libc/runtime/opensymboltable.greg.c": ["-Os"],
        "libc/runtime/enable_tls.c": select({
            # TODO(zbarsky): Added `-fno-pic`
            "@platforms//cpu:aarch64": ["-fno-pic", "-mcmodel=large"],
            "@platforms//cpu:x86_64": [],
        }),
    },
    deps = [
        ":libc_calls",
        ":libc_elf",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_nt_advapi32",
        ":libc_nt_kernel32",
        ":libc_nt_synchronization",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
        ":third_party_compiler_rt",
        ":third_party_nsync",
        ":third_party_puff",
        #":third_party_xed",
    ],
    visibility = ["//visibility:private"],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/sock/BUILD.mk
cosmo_cc_library(
    name = "libc_sock",
    dir = "libc/sock",
    aarch64_safe_assembly_srcs = [
        "libc/sock/sys_sendfile_xnu.S",
        "libc/sock/sys_sendfile_freebsd.S",
    ],
    textual_hdrs = [":libc_hdrs"],
    deps = [
        ":libc_calls",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt_advapi32",
        # LIBC_NT_IPHLPAPI			\
        ":libc_nt_kernel32",
        ":libc_nt_ntdll",
        ":libc_nt_realtime",
        ":libc_nt_ws2_32",
        ":libc_nt",
        ":libc_runtime",
        ":libc_stdio",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
        ":third_party_tz",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/stdio/BUILD.mk
cosmo_cc_library(
    name = "libc_stdio",
    dir = "libc/stdio",
    copts = [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
    ],
    per_file_copts = {
        "libc/stdio/fputc.c": ["-O3"],
        "libc/stdio/appendw.c": ["-Os"],
        "libc/stdio/dirstream.c": ["-ffunction-sections"],
        "libc/stdio/mt19937.c": ["-ffunction-sections"],
    },
    textual_hdrs = [":libc_hdrs"],
    deps = [
        ":libc_calls",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt_advapi32",
        ":libc_nt_kernel32",
        ":libc_proc",
        ":libc_runtime",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
        ":third_party_dlmalloc",
        ":third_party_gdtoa",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/str/BUILD.mk
cosmo_cc_library(
    name = "libc_str",
    dir = "libc/str",
    deps = [
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_sysv",
        ":third_party_compiler_rt",
    ],
    copts = [
		"-fno-sanitize=all",
		"-Wframe-larger-than=4096",
		#"-Walloca-larger-than=4096",
    ],
    per_file_copts = {
        "libc/str/wmemset.c": ["-O3"],
        "libc/str/memset16.c": ["-O3"],
        "libc/str/dosdatetimetounix.c": ["-O3"],

        "libc/str/getzipeocd.c": ["-Os"],
        "libc/str/getzipcdircomment.c": ["-Os"],
        "libc/str/getzipcdircommentsize.c": ["-Os"],
        "libc/str/getzipcdiroffset.c": ["-Os"],
        "libc/str/getzipcdirrecords.c": ["-Os"],
        "libc/str/getzipcfilecompressedsize.c": ["-Os"],
        "libc/str/getzipcfilemode.c": ["-Os"],
        "libc/str/getzipcfileoffset.c": ["-Os"],
        "libc/str/getzipcfileuncompressedsize.c": ["-Os"],
        "libc/str/getziplfilecompressedsize.c": ["-Os"],
        "libc/str/getziplfileuncompressedsize.c": ["-Os"],
        "libc/str/getzipcfiletimestamps.c": ["-Os"],

        #"libc/str/iswpunct.c": ["-fno-jump-tables"],
        "libc/str/iswupper.cc": ["-fno-jump-tables"],
        "libc/str/iswlower.cc": ["-fno-jump-tables"],
        "libc/str/iswseparator.cc": ["-fno-jump-tables"],

        "libc/str/bcmp.c": ["-O2"],
        #"libc/str/strcmp.c": ["-O2"],

        "libc/str/iso8601.c": ["-O3"],
        "libc/str/iso8601us.c": ["-O3"],
    },
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/sysv/BUILD.mk
cosmo_cc_library(
    name = "libc_sysv",
    dir = "libc/sysv",
    excludes = ["libc/sysv/calls/**"],
    per_file_copts = {
        "libc/sysv/errno.c": ["-ffreestanding", "-fno-stack-protector", "-fno-sanitize=all", "-mgeneral-regs-only"],
        "libc/sysv/sysret.c": ["-ffreestanding", "-fno-stack-protector", "-fno-sanitize=all", "-mgeneral-regs-only"],
        "libc/sysv/errfun2.c": ["-ffreestanding", "-fno-stack-protector", "-fno-sanitize=all", "-mgeneral-regs-only"],

        "libc/sysv/sysv.c": ["-ffreestanding", "-fno-stack-protector", "-fno-sanitize=all", "-mgeneral-regs-only"] + select({
            "@platforms//cpu:aarch64": [
                #"-ffixed-x0",
                #"-ffixed-x1",
                #"-ffixed-x2",
                #"-ffixed-x3",
                #"-ffixed-x4",
                #"-ffixed-x5",
                #"-ffixed-x8",
                #"-ffixed-x9",
                #"-ffixed-x16",
                "-fomit-frame-pointer",
                "-foptimize-sibling-calls",
                "-Os",
            ],
            "@platforms//cpu:x86_64": [],
        })
    },
    aarch64_safe_assembly_srcs = [
        "libc/sysv/syscon.S",
        "libc/sysv/hostos.S",
        "libc/sysv/syslib.S",
        "libc/sysv/syscount.S",
        "libc/sysv/syscall2.S",
        "libc/sysv/syscall3.S",
        "libc/sysv/syscall4.S",
        "libc/sysv/restorert.S",
    ] + glob([
        "libc/sysv/calls/*.S",
        "libc/sysv/consts/*.S",
        "libc/sysv/errfuns/*.S",
        "libc/sysv/dos2errno/*.S",
    ]),
    deps = [
        ":libc_nexgen32e",
    ],
    textual_hdrs = [":libc_hdrs"],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/sysv/BUILD.mk
cosmo_cc_library(
    name = "libc_sysv_calls",
    dir = "libc/sysv/calls",
    deps = [
        ":libc_sysv",
    ],
    textual_hdrs = [":libc_hdrs"],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/thread/BUILD.mk
cosmo_cc_library(
    name = "libc_thread",
    dir = "libc/thread",
    textual_hdrs = [":libc_hdrs"],
    copts = [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_calls",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt_kernel32",
        ":libc_nt_synchronization",
        ":libc_runtime",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
        ":libc_tinymath",
        ":third_party_dlmalloc",
        ":third_party_nsync",
        ":third_party_nsync_mem",
    ],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/libc/tinymath/BUILD.mk
cosmo_cc_library(
    name = "libc_tinymath",
    dir = "libc/tinymath",
    copts = [
        "-fmath-errno",
        "-fsigned-zeros",
        "-ftrapping-math",
        "-frounding-math",
        #"-fsignaling-nans",
        "-fno-reciprocal-math",
        "-fno-associative-math",
        "-fno-finite-math-only",
        "-fno-cx-limited-range",
        #"-ffp-int-builtin-inexact",
    ],
    per_file_copts = {
        "libc/tinymath/lround.c": ["-fno-builtin"],
        "libc/tinymath/lroundf.c": ["-fno-builtin"],
        "libc/tinymath/lroundl.c": ["-fno-builtin"],

        "libc/tinymath/expl.c": ["-ffunction-sections"],
        "libc/tinymath/loglq.c": ["-ffunction-sections"],
    },
    deps = [
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_sysv",
        ":third_party_compiler_rt",
    ],
)

cc_stage2_library(
    name = "libc_vga",
    srcs = select({
        "@platforms//cpu:x86_64": glob(
            ["libc/vga/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
            exclude = COSMO_COMMON_EXCLUDES,
            allow_empty = True,
        ),
        "@platforms//cpu:aarch64": [],
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_x",
    srcs = select({
        "@platforms//cpu:x86_64": glob(
            ["libc/x/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
            exclude = COSMO_COMMON_EXCLUDES,
            allow_empty = True,
        ),
        "@platforms//cpu:aarch64": [],
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_testlib",
    srcs = glob(
        ["libc/testlib/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [
        ":libc_hdrs",
    ] + glob(
        ["libc/testlib/**/*.txt"],
        allow_empty = True,
    ),
    copts = COSMO_COMMON_COPTS + [
        "-Wa,-Iexternal/+cosmo+cosmo_libc",
    ],
    deps = [
        ":libc_calls",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_log",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_proc",
        ":libc_runtime",
        ":libc_stdio",
        ":libc_str",
        ":libc_sysv",
        ":libc_thread",
        ":libc_tinymath",
        ":libc_x",
        _COMPILER_RT_DEP,
        ":third_party_dlmalloc",
        ":third_party_gdtoa",
    ],
    visibility = ["//visibility:private"],
)

genrule(
    name = "ape_lds_preprocessed",
    srcs = [
        "ape/ape.lds",
        ":libc_hdrs",
    ],
    outs = ["ape/ape.preprocessed.lds"],
    tools = ["@toolchains_llvm_bootstrapped//tools:clang"],
    cmd = "set -e; ROOT=$$(dirname \"$(location ape/ape.lds)\")/..; " +
          "$(location @toolchains_llvm_bootstrapped//tools:clang) -E -P -x c -nostdinc " +
          "-D_COSMO_SOURCE -D__LINKER__ -D__x86__ -D__x86_64__ " +
          "-iquote $$ROOT -isystem $$ROOT/libc/isystem " +
          "\"$(location ape/ape.lds)\" | grep -v '^typedef' > \"$@\"",
    visibility = ["//visibility:public"],
)

copy_file(
    name = "ape_linker_script",
    src = "ape/ape.preprocessed.lds",
    out = "ape.lds",
    allow_symlink = True,
    visibility = ["//visibility:public"],
)

genrule(
    name = "ape_aarch64_lds_preprocessed",
    srcs = [
        "ape/aarch64.lds",
        ":libc_hdrs",
    ],
    outs = ["ape/aarch64.preprocessed.lds"],
    tools = ["@toolchains_llvm_bootstrapped//tools:clang"],
    cmd = "set -e; ROOT=$$(dirname \"$(location ape/aarch64.lds)\")/..; " +
          "$(location @toolchains_llvm_bootstrapped//tools:clang) -E -P -x c -nostdinc " +
          "-D_COSMO_SOURCE -D__LINKER__ -D__aarch64__ " +
          "-iquote $$ROOT -isystem $$ROOT/libc/isystem " +
          "\"$(location ape/aarch64.lds)\" | grep -v '^typedef' > \"$@\"",
    visibility = ["//visibility:public"],
)

copy_file(
    name = "ape_aarch64_linker_script",
    src = "ape/aarch64.preprocessed.lds",
    out = "aarch64.lds",
    allow_symlink = True,
    visibility = ["//visibility:public"],
)

cc_stage2_library(
    name = "libc_ape",
    srcs = select({
        "@platforms//cpu:x86_64": glob(
            ["ape/*.S"],
            allow_empty = True,
        ),
        "@platforms//cpu:aarch64": [
            "ape/ape.S",
            "ape/start.S",
            "ape/launch.S",
            "ape/systemcall.S",
        ],
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "cosmo_crt_lib",
    srcs = ["libc/crt/crt.S"],
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_object(
    name = "cosmo_crt.object",
    srcs = [":cosmo_crt_lib"],
    copts = [
        "-target",
    ] + LLVM_TARGET_TRIPLE,
    out = "crt.o",
    visibility = ["//visibility:public"],
)

copy_file(
    name = "cosmo_crt1.object",
    src = ":cosmo_crt.object",
    out = "crt1.o",
    allow_symlink = True,
    visibility = ["//visibility:public"],
)

copy_file(
    name = "cosmo_rcrt1.object",
    src = ":cosmo_crt.object",
    out = "rcrt1.o",
    allow_symlink = True,
    visibility = ["//visibility:public"],
)

copy_file(
    name = "cosmo_Scrt1.object",
    src = ":cosmo_crt.object",
    out = "Scrt1.o",
    allow_symlink = True,
    visibility = ["//visibility:public"],
)

cc_stage2_library(
    name = "third_party_puff",
    srcs = ["third_party/puff/puff.c"],
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-ffreestanding",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_intrin",
        ":libc_nexgen32e",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_zlib_base",
    srcs = ZLIB_BASE_SRCS + select({
        "@platforms//cpu:aarch64": ["third_party/zlib/inffast_chunk.c"],
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = ZLIB_COMMON_COPTS,
    deps = ZLIB_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_zlib_deflate",
    srcs = [ZLIB_DEFLATE_SRC],
    textual_hdrs = [":libc_hdrs"],
    copts = ZLIB_COMMON_COPTS + select({
        "@platforms//cpu:aarch64": [
            "-O3",
            "-DBUILD_NEON",
            "-march=armv8-a+aes+crc",
        ],
        "//conditions:default": [],
    }),
    deps = ZLIB_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_zlib_adler32_simd",
    srcs = select({
        "@platforms//cpu:x86_64": [],
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = ZLIB_COMMON_COPTS,
    deps = ZLIB_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_zlib_crc_sse",
    srcs = select({
        "@platforms//cpu:x86_64": [
            "third_party/zlib/crc_folding.c",
            "third_party/zlib/crc32_simd_sse42.c",
        ],
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = ZLIB_COMMON_COPTS + [
        "-O3",
        "-msse4.2",
        "-mpclmul",
        "-UCRC32_SIMD_AVX512_PCLMUL",
        "-DCRC32_SIMD_SSE42_PCLMUL",
        "-DBUILD_SSE42",
    ],
    deps = ZLIB_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_zlib_crc_avx512",
    srcs = select({
        "@platforms//cpu:x86_64": ["third_party/zlib/crc32_simd_avx512.c"],
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = ZLIB_COMMON_COPTS + [
        "-O3",
        "-mpclmul",
        "-mavx512f",
        "-mvpclmulqdq",
        "-UCRC32_SIMD_SSE42_PCLMUL",
        "-DCRC32_SIMD_AVX512_PCLMUL",
        "-DBUILD_AVX512",
    ],
    deps = ZLIB_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_zlib_crc_neon",
    srcs = select({
        "@platforms//cpu:aarch64": ZLIB_AARCH64_SIMD_SRCS,
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = ZLIB_COMMON_COPTS + [
        "-O3",
        "-DBUILD_NEON",
        "-march=armv8-a+aes+crc",
    ],
    deps = ZLIB_DEPS,
    visibility = ["//visibility:private"],
)

# CRC SIMD objects rely on intrinsics clang does not currently provide, so we
# stick to the base and adler32 variants for the cosmo build.
cc_stage2_library(
    name = "third_party_zlib",
    srcs = [],
    deps = [
        ":third_party_zlib_base",
        ":third_party_zlib_deflate",
        ":third_party_puff",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_tz_base",
    srcs = TZ_BASE_SRCS,
    textual_hdrs = [":libc_hdrs"],
    copts = TZ_COMMON_COPTS,
    deps = TZ_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_tz_localtime",
    srcs = [TZ_LOCALTIME_SRC],
    textual_hdrs = [":libc_hdrs"],
    copts = TZ_COMMON_COPTS + [
        "-fdata-sections",
        "-ffunction-sections",
    ],
    deps = TZ_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_tz",
    srcs = [],
    deps = [
        ":third_party_tz_base",
        ":third_party_tz_localtime",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_musl_base",
    srcs = glob(
        ["third_party/musl/*.c"],
        exclude = MUSL_PORTCOSMO_SRCS,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = MUSL_COMMON_COPTS,
    deps = MUSL_DEPS,
    visibility = ["//visibility:private"],
)

# Upstream uses -fportcosmo (GCC-only) for these sources; clang rejects it so
# we rely on the shared MUSL_COMMON_COPTS instead.
cc_stage2_library(
    name = "third_party_musl_portcosmo",
    srcs = MUSL_PORTCOSMO_SRCS,
    textual_hdrs = [":libc_hdrs"],
    copts = MUSL_COMMON_COPTS,
    deps = MUSL_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_musl",
    srcs = [],
    deps = [
        ":third_party_musl_base",
        ":third_party_musl_portcosmo",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "cosmo_locale_stubs",
    srcs = ["@toolchains_llvm_bootstrapped//runtimes/cosmo:locale_stubs.c"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

LIBUNWIND_COPTS = COSMO_COMMON_COPTS + [
    "-fexceptions",
    "-ffunction-sections",
    "-fdata-sections",
    "-D_LIBUNWIND_USE_DLADDR=0",
    "-D_LIBUNWIND_IS_BAREMETAL=1",
]

cc_stage2_library(
    name = "third_party_nsync",
    srcs = glob(
        ["third_party/nsync/**/*.%s" % ext for ext in ["c", "S"]],
        exclude = [
            "third_party/nsync/mem/**",
        ],
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-ffreestanding",
        "-fdata-sections",
        "-ffunction-sections",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_calls",
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_str",
        ":libc_sysv",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_nsync_mem",
    srcs = glob(
        ["third_party/nsync/mem/**/*.%s" % ext for ext in ["c"]],
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-ffreestanding",
        "-fdata-sections",
        "-ffunction-sections",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_calls",
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_mem",
        ":libc_sysv",
        ":third_party_nsync",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_dlmalloc",
    srcs = glob(
        ["third_party/dlmalloc/**/*.%s" % ext for ext in ["c"]],
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-ffreestanding",
        "-fdata-sections",
        "-ffunction-sections",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_calls",
        ":libc_intrin",
        ":libc_fmt",
        ":libc_nexgen32e",
        ":libc_str",
        ":libc_sysv",
        ":third_party_nsync",
        _COMPILER_RT_DEP,
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_gdtoa",
    srcs = glob(
        ["third_party/gdtoa/**/*.%s" % ext for ext in ["c"]],
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    deps = [
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_runtime",
        ":libc_str",
        ":libc_sysv",
        ":libc_tinymath",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_libunwind",
    srcs = glob(
        ["third_party/libunwind/**/*.%s" % ext for ext in ["c", "cc", "S"]],
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = LIBUNWIND_COPTS + [
        "-Ithird_party/libunwind/include",
    ],
    deps = [
        ":libc_calls",
        ":libc_intrin",
        ":libc_stdio",
        ":libc_mem",
        ":libc_thread",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_libcxxabi",
    srcs = glob(
        ["third_party/libcxxabi/**/*.%s" % ext for ext in ["cc"]],
        exclude = ["third_party/libcxxabi/test/**"],
        allow_empty = True,
    ),
    textual_hdrs = glob(
        ["third_party/libcxxabi/**/*.%s" % ext for ext in ["h", "inc"]],
        exclude = ["third_party/libcxxabi/test/**"],
        allow_empty = True,
    ),
    copts = COSMO_COMMON_COPTS + [
        "-ffunction-sections",
        "-fdata-sections",
        "-fexceptions",
        "-frtti",
        "-fno-sanitize=all",
        "-DLIBCXX_BUILDING_LIBCXXABI",
        "-D_LIBCXXABI_BUILDING_LIBRARY",
        "-D_LIBCPP_BUILDING_LIBRARY",
        "-Ithird_party/libcxxabi",
        "-Ithird_party/libcxx",
    ],
    deps = [
        ":libc_calls",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_runtime",
        ":libc_stdio",
        ":libc_str",
        ":libc_thread",
        ":third_party_libunwind",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "third_party_libcxx",
    srcs = glob(
        ["third_party/libcxx/**/*.%s" % ext for ext in ["cpp", "cc", "c"]],
        exclude = ["third_party/libcxx/test/**"],
        allow_empty = True,
    ),
    textual_hdrs = glob(
        ["third_party/libcxx/**/*.%s" % ext for ext in ["h", "inc"]],
        exclude = ["third_party/libcxx/test/**"],
        allow_empty = True,
    ),
    copts = COSMO_COMMON_COPTS + [
        "-nostdinc++",
        "-ffunction-sections",
        "-fdata-sections",
        "-fexceptions",
        "-frtti",
        "-Wno-alloc-size-larger-than",
        "-DLIBCXX_BUILDING_LIBCXXABI",
        "-D_LIBCPP_BUILDING_LIBRARY",
        "-Ithird_party/libcxx",
        "-Ithird_party/libcxxabi",
        "-Ithird_party/libunwind/include",
    ],
    deps = [
        ":libc_calls",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_runtime",
        ":libc_stdio",
        ":libc_sock",
        ":libc_str",
        ":libc_sysv",
        ":libc_thread",
        ":libc_tinymath",
        ":third_party_gdtoa",
        ":third_party_libcxxabi",
        ":third_party_libunwind",
        _COMPILER_RT_DEP,
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "cosmo_libc",
    deps = [
        ":libc_ape",
        ":libc_calls",
        ":libc_crt",
        ":libc_dlopen",
        ":libc_elf",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_irq",
        ":libc_log",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_proc",
        ":libc_runtime",
        ":libc_sock",
        ":libc_stdio",
        ":libc_str",
        ":libc_sysv",
        ":libc_thread",
        ":libc_tinymath",
        ":libc_vga",
        ":libc_x",
        ":libc_testlib",
        ":cosmo_locale_stubs",
    ],
    visibility = ["//visibility:public"],
)

cc_stage2_static_library(
    name = "cosmopolitan",
    deps = [
        ":cosmo_libc",
        #":third_party_dlmalloc",
        #":third_party_gdtoa",
        #":third_party_puff",
        #":third_party_zlib",
        #":third_party_tz",
        #":third_party_nsync",
        #":third_party_nsync_mem",
        #":third_party_libunwind",
        #":third_party_libcxxabi",
        #":third_party_libcxx",
    ],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "cosmo_headers",
    hdrs = [":libc_hdrs"],
    visibility = ["//visibility:public"],
)

# https://github.com/jart/cosmopolitan/blob/4.0.2/third_party/compiler_rt/BUILD.mk
cosmo_cc_library(
    name = "third_party_compiler_rt",
    dir = "third_party/compiler_rt",
    copts = [
        "-fno-strict-aliasing",
        "-fno-strict-overflow",
    ],
    local_defines = [
        "CRT_HAS_128BIT",
    ],
    textual_hdrs = glob(["third_party/compiler_rt/**/*.inc"]) + [":libc_hdrs"],
    visibility = ["//visibility:public"],
)

cc_stage2_static_library(
    name = "clang_rt.builtins.static",
    deps = [":third_party_compiler_rt"],
    visibility = ["//visibility:public"],
)

copy_file(
    name = "cosmo_libc_archive",
    src = ":cosmopolitan",
    out = "libc.a",
    allow_symlink = True,
    visibility = ["//visibility:public"],
)

COSMO_COMPANION_LIBS = [
    "m",
    "pthread",
    "rt",
    "util",
    "resolv",
    "dl",
    "xnet",
    "crypt",
]

[
    copy_file(
        name = "cosmo_lib{}".format(lib),
        src = ":cosmopolitan",
        out = "lib{}.a".format(lib),
        allow_symlink = True,
        visibility = ["//visibility:public"],
    )
    for lib in COSMO_COMPANION_LIBS
]

cc_static_lib_file(
    name = "cosmo_libcxx",
    lib = ":third_party_libcxx",
    out = "libc++.a",
)

cc_static_lib_file(
    name = "cosmo_libcxxabi",
    lib = ":third_party_libcxxabi",
    out = "libc++abi.a",
)

cc_static_lib_file(
    name = "cosmo_libunwind",
    lib = ":third_party_libunwind",
    out = "libunwind.a",
)

copy_to_directory(
    name = "cosmo_library_search_directory",
    srcs = [
        ":cosmopolitan",
        ":cosmo_libc_archive",
    ] + [
        ":cosmo_lib{}".format(lib) for lib in COSMO_COMPANION_LIBS
    ] + [
        ":cosmo_libcxx",
        ":cosmo_libcxxabi",
        ":cosmo_libunwind",
    ],
    root_paths = ["."],
    visibility = ["//visibility:public"],
)

copy_to_directory(
    name = "cosmo_headers_include_search_directory",
    srcs = [":libc_hdrs"],
    root_paths = ["."],
    include_external_repositories = ["**"],
    visibility = ["//visibility:public"],
)

copy_to_directory(
    name = "cosmo_tzdata_directory",
    srcs = [":tzdata"],
    root_paths = ["usr"],
    include_external_repositories = ["**"],
    visibility = ["//visibility:public"],
)
