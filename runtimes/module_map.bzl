load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")
load("//:directory.bzl", "SourceDirectoryInfo")

IncludePathInfo = provider(
    "IncludePathInfo",
    fields = {
        "submodule_directories": "A depset of File objects representing directories to be included as umbrella submodules.",
        "source_submodule_directory_paths": "A list of source directory paths to be included as umbrella submodules.",
        "textual_headers": "A depset of File objects representing headers to be included as textual headers.",
    },
)

def _umbrella_submodule_path(path):
    path = paths.normalize(path).replace("//", "/")

    return """
  module "{path}" {{
    umbrella "{path}"
  }}""".format(path = path)

def _add_umbrella_submodule(args, directory):
    # Keep File values opaque to Starlark so Bazel can rewrite generated paths
    # when output-path mapping is enabled.
    args.add_all([directory], format_each = "\n  module \"%s\" {", expand_directories = False)
    args.add_all([directory], format_each = "    umbrella \"%s\"", expand_directories = False)
    args.add("  }")

def _module_map_impl(ctx):
    module_map = ctx.actions.declare_file(ctx.attr.name + ".modulemap")

    include_path_info = ctx.attr.include_path[IncludePathInfo]

    module_map_args = ctx.actions.args()
    module_map_args.set_param_file_format("multiline")
    module_map_args.add('module "crosstool" [system] {')

    for directory in include_path_info.submodule_directories.to_list():
        _add_umbrella_submodule(module_map_args, directory)

    module_map_args.add_joined(
        include_path_info.source_submodule_directory_paths,
        join_with = "\n",
        map_each = _umbrella_submodule_path,
    )

    module_map_args.add_joined(
        include_path_info.textual_headers,
        join_with = "\n",
        format_each = "  textual header \"%s\"",
        expand_directories = False,
    )

    module_map_args.add("}")

    write_kwargs = {}
    if bazel_features.rules.write_action_has_mnemonic:
        write_kwargs["mnemonic"] = "CppModuleMap"

    ctx.actions.write(
        output = module_map,
        content = module_map_args,
        **write_kwargs
    )
    return DefaultInfo(files = depset([module_map]))

module_map = rule(
    doc = """Generates a Clang module map for the toolchain and system headers.

    Source and output directories are included as umbrella submodules.
    Individual header files (typically `run_binary` outputs like in mingw) are included as textual headers.""",
    implementation = _module_map_impl,
    attrs = {
        "include_path": attr.label(
            providers = [IncludePathInfo],
            mandatory = True,
        ),
    },
)

def _include_path_impl(ctx):
    submodule_directories = []
    source_submodule_directory_paths = []
    textual_headers_depsets = []

    for src in ctx.attr.srcs:
        if SourceDirectoryInfo in src or DirectoryInfo not in src:
            # We're either a source directory or an output directory (Tree Artifact).
            submodule_directories.append(src[DefaultInfo].files)
        else:
            textual_headers_depsets.append(src[DirectoryInfo].transitive_files)

    for directory in ctx.attr.umbrella_directories:
        path = directory[DirectoryInfo].path
        if path.startswith("bazel-out/"):
            fail("Generated umbrella directory {} must be passed through srcs as a File-backed target so Bazel can apply output-path mapping.".format(directory.label))
        source_submodule_directory_paths.append(path)

    return [
        IncludePathInfo(
            submodule_directories = depset([], transitive = submodule_directories),
            source_submodule_directory_paths = source_submodule_directory_paths,
            textual_headers = depset([], transitive = textual_headers_depsets),
        ),
    ]

include_path = rule(
    implementation = _include_path_impl,
    attrs = {
        "umbrella_directories": attr.label_list(providers = [DirectoryInfo]),
        "srcs": attr.label_list(),
    },
)
