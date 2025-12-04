
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")

#TODO(cerisier): use a single shared transition
bootstrap_transition = transition(
    implementation = lambda settings, attr: {
        "//toolchain:bootstrap_setting": True,
    },
    inputs = [],
    outputs = [
        "//toolchain:bootstrap_setting",
    ],
)

def _cc_stage2_object_impl(ctx):
    object = ctx.actions.declare_file(ctx.label.name + ".o")

    cc_toolchain = find_cc_toolchain(ctx)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )

    cc_tool = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_executable,
    )

    arguments = ctx.actions.args()
    arguments.add("-fuse-ld=lld")
    arguments.add_all(ctx.attr.copts)
    arguments.add("-r")
    arguments.add("-Wl,--whole-archive")
    arguments.add_all(ctx.files.srcs)
    arguments.add("-o")
    arguments.add(object)

    ctx.actions.run(
        inputs = ctx.files.srcs,
        outputs = [object],
        arguments = [arguments],
        tools = cc_toolchain.all_files,
        executable = cc_tool,
        mnemonic = "CcStage2Compile",
    )

    return [DefaultInfo(files = depset([object]))]

cc_stage2_object = rule(
    implementation = _cc_stage2_object_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "copts": attr.string_list(
            mandatory = True,
        ),
    },
    cfg = bootstrap_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
