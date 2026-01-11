load("//platforms:common.bzl", "ABI_SUPPORTED_TARGETS", "SUPPORTED_EXECS", "SUPPORTED_TARGETS")
load("//toolchain:selects.bzl", "platform_cc_tool_map")
load(":cc_toolchain.bzl", "cc_toolchain")

def declare_toolchains(*, execs = SUPPORTED_EXECS, targets = SUPPORTED_TARGETS):
    """Declares the configured LLVM toolchains.

    Args:
        execs: List of (os, arch) tuples describing exec platforms.
        targets: List of (os, arch) tuples describing target platforms.
    """
    for (exec_os, exec_cpu) in execs:
        cc_toolchain_name = "{}_{}_cc_toolchain".format(exec_os, exec_cpu)

        # Even though `tool_map` has an exec transition, Bazel doesn't properly handle
        # binding a single `cc_toolchain` to multiple toolchains with different `exec_compatible_with`.
        # See https://github.com/bazelbuild/rules_cc/issues/299#issuecomment-2660340534
        cc_toolchain(
            name = cc_toolchain_name,
            tool_map = platform_cc_tool_map(exec_os, exec_cpu),
        )

        for (target_os, target_cpu) in targets:
            native.toolchain(
                name = "{}_{}_to_{}_{}".format(exec_os, exec_cpu, target_os, target_cpu),
                exec_compatible_with = [
                    "@platforms//cpu:{}".format(exec_cpu),
                    "@platforms//os:{}".format(exec_os),
                ],
                target_compatible_with = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                    "//constraints/abi:unconstrained",
                ],
                target_settings = [
                    "@toolchains_llvm_bootstrapped//toolchain:prebuilt_toolchain",
                ],
                toolchain = cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )

        msvc_cc_toolchain_name = "{}_{}_msvc_cc_toolchain".format(exec_os, exec_cpu)
        cc_toolchain(
            name = msvc_cc_toolchain_name,
            tool_map = platform_cc_tool_map(exec_os, exec_cpu, msvc = True),
            compiler = "clang",  # FIXME: change to clang-cl
        )
        for (target_os, target_cpu) in ABI_SUPPORTED_TARGETS:
            native.toolchain(
                name = "{}_{}_to_{}_{}_msvc".format(exec_os, exec_cpu, target_os, target_cpu),
                exec_compatible_with = [
                    "@platforms//cpu:{}".format(exec_cpu),
                    "@platforms//os:{}".format(exec_os),
                ],
                target_compatible_with = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                    "//constraints/abi:msvc",
                ],
                target_settings = [
                    "@toolchains_llvm_bootstrapped//toolchain:prebuilt_toolchain",
                ],
                toolchain = msvc_cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )
