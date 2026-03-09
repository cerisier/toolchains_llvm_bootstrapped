load("//constraints/libc:libc_versions.bzl", "LIBCS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")
load(":kernel_helpers.bzl", "arch_to_kernel_arch")
load(":libc_kernel_versions.bzl", "LIBC_KERNEL_VERSIONS")

def make_select_kernel_headers_repository_target(bazel_target):
    """Select the right kernel headers repository based on the target architecture and the libc version.

    Args:
        bazel_target: The target within the kernel headers repository to select.

    Returns:
        A select expression that selects the appropriate target in the kernel headers repository based on the target architecture and libc version.
    """
    selection = {}
    for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
        for libc_version in LIBCS + ["unconstrained"]:
            kernel_version = LIBC_KERNEL_VERSIONS[libc_version]
            apparent_target = "@linux_kernel_headers_{}.{}//:{}".format(arch_to_kernel_arch(target_arch), kernel_version, bazel_target)
            selection["@llvm//platforms/config:{}_{}_{}".format(target_os, target_arch, libc_version)] = apparent_target

    return select(selection)
