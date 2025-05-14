
def _libstdcxx_stubs_impl(ctx):
    target = ctx.attr.target

    version_script = ctx.actions.declare_file("build/all.map")

    output_files = [
        ctx.actions.declare_file("build/libstdc++.S"),
    ]

    args = ctx.actions.args()
    args.add("-target")
    args.add(target)
    args.add("-o")
    args.add(version_script.dirname)
    args.add(ctx.files.baseline_symbols[0].path)

    ctx.actions.run(
        executable = ctx.executable._generator,
        inputs = [ctx.files.baseline_symbols[0]],
        arguments = [args],
        outputs = output_files + [version_script],
    )
    return [
        DefaultInfo(files = depset(output_files + [version_script])),
    ]

libstdcxx_stubs_assembly_files = rule(
    implementation = _libstdcxx_stubs_impl,
    attrs = {
        "target": attr.string(
            mandatory = True,
        ),
        "_generator": attr.label(
            default = "//libc/libstdcxx:libstdcxx-stubs-generator",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
        "baseline_symbols": attr.label(
            allow_single_file = True,
        ),
    },
    doc = "Generates libstdcxx stub files for a given target.",
)
