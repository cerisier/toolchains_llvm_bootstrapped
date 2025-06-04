load("@bazel_skylib//rules/directory:directory.bzl", "directory")
load("@bazel_skylib//rules/directory:subdirectory.bzl", "subdirectory")

cc_library(
    name = "gnu_libc_headers",
    hdrs = glob([
        "include/**",
    ]),
    includes = [
        "include",
    ],
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
