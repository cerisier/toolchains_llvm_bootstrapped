
def _glibc_stubs_impl(ctx):
    target = ctx.attr.target

    version_script = ctx.actions.declare_file("build/all.map")

    output_files = [
        ctx.actions.declare_file("build/c.s"),
        ctx.actions.declare_file("build/dl.s"),
        ctx.actions.declare_file("build/ld.s"),
        ctx.actions.declare_file("build/m.s"),
        ctx.actions.declare_file("build/pthread.s"),
        ctx.actions.declare_file("build/resolv.s"),
        ctx.actions.declare_file("build/rt.s"),
        ctx.actions.declare_file("build/util.s"),
    ]

    args = ctx.actions.args()
    args.add("-target")
    args.add(target)
    args.add("-o")
    args.add(version_script.dirname)
    args.add(ctx.files.abilist[0].path)

    ctx.actions.run(
        executable = ctx.executable._generator,
        inputs = [ctx.files.abilist[0]],
        arguments = [args],
        outputs = output_files + [version_script],
    )
    return [
        DefaultInfo(files = depset(output_files + [version_script])),
    ]

glibc_stubs_assembly_files = rule(
    implementation = _glibc_stubs_impl,
    attrs = {
        "target": attr.string(
            mandatory = True,
        ),
        "_generator": attr.label(
            default = "//runtimes/glibc:glibc-stubs-generator",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
        "abilist": attr.label(
            allow_single_file = True,
        ),
    },
    doc = "Generates glibc stub files for a given target.",
)
