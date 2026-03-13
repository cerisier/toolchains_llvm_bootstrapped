
load("//platforms:common.bzl", "CUDA_SUPPORTED_EXECS", "CUDA_SUPPORTED_TARGETS")
load("//toolchain/cuda:cc_toolchain.bzl", "cc_toolchain")
# load("//toolchain/bootstrap:declare_toolchains.bzl", "declare_tool_map")

def declare_toolchains(*, execs = CUDA_SUPPORTED_EXECS, targets = CUDA_SUPPORTED_TARGETS):
    """Declares the configured LLVM toolchains.

    Args:
        execs: List of (os, arch) tuples describing exec platforms.
        targets: List of (os, arch) tuples describing target platforms.
    """
    for (exec_os, exec_cpu) in execs:

        # Not doing this since it overrides existing toolmap at call site
        # declare_tool_map(exec_os, exec_cpu)

        cuda_cc_toolchain_name = "bootstrap_cuda_{}_{}_cc_toolchain".format(exec_os, exec_cpu)
        cc_toolchain(
            name = cuda_cc_toolchain_name,
            tool_map = select({
                # We know that those targets are defined earlier by declare_bootstrap_toolchains
                "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_macos_setting": ":{}_{}/tools_with_libtool".format(exec_os, exec_cpu),
                "//conditions:default": ":{}_{}/default_tools".format(exec_os, exec_cpu),
            }),
        )

        for (target_os, target_cpu) in targets:
            native.toolchain(
                name = "bootstrap_cuda_{}_{}_to_{}_{}".format(exec_os, exec_cpu, target_os, target_cpu),
                exec_compatible_with = [
                    "@platforms//cpu:{}".format(exec_cpu),
                    "@platforms//os:{}".format(exec_os),
                ],
                target_compatible_with = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                ],
                target_settings = [
                    "@llvm//toolchain:bootstrapped_toolchain",
                    "@llvm//config:cuda_device_mode_enabled",
                ],
                toolchain = cuda_cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )
