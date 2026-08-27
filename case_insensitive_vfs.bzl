"""Generates a case-insensitive Clang VFS view of declared directory inputs."""

load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")

def _case_insensitive_vfs_overlay_impl(ctx):
    output = ctx.actions.declare_file(ctx.label.name + ".yaml")
    args = ctx.actions.args()
    args.add("-output", output)
    inputs = []
    for directory_target in ctx.attr.roots:
        directory = directory_target[DirectoryInfo]
        args.add("-root", directory.path)
        inputs.append(directory.transitive_files)
    if ctx.attr.use_external_names:
        args.add("-use-external-names")

    ctx.actions.run(
        executable = ctx.executable._generator,
        arguments = [args],
        inputs = depset(transitive = inputs),
        outputs = [output],
        mnemonic = "CaseInsensitiveVFS",
        progress_message = "Generating case-insensitive VFS %{label}",
    )
    return [DefaultInfo(files = depset([output]))]

case_insensitive_vfs_overlay = rule(
    implementation = _case_insensitive_vfs_overlay_impl,
    attrs = {
        "roots": attr.label_list(providers = [DirectoryInfo]),
        "use_external_names": attr.bool(
            default = False,
            doc = "Whether VFS status results expose external filesystem paths.",
        ),
        "_generator": attr.label(
            allow_single_file = True,
            default = "//tools/case_insensitive_vfs",
            cfg = "exec",
            executable = True,
        ),
    },
)
