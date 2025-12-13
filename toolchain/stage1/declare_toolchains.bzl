load("//platforms:common.bzl", _supported_targets = "SUPPORTED_TARGETS", _supported_execs = "SUPPORTED_EXECS")
load("//toolchain:cc_toolchain.bzl", "cc_toolchain")

def declare_toolchains():
    for (exec_os, exec_cpu) in _supported_execs:
        cc_toolchain_name = "{}_{}_cc_toolchain".format(exec_os, exec_cpu)

        # Even though `tool_map` has an exec transition, Bazel doesn't properly handle
        # binding a single `cc_toolchain` to multiple toolchains with different `exec_compatible_with`.
        # See https://github.com/bazelbuild/rules_cc/issues/299#issuecomment-2660340534
        cc_toolchain(
            name = cc_toolchain_name,
            tool_map = select({
                "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_macos_setting": ":tools_with_libtool",
                "//conditions:default": ":default_tools",
            }),
        )

        for (target_os, target_cpu) in _supported_targets:
            native.toolchain(
                name = "{}_{}_to_{}_{}".format(exec_os, exec_cpu, target_os, target_cpu),
                exec_compatible_with = [
                    "@platforms//cpu:{}".format(exec_cpu),
                    "@platforms//os:{}".format(exec_os),
                ],
                target_compatible_with = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                ],
                target_settings = [
                    "//toolchain:bootstrapped",
                    "//toolchain:stage1_bootstrapped",
                ],
                toolchain = cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )
