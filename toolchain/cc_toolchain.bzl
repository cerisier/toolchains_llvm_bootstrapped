load("@rules_cc//cc/toolchains:toolchain.bzl", _cc_toolchain = "cc_toolchain")

def cc_toolchain(name, tool_map):
    _cc_toolchain(
        name = name,
        args = ["//toolchain:toolchain_args"],
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
        tool_map = tool_map,
        static_runtime_lib = "//runtimes:static_runtime_lib",
        dynamic_runtime_lib = "//runtimes:dynamic_runtime_lib",
        compiler = "clang",
    )
