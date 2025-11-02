
"""
A rule similar to filegroup, but it ensures that only the last occurrence of each basename is kept.

It is used to compile arch specific builtins without including the generic ones.
It implies that arch specific sources are listed after the generic ones in the `srcs` attribute.
"""
def _filter_builtin_sources_impl(ctx):
    basename_to_file = {}
    for f in ctx.files.srcs:
        basename_to_file[f.basename] = f

    # Only keep the last occurrence for each basename
    unique_files = list(basename_to_file.values())

    return [
        DefaultInfo(
            files = depset(unique_files),
        )
    ]

filter_builtin_sources = rule(
    implementation = _filter_builtin_sources_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
    },
    doc = "Like filegroup, but removes duplicate basenames, keeping only the last one.",
)
