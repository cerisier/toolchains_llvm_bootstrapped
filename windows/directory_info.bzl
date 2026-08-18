"""Adapts a single declared directory artifact to DirectoryInfo."""

load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo", "create_directory_info")

def _directory_info_impl(ctx):
    files = ctx.attr.src[DefaultInfo].files.to_list()
    if len(files) != 1 or not files[0].is_directory:
        fail("directory_info requires exactly one directory artifact")
    directory = files[0]
    return [
        create_directory_info(
            entries = {},
            human_readable = str(ctx.label),
            path = directory.path,
            transitive_files = depset([directory]),
        ),
        DefaultInfo(files = depset([directory])),
    ]

directory_info = rule(
    implementation = _directory_info_impl,
    attrs = {"src": attr.label(mandatory = True)},
    provides = [DirectoryInfo],
)

def _validated_directory_info_impl(ctx):
    directory = ctx.attr.src[DirectoryInfo]
    if not directory.path.endswith(ctx.attr.expected_path_suffix):
        fail(
            ("%s requires %s, but the selected repository provides %s; " +
             "do not override the Phase 0-pinned Microsoft payload version") % (
                ctx.label,
                ctx.attr.expected_path_suffix,
                directory.path,
            ),
        )
    return [
        directory,
        DefaultInfo(files = directory.transitive_files),
    ]

validated_directory_info = rule(
    implementation = _validated_directory_info_impl,
    attrs = {
        "expected_path_suffix": attr.string(mandatory = True),
        "src": attr.label(mandatory = True, providers = [DirectoryInfo]),
    },
    provides = [DirectoryInfo],
)
