load("//platforms:common.bzl", "SUPPORTED_TARGETS", "SUPPORTED_EXECS")
load("//toolchain:selects.bzl", "platform_cc_tool_map", "platform_module_map")
load(":cc_toolchain.bzl", "cc_toolchain")

def declare_toolchains(*, execs = SUPPORTED_EXECS, targets = SUPPORTED_TARGETS):
    """Declares the configured LLVM toolchains.

    Args:
        execs: List of (os, arch) tuples describing exec platforms.
        targets: List of (os, arch) tuples describing target platforms.
    """
    for (exec_os, exec_cpu) in execs:
        cc_toolchain_name = "cuda_{}_{}_cc_toolchain".format(exec_os, exec_cpu)

        # Even though `tool_map` has an exec transition, Bazel doesn't properly handle
        # binding a single `cc_toolchain` to multiple toolchains with different `exec_compatible_with`.
        # See https://github.com/bazelbuild/rules_cc/issues/299#issuecomment-2660340534
        cc_toolchain(
            name = cc_toolchain_name,
            tool_map = platform_cc_tool_map(exec_os, exec_cpu),
            module_map = platform_module_map(exec_os, exec_cpu),
        )

        native.toolchain(
            name = "cuda_{}_{}_to_none_nvptx64".format(exec_os, exec_cpu),
            exec_compatible_with = [
                "@platforms//cpu:{}".format(exec_cpu),
                "@platforms//os:{}".format(exec_os),
            ],
            target_compatible_with = [
                "@llvm//constraints/accelerator/arch:nvptx64",
            ],
            target_settings = [
                "@llvm//toolchain:prebuilt_toolchain",
            ],
            toolchain = cc_toolchain_name,
            toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
            visibility = ["//visibility:public"],
        )
