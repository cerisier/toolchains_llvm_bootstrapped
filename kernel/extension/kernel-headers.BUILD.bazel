load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@toolchains_llvm_bootstrapped//:directory.bzl", "headers_directory")

cc_library(
    name = "kernel_headers",
    hdrs = ["include"],
    includes = ["include"],
    # Any code should always get passed linux UAPI headers as -isystem
    features = ["system_include_paths"],
    visibility = ["//visibility:public"],
)

headers_directory(
    name = "kernel_headers_directory",
    path = "include",
    visibility = ["//visibility:public"],
)
