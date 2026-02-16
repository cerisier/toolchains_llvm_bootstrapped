load("@rules_cc//cc/toolchains:toolchain.bzl", _cc_toolchain = "cc_toolchain")
load("@rules_cc//cc/toolchains:feature_set.bzl", "cc_feature_set")

def cc_toolchain(name, tool_map, module_map = None):

    cc_feature_set(
        name = name + "_known_features",
        all_of = [
            "@rules_cc//cc/toolchains/args/layering_check:layering_check",
            "@rules_cc//cc/toolchains/args/layering_check:use_module_maps",
            "@toolchains_llvm_bootstrapped//toolchain/features:static_link_cpp_runtimes",
            "@toolchains_llvm_bootstrapped//toolchain/features/runtime_library_search_directories:feature",
            "@toolchains_llvm_bootstrapped//toolchain/features:archive_param_file",
            "@toolchains_llvm_bootstrapped//toolchain/features:prefer_pic_for_opt_binaries",
        ] + select({
            "@platforms//os:linux": [
                "@rules_cc//cc/toolchains/args/thin_lto:feature",
            ],
            "//conditions:default": [],
        }) + [
            # Those features are enabled internally by --compilation_mode flags family.
            # We add them to the list of known_features but not in the list of enabled_features.
            "@toolchains_llvm_bootstrapped//toolchain/features:all_non_legacy_builtin_features",
            "@toolchains_llvm_bootstrapped//toolchain/features/legacy:all_legacy_builtin_features",
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

            "@toolchains_llvm_bootstrapped//toolchain/features:archive_param_file",
            "@toolchains_llvm_bootstrapped//toolchain/features:prefer_pic_for_opt_binaries",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_enabled_features",
        all_of = select({
            "@platforms//os:linux": [
                "@toolchains_llvm_bootstrapped//toolchain/features:static_link_cpp_runtimes",
                "@toolchains_llvm_bootstrapped//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@platforms//os:macos": [],
            "@platforms//os:windows": [
                "@toolchains_llvm_bootstrapped//toolchain/features:static_link_cpp_runtimes",
                "@toolchains_llvm_bootstrapped//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@platforms//os:none": [],
        }) + [
            "@toolchains_llvm_bootstrapped//toolchain/features:prefer_pic_for_opt_binaries",
            "@rules_cc//cc/toolchains/args/layering_check:module_maps",
            # These are "enabled" but they only _actually_ get enabled when the underlying compilation mode is set.
            # This lets us properly order them before user_compile_flags and user_link_flags below.
            "@toolchains_llvm_bootstrapped//toolchain/features:opt",
            "@toolchains_llvm_bootstrapped//toolchain/features:dbg",
            "@toolchains_llvm_bootstrapped//toolchain/features:archive_param_file",
            "@toolchains_llvm_bootstrapped//toolchain/features:parse_headers",
            "@toolchains_llvm_bootstrapped//toolchain/features/legacy:all_legacy_builtin_features",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_runtimes_only_enabled_features",
        all_of = [
            "@toolchains_llvm_bootstrapped//toolchain/features:prefer_pic_for_opt_binaries",
            "@toolchains_llvm_bootstrapped//toolchain/features:archive_param_file",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@rules_cc//cc/toolchains/args:experimental_replace_legacy_action_config_features",
        ],
    )

    _cc_toolchain(
        name = name,
        args = select({
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_none": ["@toolchains_llvm_bootstrapped//toolchain/runtimes:toolchain_args"],
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_stage1": ["@toolchains_llvm_bootstrapped//toolchain/runtimes:toolchain_args"],
            "//conditions:default": ["@toolchains_llvm_bootstrapped//toolchain:toolchain_args"],
        }) + [
            # TODO: rules_cc passes extra args to these actions, ideally these would be fixed in rules_cc.
            "@toolchains_llvm_bootstrapped//toolchain/args:ignore_unused_command_line_argument",
        ],
        supports_header_parsing = True,
        artifact_name_patterns = select({
            "@platforms//os:macos": [
                "@toolchains_llvm_bootstrapped//toolchain:macos_dynamic_library_pattern",
            ],
            "@platforms//os:windows": [
                "@toolchains_llvm_bootstrapped//toolchain:windows_executable_pattern",
            ],
            "//conditions:default": [],
        }),
        known_features = select({
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_none": [name + "_runtimes_only_known_features"],
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_stage1": [name + "_runtimes_only_known_features"],
            "//conditions:default": [name + "_known_features"],
        }),
        enabled_features = select({
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_none": [name + "_runtimes_only_enabled_features"],
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_stage1": [name + "_runtimes_only_enabled_features"],
            "//conditions:default": [name + "_enabled_features"],
        }),
        tool_map = tool_map,
        module_map = module_map,
        static_runtime_lib = select({
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_none": "@toolchains_llvm_bootstrapped//runtimes:none",
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_stage1": "@toolchains_llvm_bootstrapped//runtimes:none",
            "//conditions:default": "@toolchains_llvm_bootstrapped//runtimes:static_runtime_lib",
        }),
        dynamic_runtime_lib = select({
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_none": "@toolchains_llvm_bootstrapped//runtimes:none",
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_stage1": "@toolchains_llvm_bootstrapped//runtimes:none",
            "//conditions:default": "@toolchains_llvm_bootstrapped//runtimes:dynamic_runtime_lib",
        }),
        compiler = "clang",
    )
