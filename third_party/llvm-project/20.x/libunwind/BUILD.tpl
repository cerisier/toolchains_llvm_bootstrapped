

load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_static_library.bzl", "cc_stage2_static_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_shared_library.bzl", "cc_stage2_shared_library")

cc_stage2_library(
    name = "libunwind",
    copts = [
        "-Wa,--noexecstack",
        "-fvisibility=hidden",
        "-fvisibility-inlines-hidden",
        "-fvisibility-global-new-delete=force-hidden",
        "-Wno-bitwise-conditional-parentheses",
        "-Wno-visibility",
        "-Wno-incompatible-pointer-types",
        "-Wno-dll-attribute-on-redeclaration",
    ],
    conlyopts = [
        "-std=c99",
        "-fexceptions",
    ],
    cxxopts = [
        "-fno-exceptions",
        "-fno-rtti",
    ],
    features = ["-default_compile_flags"],
    local_defines = [
        "_LIBUNWIND_DISABLE_VISIBILITY_ANNOTATIONS", # only for static libunwind

        # This is intentionally always defined because the macro definition means, should it only
        # build for the target specified by compiler defines. Since we pass -target the compiler
        # defines will be correct.
        "_LIBUNWIND_IS_NATIVE_ONLY",
        "_DEBUG",
        # "_LIBUNWIND_HAS_NO_THREADS", # ANY_NON_SINGLE_THREADED
        # "_DCOMPILER_RT_ARMHF_TARGET", # ARM
    ],
    hdrs = glob([
        "include/**",
        "src/*.h",
        "src/*.hpp",
    ]),
    includes = [
        "include",
        "src",
    ],
    # textual_hdrs = glob([
    #     "src/*.h"
    # ]),
    srcs = [
        "src/libunwind.cpp",
        "src/Unwind-EHABI.cpp",
        "src/Unwind-seh.cpp",

        "src/UnwindLevel1.c",
        "src/UnwindLevel1-gcc-ext.c",
        "src/Unwind-sjlj.c",
        "src/Unwind-wasm.c",

        "src/UnwindRegistersRestore.S",
        "src/UnwindRegistersSave.S",

        # "src/Unwind_AIXExtras.cpp",
    ],
    implementation_deps = select({
        "@platforms//os:macos": [],
        "@platforms//os:linux": [
            "@kernel_headers//:kernel_headers",
        ],
    }) + select({
        "@toolchains_llvm_bootstrapped//constraints/libc:musl": [
            "@musl_libc//:musl_libc_headers",
        ],
        "//conditions:default": [
            "@glibc//:gnu_libc_headers",
        ],
    }),
    visibility = ["//visibility:public"],
)

cc_stage2_static_library(
    name = "libunwind.static",
    deps = [
        ":libunwind",
    ],
    visibility = ["//visibility:public"],
)

cc_stage2_shared_library(
    name = "libunwind.shared",
    deps = [
        ":libunwind",
    ],
    shared_lib_name = "libunwind.so.1.0",
    visibility = ["//visibility:public"],
)
