load("@rules_cc//cc/toolchains:toolchain.bzl", "cc_toolchain")
load("//platforms:common.bzl", _arch_aliases = "ARCH_ALIASES", _supported_targets = "SUPPORTED_TARGETS", _supported_execs = "SUPPORTED_EXECS")
load("//toolchain:selects.bzl", "platform_cc_tool_map")

def declare_toolchains():
    for (exec_os, exec_cpu) in _supported_execs:
        cc_toolchain_name = "{}_{}_cc_toolchain".format(exec_os, exec_cpu)

        cc_toolchain(
            name = cc_toolchain_name,
            args = [
                "//toolchain/args:llvm_target_for_platform",
                "//toolchain/args:no_absolute_paths_for_builtins",
                "//toolchain/args:deterministic_compile_flags",
                ":platform_specific_args",
                ":optimization_flags",
                "//toolchain/stage2/args:default_link_flags",
            ],
            enabled_features = ["@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features"],
            known_features = ["@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features"],
            tool_map = platform_cc_tool_map(exec_os, exec_cpu),
            compiler = "clang",
        )

        native.toolchain(
            name = "{}_{}".format(exec_os, exec_cpu),
            exec_compatible_with = [
                "@platforms//cpu:{}".format(exec_cpu),
                "@platforms//os:{}".format(exec_os),
            ],
            target_compatible_with = [
                "@platforms//cpu:{}".format(exec_cpu),
                "@platforms//os:{}".format(exec_os),
            ],
            toolchain = cc_toolchain_name,
            toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
            target_settings = [
                "//toolchain:bootstrapping",
            ],
            visibility = ["//visibility:public"],
        )

