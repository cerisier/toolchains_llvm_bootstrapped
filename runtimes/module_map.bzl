load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")
load("//:directory.bzl", "SourceDirectoryInfo")

IncludePathInfo = provider()

def _textual_header(file, *, execroot_prefix):
    return "  textual header \"{}{}\"".format(execroot_prefix, file.path)

def _umbrella_submodule(directory, *, execroot_prefix):
    path = execroot_prefix + paths.normalize(directory.path).replace("//", "/")

    return """
  module "{path}" {{
    umbrella "{path}"
  }}""".format(path = path)

def _module_map_impl(ctx):
    module_map = ctx.actions.declare_file(ctx.attr.name + ".modulemap")

    # The builtin include directories are relative to the execroot, but the
    # paths in the module map must be relative to the directory that contains
    # the module map.
    execroot_prefix = (module_map.dirname.count("/") + 1) * "../"
    include_path_info = ctx.attr.include_path[IncludePathInfo]

    template_dict = ctx.actions.template_dict()

    template_dict.add_joined(
        "%submodules%",
        include_path_info.submodule_directories,
        join_with = "\n",
        map_each = lambda directory: _umbrella_submodule(directory, execroot_prefix = execroot_prefix),
        allow_closure = True,
    )

    template_dict.add_joined(
        "%textual_headers%",
        include_path_info.textual_headers,
        join_with = "\n",
        map_each = lambda file: _textual_header(file, execroot_prefix = execroot_prefix),
        allow_closure = True,
    )

    ctx.actions.expand_template(
        template = ctx.file._module_map_template,
        output = module_map,
        computed_substitutions = template_dict,
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
        "_module_map_template": attr.label(
            default = "//runtimes:module_map.BUILD.bazel",
            allow_single_file = True,
        ),
    },
)

def _include_path_impl(ctx):
    submodule_directories = []
    textual_headers_depsets = []

    for src in ctx.attr.srcs:
        if SourceDirectoryInfo in src or DirectoryInfo not in src:
            # We're either a source directory or an output directory (Tree Artifact).
            submodule_directories.append(src[DefaultInfo].files)
        else:
            textual_headers_depsets.append(src[DirectoryInfo].transitive_files)

    return [
        IncludePathInfo(
            submodule_directories = depset([], transitive = submodule_directories),
            textual_headers = depset([], transitive = textual_headers_depsets),
        ),
    ]


include_path = rule(
    implementation = _include_path_impl,
    attrs = {
        "srcs": attr.label_list()
    },
)
