load("@rules_cc//cc/toolchains:toolchain.bzl", "cc_toolchain")
load("//platforms:common.bzl", _supported_targets = "SUPPORTED_TARGETS", _supported_execs = "SUPPORTED_EXECS")
load("//toolchain:selects.bzl", "platform_cc_tool_map")

def declare_all_toolchains():
    for (exec_os, exec_cpu) in _supported_execs:
        _declare_toolchains(exec_os, exec_cpu)

def _declare_toolchains(exec_os, exec_cpu):
    cc_toolchain_name = "{}_{}_cc_toolchain".format(exec_os, exec_cpu)

    # Even though `tool_map` has an exec transition, Bazel doesn't properly handle
    # binding a single `cc_toolchain` to multiple toolchains with different `exec_compatible_with`.
    # See https://github.com/bazelbuild/rules_cc/issues/299#issuecomment-2660340534
    cc_toolchain(
        name = cc_toolchain_name,
        args = [":toolchain_args"],
        known_features = [
            "//toolchain/features:static_link_cpp_runtimes",
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
            "//toolchain/features:all_non_legacy_builtin_features",
            "//toolchain/features/legacy:all_legacy_builtin_features",
        ] + select({
            # Should be last. This is a workaround to add those args last.
            # See comment of this target.
            "@platforms//os:linux": [
                "//toolchain/args/linux:crtend_feature",
            ],
            "//conditions:default": [],
        }),
        enabled_features = select({
            "@platforms//os:linux": [
                "//toolchain/features:static_link_cpp_runtimes",
            ],
            "@platforms//os:macos": [],
        }) + [
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
            # Do not enable this manually. Those features are enabled internally by --compilation_mode flags family.
            "//toolchain/features/legacy:all_legacy_builtin_features",
        ] + select({
            # Should be last. This is a workaround to add those args last.
            # See comment of this target.
            "@platforms//os:linux": [
                "//toolchain/args/linux:crtend_feature",
            ],
            "//conditions:default": [],
        }),
        tool_map = platform_cc_tool_map(exec_os, exec_cpu),
        static_runtime_lib = "//runtimes:static_runtime_lib",
        dynamic_runtime_lib = "//runtimes:dynamic_runtime_lib",
        compiler = "clang",
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
            ],
            toolchain = cc_toolchain_name,
            toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
            visibility = ["//visibility:public"],
        )
