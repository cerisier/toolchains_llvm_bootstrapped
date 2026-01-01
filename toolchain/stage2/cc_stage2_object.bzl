
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

    # Fast-path: if we only have a single archive/object, avoid invoking the
    # linker (which can be fragile on mixed execution platforms) by extracting
    # or forwarding the object directly.
    archives = [s for s in ctx.files.srcs if s.path.endswith((".a", ".pic.a"))]
    objects = [s for s in ctx.files.srcs if s.path.endswith(".o")]
    if archives and len(archives) == len(ctx.files.srcs):
        src = archives[0]
        ctx.actions.run_shell(
            inputs = [src, ctx.file._llvm_ar],
            tools = [ctx.file._llvm_ar],
            outputs = [ctx.outputs.out],
            command = """set -e
ROOT=$(pwd -P)
TMPDIR=$(mktemp -d)
cp "$ROOT/{src}" "$TMPDIR/lib.a"
cd "$TMPDIR"
AR="$ROOT/{ar}"
"$AR" x lib.a
obj=$(ls *.o | head -n1)
cp "$obj" "$ROOT/{out}"
""".format(
                src = src.path,
                ar = ctx.file._llvm_ar.path,
                out = ctx.outputs.out.path,
            ),
            progress_message = "Extracting object from {}".format(src.path),
        )
        return [DefaultInfo(files = depset([ctx.outputs.out]))]
    if objects and len(objects) == len(ctx.files.srcs):
        src = objects[0]
        ctx.actions.symlink(
            output = ctx.outputs.out,
            target_file = src,
            progress_message = "Copying object {}".format(src.path),
        )
        return [DefaultInfo(files = depset([ctx.outputs.out]))]

    cc_tool = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_executable,
    )

    arguments = ctx.actions.args()
    arguments.add("-fuse-ld=lld")
    arguments.add(ctx.file._ld_lld, format = "--ld-path=%s")
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
        inputs = ctx.files.srcs + [ctx.file._ld_lld, ctx.file._lld],
        outputs = [ctx.outputs.out],
        arguments = [arguments],
        tools = cc_toolchain.all_files.to_list(),
        executable = cc_tool,
        execution_requirements = {
            "supports-path-mapping": "1",
            "no-local": "1",
        },
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
        "_ld_lld": attr.label(
            default = Label("//tools:ld.lld"),
            allow_single_file = True,
            cfg = "exec",
        ),
        "_lld": attr.label(
            default = Label("//tools:lld"),
            allow_single_file = True,
            cfg = "exec",
        ),
        "_llvm_ar": attr.label(
            default = Label("//tools:llvm-ar"),
            allow_single_file = True,
            cfg = "exec",
        ),
    },
    cfg = bootstrap_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
