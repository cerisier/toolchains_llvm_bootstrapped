load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

MUSL_SUPPORTED_ARCHS = ["x86_64", "aarch64"]

filegroup(
    name = "compile_srcs",
    srcs = glob([
        "src/**/*.c",
        "src/**/*.S",
        "src/**/*.s",
    ]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "compile_hdrs",
    srcs = glob([
        "src/**/*.h",
    ]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "internal_textual_hdrs",
    srcs = glob([
        "src/ldso/**",
    ]),
    visibility = ["//visibility:public"],
)

## INTERNAL HEADERS

genrule(
    name = "version_h",
    srcs = [
        "VERSION",
        "tools/version.sh",
    ],
    outs = ["obj/src/internal/version.h"],
    cmd = """
        printf '#define VERSION \"%s\"\\n' "$$(cat $(location VERSION))" > $@
    """,
)

[
    cc_library(
        name = "musl_internal_headers_{arch}".format(arch = arch),
        includes = [
            "arch/{arch}".format(arch = arch),
            "arch/generic",
            "src/include",
            "src/internal",
            "obj/src/internal", # version_h
            "ldso",
            "include",
        ],
        hdrs = glob([
            "arch/{arch}/**".format(arch = arch),
            "arch/generic/**",
            "src/include/**",
            "src/internal/**",
            "ldso/**",
            "include/**",
        ]) + [":version_h"],
        textual_hdrs = glob([
            "ldso/**",
        ]),
        visibility = ["//visibility:public"],
    ) for arch in MUSL_SUPPORTED_ARCHS
]

alias(
    name = "musl_internal_headers",
    actual = select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": ":musl_internal_headers_x86_64",
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": ":musl_internal_headers_aarch64",
    }),
    visibility = ["//visibility:public"],
)

## PUBLIC HEADERS

filegroup(
    name = "headers_generic",
    srcs = glob([
        "arch/generic/bits/*.h",
        "include/*.h",
        "include/*/*.h",
    ]),
    visibility = ["//visibility:public"],
)

[
    filegroup(
        name = "headers_arch_specific_{arch}".format(arch = arch),
        srcs = glob([
            "arch/{arch}/bits/*.h".format(arch = arch),
        ]),
        visibility = ["//visibility:public"],
    ) for arch in MUSL_SUPPORTED_ARCHS
]


[
    genrule(
        name = "alltypes_h_{arch}".format(arch = arch),
        srcs = [
            "arch/{arch}/bits/alltypes.h.in".format(arch = arch),
            "include/alltypes.h.in",
            "tools/mkalltypes.sed",
        ],
        outs = ["obj/{arch}/include/bits/alltypes.h".format(arch = arch)],
        cmd = """
            sed -f $(location tools/mkalltypes.sed) $(location arch/{arch}/bits/alltypes.h.in) $(location include/alltypes.h.in) > $@
        """.format(arch = arch),
        visibility = ["//visibility:public"],
    ) for arch in MUSL_SUPPORTED_ARCHS
]

[
    genrule(
        name = "syscall_h_{arch}".format(arch = arch),
        srcs = [
            "arch/{arch}/bits/syscall.h.in".format(arch = arch),
        ],
        outs = ["obj/{arch}/include/bits/syscall.h".format(arch = arch)],
        cmd = """
            cp $(location arch/{arch}/bits/syscall.h.in) $@ && \
            sed -n -e 's/__NR_/SYS_/p' $(location arch/{arch}/bits/syscall.h.in) >> $@
        """.format(arch = arch),
        visibility = ["//visibility:public"],
    ) for arch in MUSL_SUPPORTED_ARCHS
]


[
    filegroup(
        name = "headers_{arch}".format(arch = arch),
        srcs = [
            ":headers_generic",
            ":headers_arch_specific_{arch}".format(arch = arch),
            ":alltypes_h_{arch}".format(arch = arch),
            ":syscall_h_{arch}".format(arch = arch),
        ],
        visibility = ["//visibility:public"],
    ) for arch in MUSL_SUPPORTED_ARCHS
]

[
    copy_to_directory(
        name = "headers_{arch}_include_directory".format(arch = arch),
        srcs = [
            ":headers_{arch}".format(arch = arch),
        ],
        root_paths = [
            "include",
            "arch/generic",
            "arch/{arch}".format(arch = arch),
            "obj/{arch}/include".format(arch = arch),
            "obj/src/internal",
        ],
        allow_overwrites = True,
        out = "generated/{arch}/includes".format(arch = arch),
        visibility = ["//visibility:public"],
    ) for arch in MUSL_SUPPORTED_ARCHS
]

[
    cc_library(
        name = "musl_libc_headers_{arch}".format(arch = arch),
        includes = [
            "obj/src/internal",
            "obj/{arch}/include".format(arch = arch),
            "arch/{arch}".format(arch = arch),
            "arch/generic",
            "include",
        ],
        hdrs = [":headers_{arch}".format(arch = arch)],
        visibility = ["//visibility:public"],
    ) for arch in MUSL_SUPPORTED_ARCHS
]

alias(
    name = "musl_libc_headers",
    actual = select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": ":musl_libc_headers_x86_64",
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": ":musl_libc_headers_aarch64",
    }),
    visibility = ["//visibility:public"],
)

alias(
    name = "musl_libc_headers_include_directory",
    actual = select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": ":headers_x86_64_include_directory",
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": ":headers_aarch64_include_directory",
    }),
    visibility = ["//visibility:public"],
)

exports_files([
    "crt/crt1.c",
    "crt/rcrt1.c",
    "crt/Scrt1.c",
])
