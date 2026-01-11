load("@rules_cc//cc/toolchains:toolchain.bzl", _cc_toolchain = "cc_toolchain")
load("@rules_cc//cc/toolchains:feature_set.bzl", "cc_feature_set")

def cc_toolchain(name, tool_map, module_map = None):

    cc_feature_set(
        name = name + "_known_features",
        all_of = [
            "@rules_cc//cc/toolchains/args/layering_check:layering_check",
            "@rules_cc//cc/toolchains/args/layering_check:use_module_maps",
            "//toolchain/features:static_link_cpp_runtimes",
            "//toolchain/features/runtime_library_search_directories:feature",
            "//toolchain/features:archive_param_file",
        ] + select({
            "@platforms//os:linux": [
                "@rules_cc//cc/toolchains/args/thin_lto:feature",
            ],
            "//conditions:default": [],
        }) + [
            # Those features are enabled internally by --compilation_mode flags family.
            # We add them to the list of known_features but not in the list of enabled_features.
            "//toolchain/features:all_non_legacy_builtin_features",
            "//toolchain/features/legacy:all_legacy_builtin_features",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_runtimes_only_known_features",
        all_of = [
            # TODO(zbarsky): Do we want layering check for runtime libs?
            #"@rules_cc//cc/toolchains/args/layering_check:layering_check",
            #"@rules_cc//cc/toolchains/args/layering_check:use_module_maps",

            "//toolchain/features:archive_param_file",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_enabled_features",
        all_of = select({
            "@platforms//os:linux": [
                "//toolchain/features:static_link_cpp_runtimes",
                "//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@platforms//os:macos": [],
            "@platforms//os:windows": [
                "//toolchain/features:static_link_cpp_runtimes",
                "//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@platforms//os:none": [],
        }) + [
            "@rules_cc//cc/toolchains/args/layering_check:module_maps",
            "//toolchain/features:archive_param_file",
            "//toolchain/features:parse_headers",
            "//toolchain/features/legacy:all_legacy_builtin_features",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_runtimes_only_enabled_features",
        all_of = [
            "//toolchain/features:archive_param_file",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
        ],
    )

    _cc_toolchain(
        name = name,
        args = select({
            "//toolchain:runtimes_none": ["//toolchain/runtimes:toolchain_args"],
            "//toolchain:runtimes_stage1": ["//toolchain/runtimes:toolchain_args"],
            "//conditions:default": ["//toolchain:toolchain_args"],
        }) + [
            # TODO: rules_cc passes extra args to these actions, ideally these would be fixed in rules_cc.
            "//toolchain/args:ignore_unused_command_line_argument",
        ],
        supports_header_parsing = True,
        artifact_name_patterns = select({
            "@platforms//os:windows": [
                "//toolchain:windows_executable_pattern",
            ],
            "//conditions:default": [],
        }),
        known_features = select({
            "//toolchain:runtimes_none": [name + "_runtimes_only_known_features"],
            "//toolchain:runtimes_stage1": [name + "_runtimes_only_known_features"],
            "//conditions:default": [name + "_known_features"],
        }),
        enabled_features = select({
            "//toolchain:runtimes_none": [name + "_runtimes_only_enabled_features"],
            "//toolchain:runtimes_stage1": [name + "_runtimes_only_enabled_features"],
            "//conditions:default": [name + "_enabled_features"],
        }),
        tool_map = tool_map,
        module_map = module_map,
        static_runtime_lib = select({
            "//toolchain:runtimes_none": "//runtimes:none",
            "//toolchain:runtimes_stage1": "//runtimes:none",
            "//conditions:default": "//runtimes:static_runtime_lib",
        }),
        dynamic_runtime_lib = select({
            "//toolchain:runtimes_none": "//runtimes:none",
            "//toolchain:runtimes_stage1": "//runtimes:none",
            "//conditions:default": "//runtimes:dynamic_runtime_lib",
        }),
        compiler = "clang",
    )
