load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@toolchains_llvm_bootstrapped//:directory.bzl", "headers_directory")

cc_library(
    name = "gnu_libc_headers",
    hdrs = ["include"],
    includes = ["include"],
    # user code should always get glibc headers as -isystem
    # but it seems glibc itself includes as <...>
    features = ["system_include_paths"],
    visibility = ["//visibility:public"],
)

headers_directory(
    name = "glibc_headers_directory",
    path = "include",
    visibility = ["//visibility:public"],
)
