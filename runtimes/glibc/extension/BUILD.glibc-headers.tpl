load("@bazel_skylib//rules/directory:directory.bzl", "directory")
load("@bazel_skylib//rules/directory:subdirectory.bzl", "subdirectory")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_library(
    name = "gnu_libc_headers",
    hdrs = glob([
        "include/**",
    ]),
    includes = [
        "include",
    ],
    # user code should always get glibc headers as -isystem
    # but it seems glibc itself includes as <...>
    features = ["system_include_paths"],
    visibility = ["//visibility:public"],
)

directory(
    name = "glibc_headers_top_directory",
    srcs = glob([
        "include/**",
    ]),
    visibility = ["//visibility:public"],
)

subdirectory(
    name = "glibc_headers_directory",
    path = "include",
    parent = ":glibc_headers_top_directory",
    visibility = ["//visibility:public"],
)
