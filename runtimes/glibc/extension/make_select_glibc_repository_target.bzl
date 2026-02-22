load("//constraints/libc:libc_versions.bzl", "GLIBCS", "DEFAULT_LIBC")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")

def make_select_glibc_repository_target(bazel_repository, bazel_target):
    selection = {}
    for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
        for libc_version in GLIBCS + ["unconstrained"]:
            apparent_libc_version_suffix = libc_version if libc_version != "unconstrained" else DEFAULT_LIBC
            apparent_target = "{}_{}-{}-{}//:{}".format(bazel_repository, target_arch, target_os, apparent_libc_version_suffix, bazel_target)
            selection["@llvm//platforms/config:{}_{}_{}".format(target_os, target_arch, libc_version)] = apparent_target

    return select(selection)
