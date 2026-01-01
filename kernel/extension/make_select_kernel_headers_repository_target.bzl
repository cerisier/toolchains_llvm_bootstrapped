load("//constraints/libc:libc_versions.bzl", "LIBCS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")
load(":libc_kernel_versions.bzl", "LIBC_KERNEL_VERSIONS")
load(":kernel_helpers.bzl", "arch_to_kernel_arch")

def make_select_kernel_headers_repository_target(bazel_target):
    """Select the right kernel headers repository based on the target architecture and the libc version."""
    selection = {}
    for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
        for libc_version in LIBCS + ["unconstrained"]:
            kernel_version = LIBC_KERNEL_VERSIONS[libc_version]
            apparent_target = "@linux_kernel_headers_{}.{}//:{}".format(arch_to_kernel_arch(target_arch), kernel_version, bazel_target)
            if libc_version == "cosmo":
                selection["@toolchains_llvm_bootstrapped//platforms/config:cosmo_{}".format(target_arch)] = apparent_target
            else:
                selection["@toolchains_llvm_bootstrapped//platforms/config:{}_{}_{}".format(target_os, target_arch, libc_version)] = apparent_target

    return select(selection)
