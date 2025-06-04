load("//constraints/libc:libc_versions.bzl", "GLIBCS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")

def make_select_glibc_repository_target(bazel_repository, bazel_target):
    selection = {}
    for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
        # TODO(cerisier): Use the right glibc version for the target architecture.
        #
        # We should choose the minimum version of the glibc that supports the
        # target architecture. For now 2.28 is ok because we only support x86_64
        # and aarch64. But loongarch, risc and csky for instance were 
        # introduced later.
        apparent_target = "{}_{}-{}-gnu.2.28//:{}".format(bazel_repository, target_arch, target_os, bazel_target)
        selection["@toolchains_llvm_bootstrapped//platforms/config/libc_aware:{}_{}".format(target_os, target_arch)] = apparent_target

        for libc_version in GLIBCS:
            apparent_target = "{}_{}-{}-{}//:{}".format(bazel_repository, target_arch, target_os, libc_version, bazel_target)
            selection["@toolchains_llvm_bootstrapped//platforms/config/libc_aware:{}_{}_{}".format(target_os, target_arch, libc_version)] = apparent_target

    return select(selection)
