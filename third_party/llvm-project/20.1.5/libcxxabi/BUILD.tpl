load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_static_library.bzl", "cc_stage2_static_library")
load("@aspect_bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")

filegroup(
    name = "libcxxabi_headers_files",
    srcs = [
        "include/__cxxabi_config.h",
        "include/cxxabi.h",
    ],
    visibility = ["//visibility:public"],
)

copy_to_directory(
    name = "libcxxabi_headers_include_search_directory",
    srcs = [
        ":libcxxabi_headers_files",
    ],
    root_paths = [
        "include",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "textual_hdrs",
    srcs = glob([
        "src/**/*.h",
        "src/**/*.def",
    ]),
    visibility = ["//visibility:public"],
)

cc_library(
    name = "headers",
    includes = [
        "src",
        "include",
    ],
    hdrs = glob([
        "include/**",
    ]),
    visibility = ["//visibility:public"],
)

cc_stage2_library(
    name = "libcxxabi",
    defines = [
        "NDEBUG",
        "LIBCXX_BUILDING_LIBCXXABI",
        # DHAVE___CXA_THREAD_ATEXIT_IMPL (gnu but not linux and glibc >= 2.18)
        "_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS", # Only for satic c++abi"
    ],
    copts = [
        "-fvisibility=hidden",
        "-fvisibility-inlines-hidden",
        # "-fPIC", #TODO: Support PIC
        "-fstrict-aliasing",
        "-std=c++23",
        "-Wno-user-defined-literals",
        "-Wno-covered-switch-default",
        "-Wno-suggest-override",
        "-funwind-tables", # if exceptions
    ],
    includes = [
        "include",
        "src",
    ],
    hdrs = glob([
        "include/**",
    ]),
    textual_hdrs = [
        "@libcxx//:textual_hdrs",
    ] + glob([
        "src/**/*.h",
        "src/**/*.def",
    ]),
    srcs = [
        "src/abort_message.cpp",
        "src/cxa_aux_runtime.cpp",
        "src/cxa_default_handlers.cpp",
        "src/cxa_demangle.cpp",
        "src/cxa_exception.cpp", # if exception
        "src/cxa_exception_storage.cpp",
        "src/cxa_guard.cpp",
        "src/cxa_handlers.cpp",
        # "src/cxa_noexception.cpp", # if no exceptions
        "src/cxa_personality.cpp", # if exceptions
        "src/cxa_thread_atexit.cpp", # not if no threads
        "src/cxa_vector.cpp",
        "src/cxa_virtual.cpp",
        "src/fallback_malloc.cpp",
        "src/private_typeinfo.cpp",
        "src/stdlib_exception.cpp",
        "src/stdlib_new_delete.cpp",
        "src/stdlib_stdexcept.cpp",
        "src/stdlib_typeinfo.cpp",
    ],
    implementation_deps = [
        # Order matter. Search path should have C++ headers before any lib C headers.
        "@libcxx//:headers",
    ] + select({
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
    }) + [
        "@toolchains_llvm_bootstrapped//third_party/llvm-project:libc_headers",
    ],
    visibility = ["//visibility:public"],
)

cc_stage2_static_library(
    name = "libcxxabi.static",
    deps = [
        ":libcxxabi",
    ],
    visibility = ["//visibility:public"],
)
