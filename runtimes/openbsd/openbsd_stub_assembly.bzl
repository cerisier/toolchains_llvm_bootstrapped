def _openbsd_stub_assembly_impl(ctx):
    args = ctx.actions.args()
    args.add("--" + ctx.attr.format)
    args.add(ctx.outputs.out)
    args.add_all(ctx.files.srcs)

    ctx.actions.run(
        executable = ctx.executable._generator,
        inputs = ctx.files.srcs,
        outputs = [ctx.outputs.out],
        arguments = [args],
        mnemonic = "OpenbsdStubAssembly",
        execution_requirements = {"supports-path-mapping": "1"},
    )

    return DefaultInfo(files = depset([ctx.outputs.out]))

openbsd_stub_assembly = rule(
    implementation = _openbsd_stub_assembly_impl,
    attrs = {
        "format": attr.string(
            mandatory = True,
            values = ["list", "map"],
        ),
        "out": attr.output(mandatory = True),
        "srcs": attr.label_list(
            allow_files = True,
            mandatory = True,
        ),
        "_generator": attr.label(
            default = "//tools/internal:openbsd-stub-generator",
            cfg = "exec",
            executable = True,
        ),
    },
)
