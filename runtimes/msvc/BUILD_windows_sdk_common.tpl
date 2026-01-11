load("@bazel_skylib//rules/directory:directory.bzl", "directory")
load("@bazel_skylib//rules/directory:subdirectory.bzl", "subdirectory")
load("@toolchains_llvm_bootstrapped//:directory.bzl", "headers_directory")

package(default_visibility = ["//visibility:public"])

headers_directory(
    name = "headers_include",
    path = "c/Include",
    visibility = ["//visibility:public"],
)
