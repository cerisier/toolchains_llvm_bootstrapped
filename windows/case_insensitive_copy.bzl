"""Copies a declared directory with case-folded file basenames."""

load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo", "create_directory_info")

def _case_insensitive_copy_directory_impl(ctx):
    source = ctx.attr.src[DirectoryInfo]
    output = ctx.actions.declare_directory(ctx.label.name)
    ctx.actions.run(
        executable = ctx.executable._copy_tool,
        arguments = [
            "-source",
            source.path,
            "-output",
            output.path,
        ],
        inputs = source.transitive_files,
        outputs = [output],
        mnemonic = "WindowsCaseCopy",
        progress_message = "Case-folding Windows inputs %{label}",
    )
    directory = create_directory_info(
        entries = {},
        transitive_files = depset([output]),
        path = output.path,
        human_readable = str(ctx.label),
    )
    return [
        directory,
        DefaultInfo(files = depset([output])),
    ]

case_insensitive_copy_directory = rule(
    implementation = _case_insensitive_copy_directory_impl,
    attrs = {
        "src": attr.label(mandatory = True, providers = [DirectoryInfo]),
        "_copy_tool": attr.label(
            allow_single_file = True,
            default = "//tools/windows_case_copy",
            cfg = "exec",
            executable = True,
        ),
    },
    provides = [DirectoryInfo],
)
