load("@rules_cc//cc/toolchains:toolchain.bzl", _cc_toolchain = "cc_toolchain")

def cc_toolchain(name, tool_map):
    _cc_toolchain(
        name = name,
        args = ["//toolchain:toolchain_args"],
        artifact_name_patterns = select({
            "@platforms//os:windows": [
                "//toolchain:windows_executable_pattern",
            ],
            "//conditions:default": [],
        }),
        known_features = [
            "//toolchain/features:static_link_cpp_runtimes",
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
            "//toolchain/features:all_non_legacy_builtin_features",
            "//toolchain/features/legacy:all_legacy_builtin_features",
        ] + select({
            "@platforms//os:linux": [
                # TODO(zbarsky): Enable this once rules_cc cuts a release.
                # "@rules_cc//cc/toolchains/args/thin_lto:feature",
            ],
            "//conditions:default": [],
        }),
        enabled_features = select({
            "@platforms//os:linux": [
                "//toolchain/features:static_link_cpp_runtimes",
            ],
            "@platforms//os:macos": [],
            "@platforms//os:windows": [
                "//toolchain/features:static_link_cpp_runtimes",
            ],
            "@platforms//os:none": [],
        }) + [
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
            # Do not enable this manually. Those features are enabled internally by --compilation_mode flags family.
            "//toolchain/features/legacy:all_legacy_builtin_features",
        ],
        tool_map = tool_map,
        static_runtime_lib = "//runtimes:static_runtime_lib",
        dynamic_runtime_lib = "//runtimes:dynamic_runtime_lib",
        compiler = "clang",
    )
