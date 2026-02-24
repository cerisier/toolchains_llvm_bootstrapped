load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

def _linker_contract_from_cc_toolchain_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    link_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = ctx.attr.is_linking_dynamic_library,
        runtime_library_search_directories = [],
        user_link_flags = ctx.attr.user_link_flags,
    )
    link_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ctx.attr.action_name,
        variables = link_variables,
    )

    lines = [
        "# directive<TAB>payload",
    ]
    for argument in link_args:
        if not argument:
            continue
        lines.append("arg\t%s" % argument)

    ctx.actions.write(
        output = ctx.outputs.out,
        content = "\n".join(lines) + "\n",
    )

    return [DefaultInfo(files = depset([ctx.outputs.out]))]

linker_contract_from_cc_toolchain = rule(
    doc = "Generates a linker contract by expanding rules_cc link args for one link action.",
    implementation = _linker_contract_from_cc_toolchain_impl,
    attrs = {
        "out": attr.output(
            mandatory = True,
        ),
        "action_name": attr.string(
            default = ACTION_NAMES.cpp_link_executable,
        ),
        "is_linking_dynamic_library": attr.bool(
            default = False,
        ),
        "user_link_flags": attr.string_list(
            default = [],
        ),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def linker_wrapper_config_genrule(name, out, contract_label):
    native.genrule(
        name = name,
        outs = [out],
        cmd = "\n".join([
            "cat > $@ <<'CONFIG'",
            "#include \"tools/internal/linker_wrapper_config.h\"",
            "",
            "namespace llvm_toolchain {",
            "",
            "const char* kLinkerWrapperClangRlocation = \"$(rlocationpath //tools:clang++)\";",
            "const char* kLinkerWrapperContractRlocation = \"$(rlocationpath %s)\";" % contract_label,
            "",
            "}  // namespace llvm_toolchain",
            "CONFIG",
        ]),
        tools = [
            "//tools:clang++",
            contract_label,
        ],
    )
