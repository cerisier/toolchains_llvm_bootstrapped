

load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@bazel_skylib//lib:selects.bzl", "selects")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:cc_runtime_library.bzl", "cc_runtime_stage0_library")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:cc_runtime_static_library.bzl", "cc_runtime_stage0_static_library")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:cc_runtime_shared_library.bzl", "cc_runtime_stage1_shared_library")

selects.config_setting_group(
    name = "windows_static",
    match_all = [
        "@platforms//os:windows",
        "@toolchains_llvm_bootstrapped//runtimes:linkmode_static",
    ],
)

cc_library(
    name = "libunwind",
    copts = [
        "-Wa,--noexecstack",
    ] + select({
        ":windows_static": [
            "-fvisibility=hidden",
            "-fvisibility-global-new-delete=force-hidden",
        ],
        "//conditions:default": [],
    }) + [
        "-Wno-bitwise-conditional-parentheses",
        "-Wno-visibility",
        "-Wno-incompatible-pointer-types",
        "-Wno-dll-attribute-on-redeclaration",
    ] + select({
        "@platforms//os:windows": [
            "-Wno-macro-redefined", # TODO(zbarsky): Is this masking a real issue?
            "-Wno-missing-declarations",
            "-Wno-pragma-pack",
            "-Wno-typedef-redefinition",
            "-Wno-unused-value",
        ],
        "//conditions:default": [],
    }) + [
        "-funwind-tables",
    ],
    conlyopts = [
        "-std=c99",
        "-fexceptions",
    ],
    cxxopts = [
        "-fno-exceptions",
        "-fno-rtti",
    ],
    linkopts = [
        "--unwindlib=none",
    ],
    local_defines = [
        # This is intentionally always defined because the macro definition means, should it only
        # build for the target specified by compiler defines. Since we pass -target the compiler
        # defines will be correct.
        "_LIBUNWIND_IS_NATIVE_ONLY",
        "_NDEBUG",
        # "_LIBUNWIND_HAS_NO_THREADS", # ANY_NON_SINGLE_THREADED
        # "_DCOMPILER_RT_ARMHF_TARGET", # ARM
        "_LIBUNWIND_USE_FRAME_HEADER_CACHE",
    ] + select({
        ":windows_static": [
            "_LIBUNWIND_HIDE_SYMBOLS",
        ],
        "//conditions:default": [],
    }),
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
        "@platforms//os:windows": [],
        "@platforms//os:linux": [
            # TODO(cerisier): Provide only a subset of linux UAPI headers for musl.
            # https://github.com/cerisier/toolchains_llvm_bootstrapped/issues/146
            "@kernel_headers//:kernel_headers",
        ],
    }) + select({
        "@toolchains_llvm_bootstrapped//platforms/config:musl": [
            "@musl_libc//:musl_libc_headers",
        ],
        "@toolchains_llvm_bootstrapped//platforms/config:gnu": [
            "@glibc//:gnu_libc_headers",
        ],
        "@toolchains_llvm_bootstrapped//platforms/config:abi_gnu": [
            "@mingw//:mingw_headers",
        ],
        "@toolchains_llvm_bootstrapped//platforms/config:abi_msvc": [
            # TODO: check if it is releavant to wire SDK headers and user-provided MSVC runtime headers here
        ],
        "@platforms//os:macos": [],
    }),
    visibility = ["//visibility:public"],
)

cc_runtime_stage0_static_library(
    name = "libunwind.static",
    deps = [
        ":libunwind",
    ],
    visibility = ["//visibility:public"],
)

# Stage1 because libunwind.so must have CRTs
cc_runtime_stage1_shared_library(
    name = "libunwind.shared",
    deps = [
        ":libunwind",
    ],
    user_link_flags = [
        "-Wl,-soname,libunwind.so.1",
    ],
    shared_lib_name = "libunwind.so.1",
    visibility = ["//visibility:public"],
)
