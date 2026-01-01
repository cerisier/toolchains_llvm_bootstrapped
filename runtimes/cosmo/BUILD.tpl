load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_object.bzl", "cc_stage2_object")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_static_library.bzl", "cc_stage2_static_library")
load("@toolchains_llvm_bootstrapped//toolchain/args:llvm_target_triple.bzl", "LLVM_TARGET_TRIPLE")

package(default_visibility = ["//visibility:public"])

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
    #"third_party/musl",
    "third_party/nsync",
    #"third_party/openmp",
    "third_party/puff",
    #"third_party/regex",
    "third_party/tz",
    "third_party/xed",
    "third_party/zlib",
    "tool/args",
]

# All C/C++/asm sources that make up cosmopolitan.a.
filegroup(
    name = "libc_intrin_aarch64_srcs",
    srcs = glob(
        ["libc/intrin/aarch64/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        allow_empty = True,
    ),
)

filegroup(
    name = "cosmoaudio_srcs",
    srcs = glob(
        ["dsp/audio/cosmoaudio/**/*.%s" % ext for ext in ["c", "cc", "cpp"]],
        allow_empty = True,
    ),
)

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

COSMO_COMMON_COPTS = [
    "-fno-ident",
    "-fstrict-aliasing",
    "-fstrict-overflow",
    "-fno-semantic-interposition",
    "-fno-omit-frame-pointer",
    "-frecord-gcc-switches",
    "-D_COSMO_SOURCE",
    "-DMODE=\\\"\\\"",
    "-D_Float32=float",
    "-D_Float64=double",
    "-D__float80=long\\ double",
    "-D_Float128=long\\ double",
    "-Wno-unknown-pragmas",
    "-nostdinc",
    "-iquote.",
    "-isystem",
    "libc/isystem",
    "-Wall",
    "-include",
    "libc/integral/normalize.inc",
    "-include",
    "libc/stdalign.h",
] + select({
    "@platforms//cpu:x86_64": [
        "-mno-red-zone",
        "-mno-tls-direct-seg-refs",
        "-msse",
        "-msse2",
        "-D__SSE__=1",
        "-D__SSE2__=1",
    ],
    "@platforms//cpu:aarch64": [
        "-ffixed-x18",
        "-ffixed-x28",
        "-fsigned-char",
    ],
    "//conditions:default": [],
})

COSMO_AUDIO_COPTS = COSMO_COMMON_COPTS + [
    "-include",
    "libc/isystem/windowsesque.h",
    "-include",
    "libc/isystem/sys/time.h",
]

COSMO_COMMON_EXCLUDES = [
    "libc/crt/**",
    "libc/intrin/aarch64/**",
    "dsp/audio/cosmoaudio/**",
    "ctl/new.cc",
    "examples/**",
    "test/**",
    "**/test/**",
    "build/**",
]

_COMPILER_RT_DEP = ":clang_rt.builtins.static"

LIBC_STR_O3_SRCS = [
    "libc/str/wmemset.c",
    "libc/str/memset16.c",
    "libc/str/dosdatetimetounix.c",
    "libc/str/iso8601.c",
    "libc/str/iso8601us.c",
]

LIBC_STR_O2_SRCS = [
    "libc/str/bcmp.c",
]

LIBC_STR_OS_SRCS = [
    "libc/str/getzipeocd.c",
    "libc/str/getzipcdircomment.c",
    "libc/str/getzipcdircommentsize.c",
    "libc/str/getzipcdiroffset.c",
    "libc/str/getzipcdirrecords.c",
    "libc/str/getzipcfilecompressedsize.c",
    "libc/str/getzipcfilemode.c",
    "libc/str/getzipcfileoffset.c",
    "libc/str/getzipcfileuncompressedsize.c",
    "libc/str/getziplfilecompressedsize.c",
    "libc/str/getziplfileuncompressedsize.c",
    "libc/str/getzipcfiletimestamps.c",
]

LIBC_STR_NO_JUMP_SRCS = [
    "libc/str/iswupper.cc",
    "libc/str/iswlower.cc",
    "libc/str/iswseparator.cc",
]

LIBC_STR_SPECIAL_SRCS = LIBC_STR_O3_SRCS + LIBC_STR_O2_SRCS + LIBC_STR_OS_SRCS + LIBC_STR_NO_JUMP_SRCS

LIBC_STR_COMMON_COPTS = COSMO_COMMON_COPTS

_LIBC_STR_DEPS = [
    ":libc_intrin",
    ":libc_nexgen32e",
    ":libc_sysv",
    _COMPILER_RT_DEP,
]

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

cc_stage2_library(
    name = "libc_calls",
    srcs = glob(
        ["libc/calls/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_fmt",
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
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
        ":libc_sysv_calls",
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
    deps = [":libc_sysv_calls"],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_elf",
    srcs = glob(
        ["libc/elf/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_str",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_fmt",
    srcs = glob(
        ["libc/fmt/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-fno-jump-tables",
    ],
    deps = [
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_str",
        ":libc_sysv",
        ":libc_tinymath",
        _COMPILER_RT_DEP,
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_intrin",
    srcs = glob(
        ["libc/intrin/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ) + select({
        "@platforms//cpu:aarch64": [":libc_intrin_aarch64_srcs"],
        "//conditions:default": [],
    }),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-ffreestanding",
        "-fno-sanitize=all",
        "-fno-stack-protector",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_sysv",
        ":libc_sysv_calls",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_irq",
    srcs = glob(
        ["libc/irq/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
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
        ":libc_sysv_calls",
        ":third_party_dlmalloc",
        ":third_party_gdtoa",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_log",
    srcs = glob(
        ["libc/log/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_mem",
    srcs = glob(
        ["libc/mem/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
        "-fexceptions",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_nexgen32e",
    srcs = glob(
        ["libc/nexgen32e/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_nt",
    srcs = glob(
        ["libc/nt/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_proc",
    srcs = glob(
        ["libc/proc/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    deps = [
        ":libc_calls",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt",
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

cc_stage2_library(
    name = "libc_runtime",
    srcs = glob(
        ["libc/runtime/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_calls",
        ":libc_elf",
        ":libc_fmt",
        ":libc_intrin",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_str",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_sock",
    srcs = glob(
        ["libc/sock/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_stdio",
    srcs = glob(
        ["libc/stdio/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-Wframe-larger-than=4096",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_str_base",
    srcs = glob(
        ["libc/str/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES + LIBC_STR_SPECIAL_SRCS,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = LIBC_STR_COMMON_COPTS,
    deps = _LIBC_STR_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_str_o3",
    srcs = LIBC_STR_O3_SRCS,
    textual_hdrs = [":libc_hdrs"],
    copts = LIBC_STR_COMMON_COPTS + ["-O3"],
    deps = _LIBC_STR_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_str_o2",
    srcs = LIBC_STR_O2_SRCS,
    textual_hdrs = [":libc_hdrs"],
    copts = LIBC_STR_COMMON_COPTS + ["-O2"],
    deps = _LIBC_STR_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_str_os",
    srcs = LIBC_STR_OS_SRCS,
    textual_hdrs = [":libc_hdrs"],
    copts = LIBC_STR_COMMON_COPTS + ["-Os"],
    deps = _LIBC_STR_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_str_nojump",
    srcs = LIBC_STR_NO_JUMP_SRCS,
    textual_hdrs = [":libc_hdrs"],
    copts = LIBC_STR_COMMON_COPTS + ["-fno-jump-tables"],
    deps = _LIBC_STR_DEPS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_str",
    srcs = [],
    textual_hdrs = [":libc_hdrs"],
    deps = [
        ":libc_str_base",
        ":libc_str_o3",
        ":libc_str_o2",
        ":libc_str_os",
        ":libc_str_nojump",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_sysv",
    srcs = glob(
        ["libc/sysv/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_sysv_calls",
    srcs = glob(
        ["libc/sysv/calls/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    deps = [":libc_sysv"],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_thread",
    srcs = glob(
        ["libc/thread/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS + [
        "-fno-sanitize=all",
        "-Wframe-larger-than=4096",
    ],
    deps = [
        ":libc_calls",
        ":libc_intrin",
        ":libc_mem",
        ":libc_nexgen32e",
        ":libc_nt",
        ":libc_runtime",
        ":libc_str",
        ":libc_sysv",
        ":libc_sysv_calls",
        ":libc_tinymath",
        ":third_party_dlmalloc",
        ":third_party_nsync",
        ":third_party_nsync_mem",
    ],
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_tinymath",
    srcs = glob(
        ["libc/tinymath/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_vga",
    srcs = glob(
        ["libc/vga/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
    textual_hdrs = [":libc_hdrs"],
    copts = COSMO_COMMON_COPTS,
    visibility = ["//visibility:private"],
)

cc_stage2_library(
    name = "libc_x",
    srcs = glob(
        ["libc/x/**/*.%s" % ext for ext in ["c", "cc", "cpp", "s", "S"]],
        exclude = COSMO_COMMON_EXCLUDES,
        allow_empty = True,
    ),
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
        ":libc_sysv_calls",
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
    srcs = glob(
        ["ape/*.S"],
        allow_empty = True,
    ),
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
        ":libc_sysv_calls",
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
        ":libc_sysv_calls",
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
    ],
    visibility = ["//visibility:public"],
)

cc_stage2_static_library(
    name = "cosmopolitan",
    deps = [
        ":cosmo_libc",
        ":third_party_dlmalloc",
        ":third_party_gdtoa",
        ":third_party_puff",
        ":third_party_zlib",
        ":third_party_tz",
        ":third_party_musl",
        ":third_party_nsync",
        ":third_party_nsync_mem",
        ":third_party_libunwind",
        ":third_party_libcxxabi",
        ":third_party_libcxx",
    ],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "cosmo_headers",
    hdrs = [":libc_hdrs"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "compiler_rt_srcs",
    srcs = glob(
        ["third_party/compiler_rt/**/*.%s" % ext for ext in ["c", "S"]],
        exclude = [
            "third_party/compiler_rt/mingw_*",
        ],
        allow_empty = True,
    ),
)

cc_stage2_library(
    name = "clang_rt.builtins.static",
    srcs = [":compiler_rt_srcs"],
    copts = COSMO_COMMON_COPTS + [
        "-iquote",
        "third_party/compiler_rt",
    ],
    textual_hdrs = glob(
        ["third_party/compiler_rt/**/*.%s" % ext for ext in ["h", "inc"]],
        allow_empty = True,
    ),
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

copy_to_directory(
    name = "cosmo_library_search_directory",
    srcs = [
        ":cosmopolitan",
        ":cosmo_libc_archive",
    ] + [
        ":cosmo_lib{}".format(lib) for lib in COSMO_COMPANION_LIBS
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
