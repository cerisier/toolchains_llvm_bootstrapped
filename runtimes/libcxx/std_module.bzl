"""Build wiring for libc++'s standard-library module interface."""

def _libcxx_std_cppm_impl(ctx):
    output = ctx.actions.declare_file(ctx.attr.out_name)
    inc_files = sorted(ctx.files.inc_files, key = lambda file: file.basename)
    generated_inc_files = []
    for inc_file in inc_files:
        generated_inc_file = ctx.actions.declare_file("std/{}".format(inc_file.basename))
        ctx.actions.symlink(
            output = generated_inc_file,
            target_file = inc_file,
        )
        generated_inc_files.append(generated_inc_file)

    include_lines = [
        "#include \"std/{}\"".format(file.basename)
        for file in inc_files
    ]
    ctx.actions.expand_template(
        template = ctx.file.template,
        output = output,
        substitutions = {
            "@LIBCXX_MODULE_STD_INCLUDE_SOURCES@": "\n".join(include_lines),
        },
    )
    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(module_inc_files = depset(generated_inc_files)),
    ]

libcxx_std_cppm = rule(
    implementation = _libcxx_std_cppm_impl,
    attrs = {
        "inc_files": attr.label(
            allow_files = [".inc"],
            mandatory = True,
        ),
        "out_name": attr.string(default = "std.cppm"),
        "template": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
    },
)
