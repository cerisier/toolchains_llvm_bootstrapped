load("//constraints/libc:libc_versions.bzl", "GLIBCS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")

def make_select_glibc_repository_target(bazel_repository, bazel_target):
    selection = {}
    for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
        for libc_version in GLIBCS:
            apparent_target = "{}_{}-{}-{}//:{}".format(bazel_repository, target_arch, target_os, libc_version, bazel_target)
            selection["@toolchains_llvm_bootstrapped//platforms/config:{}_{}_{}".format(target_os, target_arch, libc_version)] = apparent_target

    return select(selection)
