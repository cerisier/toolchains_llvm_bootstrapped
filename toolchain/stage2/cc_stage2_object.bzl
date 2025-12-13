
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
    for src in ctx.files.srcs:
        #TODO(cerisier): extract pic objects CC info instead of this.
        # PICness from stage2 objects is defined in copts, not by the pic feature.
        if src.path.endswith(".pic.a"):
            continue
        if src.path.endswith(".a"):
            arguments.add_all(["-Wl,--whole-archive", src, "-Wl,--no-whole-archive"])
        if src.path.endswith(".o"):
            arguments.add(src)
    arguments.add("-o")
    arguments.add(ctx.outputs.out)

    ctx.actions.run(
        inputs = ctx.files.srcs,
        outputs = [ctx.outputs.out],
        arguments = [arguments],
        tools = cc_toolchain.all_files,
        executable = cc_tool,
        execution_requirements = {"supports-path-mapping": "1"},
        mnemonic = "CcStage2Compile",
    )

    return [DefaultInfo(files = depset([ctx.outputs.out]))]

cc_stage2_object = rule(
    doc = "A rule that links .o and .a files into a single .o file.",
    implementation = _cc_stage2_object_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "List of source files (.o or .a) to be linked into a single object file.",
            allow_files = [".o", ".a"],
            mandatory = True,
        ),
        "copts": attr.string_list(
            doc = "Additional compiler options",
            default = [],
            mandatory = True,
        ),
        "out": attr.output(
            doc = "The output object file.",
            mandatory = True,
        ),
    },
    cfg = bootstrap_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
