load("@rules_cc//cc/toolchains:toolchain.bzl", _cc_toolchain = "cc_toolchain")
load("@rules_cc//cc/toolchains:feature_set.bzl", "cc_feature_set")

def cc_toolchain(name, tool_map):

    cc_feature_set(
        name = name + "_enabled_features",
        all_of = [
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
        ] + select({
            "@platforms//os:linux": [
                "//toolchain/features:static_link_cpp_runtimes",
            ],
            "@platforms//os:macos": [],
            "@platforms//os:windows": [
                "//toolchain/features:static_link_cpp_runtimes",
            ],
            "@platforms//os:none": [],
        }) + [
            "//toolchain/features/legacy:all_legacy_builtin_features",
        ],
    )

    cc_feature_set(
        name = name + "_runtimes_only_enabled_features",
        all_of = [
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_known_features",
        all_of = [
            "//toolchain/features:static_link_cpp_runtimes",
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
            # Those features are enabled internally by --compilation_mode flags family.
            # We add them to the list of known_features but not in the list of enabled_features.
            "//toolchain/features:all_non_legacy_builtin_features",
            "//toolchain/features/legacy:all_legacy_builtin_features",
        ] + select({
            "@platforms//os:linux": [
                "@rules_cc//cc/toolchains/args/thin_lto:feature",
            ],
            "//conditions:default": [],
        }),
    )

    cc_feature_set(
        name = name + "_runtimes_only_known_features",
        all_of = ["@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features"],
    )

    _cc_toolchain(
        name = name,
        args = select({
            "//toolchain:bootstrapping": ["//toolchain/stage2:runtimes_only_toolchain_args"],
            "//conditions:default": ["//toolchain:toolchain_args"],
        }),
        artifact_name_patterns = select({
            "@platforms//os:windows": [
                "//toolchain:windows_executable_pattern",
            ],
            "//conditions:default": [],
        }),
        known_features = select({
            "//toolchain:bootstrapping": [name + "_runtimes_only_known_features"],
            "//conditions:default": [name + "_known_features"],
        }),
        enabled_features = select({
            "//toolchain:bootstrapping": [name + "_runtimes_only_enabled_features"],
            "//conditions:default": [name + "_enabled_features"],
        }),
        tool_map = tool_map,
        static_runtime_lib = select({
            "//toolchain:bootstrapping": "//runtimes:empty_filegroup",
            "//conditions:default": "//runtimes:static_runtime_lib",
        }),
        dynamic_runtime_lib = select({
            "//toolchain:bootstrapping": "//runtimes:empty_filegroup",
            "//conditions:default": "//runtimes:dynamic_runtime_lib",
        }),
        compiler = "clang",
    )
