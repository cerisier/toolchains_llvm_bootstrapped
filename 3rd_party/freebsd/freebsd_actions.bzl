load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

def _collect_tool_files(target):
    info = target[DefaultInfo]
    transitive = [info.files]
    if info.default_runfiles:
        transitive.append(info.default_runfiles.files)
    return depset(transitive = transitive)

def _freebsd_generate_impl(ctx):
    substitutions = {
        "$(execpath {})".format(label.name): output.path
        for output, label in zip(ctx.outputs.outs, ctx.attr.outs)
    }
    location_targets = []
    for tool in ctx.attr.tools:
        executable = tool[DefaultInfo].files_to_run.executable
        if executable:
            substitutions["$(execpath {})".format(tool.label.name)] = executable.path
            substitutions["$(location {})".format(tool.label.name)] = executable.path
        else:
            location_targets.append(tool)

    def expand(value):
        for placeholder, path in substitutions.items():
            value = value.replace(placeholder, path)
        return ctx.expand_location(value, ctx.attr.srcs + location_targets)

    args = ctx.actions.args()
    for arg in ctx.attr.args:
        args.add(expand(arg))

    env = {}
    for name, value in ctx.attr.env.items():
        env[name] = expand(value)

    ctx.actions.run(
        executable = ctx.executable.tool,
        arguments = [args],
        inputs = ctx.files.srcs,
        tools = depset(transitive = [_collect_tool_files(tool) for tool in ctx.attr.tools]),
        outputs = ctx.outputs.outs,
        env = env,
        mnemonic = ctx.attr.mnemonic,
    )
    return [DefaultInfo(files = depset(ctx.outputs.outs))]

freebsd_generate = rule(
    implementation = _freebsd_generate_impl,
    attrs = {
        "args": attr.string_list(mandatory = True),
        "env": attr.string_dict(),
        "mnemonic": attr.string(default = "FreebsdGenerate"),
        "outs": attr.output_list(mandatory = True),
        "srcs": attr.label_list(allow_files = True),
        "tool": attr.label(cfg = "exec", executable = True, mandatory = True),
        "tools": attr.label_list(allow_files = True, cfg = "exec"),
    },
)

def _freebsd_version_script_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )
    compiler = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.preprocess_assemble,
    )
    version_script = ctx.actions.declare_file(ctx.label.name + ".map")
    preprocessed = []
    for index, symbol_map in enumerate(ctx.files.symbol_maps):
        output = ctx.actions.declare_file("{}.{}.preprocessed".format(ctx.label.name, index))
        preprocess_args = ctx.actions.args()
        preprocess_args.add_all([
            "-E",
            "-P",
            "-x",
            "c",
            "-target",
            ctx.attr.target,
        ])
        preprocess_args.add_all(ctx.attr.defines, before_each = "-D")
        preprocess_args.add(symbol_map)
        preprocess_args.add_all(["-o", output])
        ctx.actions.run(
            executable = compiler,
            arguments = [preprocess_args],
            inputs = depset(
                direct = [symbol_map],
                transitive = [cc_toolchain.all_files],
            ),
            outputs = [output],
            mnemonic = "FreebsdPreprocessSymbolMap",
            toolchain = CC_TOOLCHAIN_TYPE,
        )
        preprocessed.append(output)

    args = ctx.actions.args()
    args.add(ctx.file.version_definition)
    args.add(version_script)
    args.add_all(preprocessed)
    ctx.actions.run(
        executable = ctx.executable.generator,
        arguments = [args],
        inputs = preprocessed + [ctx.file.version_definition],
        outputs = [version_script],
        mnemonic = "FreebsdVersionScript",
    )
    return [DefaultInfo(files = depset([version_script]))]

freebsd_version_script = rule(
    implementation = _freebsd_version_script_impl,
    attrs = {
        "generator": attr.label(cfg = "exec", executable = True, mandatory = True),
        "defines": attr.string_list(),
        "symbol_maps": attr.label_list(allow_files = True, mandatory = True),
        "target": attr.string(mandatory = True),
        "version_definition": attr.label(allow_single_file = True, mandatory = True),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def freebsd_rpc_header(name, src, out):
    _freebsd_rpcgen(
        name = name,
        args = [
            "-C",
            "-h",
            "-DWANT_NFS3",
        ],
        src = src,
        out = out,
    )

def freebsd_rpc_source(name, src, out, mode):
    _freebsd_rpcgen(
        name = name,
        args = [
            "-C",
            mode,
        ],
        src = src,
        out = out,
    )

def _freebsd_rpcgen(name, src, out, args):
    freebsd_generate(
        name = name,
        tool = "@llvm//3rd_party/freebsd:rpcgen",
        tools = ["freebsd_cpp"],
        srcs = [src],
        outs = [out],
        args = args + [
            "$(location {})".format(src),
            "-o",
            "$(execpath {})".format(out),
        ],
        env = {"RPCGEN_CPP": "$(execpath freebsd_cpp) -E -x c"},
        mnemonic = "FreebsdRpcgen",
    )
