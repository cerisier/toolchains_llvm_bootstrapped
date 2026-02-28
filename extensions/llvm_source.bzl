load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")
load("@bazel_skylib//lib:structs.bzl", "structs")

# Keep this in sync with MODULE.bazel.
DEFAULT_LLVM_VERSION = "21.1.8"

_DEFAULT_SOURCE_PATCHES = [
    "//3rd_party/llvm-project/21.x/patches:llvm-extra.patch",
    "//3rd_party/llvm-project/21.x/patches:clang-prepend-arg-reexec.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-sanitizers-ignorelists.patch",
    "//3rd_party/llvm-project/21.x/patches:no_frontend_builtin_headers.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-bzl-library.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-driver-tool-order.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-dsymutil-corefoundation.patch",
]

_LLVM_21_SOURCE_PATCHES = _DEFAULT_SOURCE_PATCHES + [
    "//3rd_party/llvm-project/21.x/patches:llvm-bazel9.patch",
    "//3rd_party/llvm-project/21.x/patches:windows_link_and_genrule.patch",
    "//3rd_party/llvm-project/21.x/patches:bundle_resources_no_python.patch",
    "//3rd_party/llvm-project/21.x/patches:no_zlib_genrule.patch",
    "//3rd_party/llvm-project/21.x/patches:no_rules_python.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-overlay-starlark.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-windows-stack-size.patch",
    "//3rd_party/llvm-project/21.x/patches:compiler-rt-symbolizer_skip_cxa_atexit.patch",
    "//3rd_party/llvm-project/21.x/patches:libcxx-lgamma_r.patch",
]

_LLVM_22_SOURCE_PATCHES = _DEFAULT_SOURCE_PATCHES + [
    "//3rd_party/llvm-project/22.x/patches:no_rules_python.patch",
]


_LLVM_SUPPORT_ARCHIVES = {
    "llvm_zlib": struct(
        build_file = "@llvm-raw//utils/bazel/third_party_build:zlib-ng.BUILD",
        sha256 = "e36bb346c00472a1f9ff2a0a4643e590a254be6379da7cddd9daeb9a7f296731",
        strip_prefix = "zlib-ng-2.0.7",
        urls = ["https://github.com/zlib-ng/zlib-ng/archive/refs/tags/2.0.7.zip"],
    ),
    "llvm_zstd": struct(
        build_file = "@llvm-raw//utils/bazel/third_party_build:zstd.BUILD",
        sha256 = "7c42d56fac126929a6a85dbc73ff1db2411d04f104fae9bdea51305663a83fd0",
        strip_prefix = "zstd-1.5.2",
        urls = ["https://github.com/facebook/zstd/releases/download/v1.5.2/zstd-1.5.2.tar.gz"],
    ),
}

_LLVM_VERSIONS = {
    "21.1.8": struct(
        build_defs_version = "21.x",
        source_archive = struct(
            sha256 = "4633a23617fa31a3ea51242586ea7fb1da7140e426bd62fc164261fe036aa142",
            strip_prefix = "llvm-project-21.1.8.src",
            urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-21.1.8/llvm-project-21.1.8.src.tar.xz"],
            patch_args = ["-p1"],
            patches = _LLVM_21_SOURCE_PATCHES,
        ),
    ),
    "22.1.0": struct(
        build_defs_version = "21.x",
        source_archive = struct(
            sha256 = "25d2e2adc4356d758405dd885fcfd6447bce82a90eb78b6b87ce0934bd077173",
            strip_prefix = "llvm-project-22.1.0.src",
            urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.0/llvm-project-22.1.0.src.tar.xz"],
            patch_args = ["-p1"],
            patches = _LLVM_22_SOURCE_PATCHES,
        ),
    ),
}

def _create_llvm_raw_repo(mctx, version_config):
    had_override = False

    for module in mctx.modules:
        for tag in module.tags.from_path:
            if had_override:
                fail("Only 1 LLVM override is allowed currently!")
            had_override = True
            new_local_repository(
                name = "llvm-raw",
                build_file_content = "# EMPTY",
                path = tag.path,
            )

        for tag in module.tags.from_git:
            if had_override:
                fail("Only 1 LLVM override is allowed currently!")
            had_override = True
            git_repository(name = "llvm-raw", **structs.to_dict(tag))

        for tag in module.tags.from_archive:
            if had_override:
                fail("Only 1 LLVM override is allowed currently!")
            had_override = True

            http_archive(name = "llvm-raw", **structs.to_dict(tag))

    if not had_override:
        http_archive(
            name = "llvm-raw",
            build_file_content = "# EMPTY",
            **structs.to_dict(version_config.source_archive),
        )

    return had_override

def _create_support_archives():
    for name, params in _LLVM_SUPPORT_ARCHIVES.items():
        http_archive(
            name = name,
            build_file = params.build_file,
            sha256 = params.sha256,
            strip_prefix = params.strip_prefix,
            urls = params.urls,
        )

def _llvm_subproject_repository_impl(rctx):
    llvm_root = rctx.path(Label("@llvm-raw//:WORKSPACE")).dirname
    src_dir = llvm_root.get_child(rctx.attr.dir)

    for entry in src_dir.readdir():
        rctx.symlink(entry, entry.basename)

    rctx.file("BUILD.bazel", rctx.read(rctx.attr.build_file))
    return rctx.repo_metadata(reproducible = True)

_llvm_subproject_repository = repository_rule(
    implementation = _llvm_subproject_repository_impl,
    attrs = {
        "build_file": attr.label(allow_single_file = True),
        "dir": attr.string(mandatory = True),
    },
)

def _runtime_build_file(version_config, name, label_repo_prefix):
    return "{repo}//3rd_party/llvm-project/{version}/{name}:{name}.BUILD.bazel".format(
        repo = label_repo_prefix,
        name = name,
        version = version_config.build_defs_version,
    )

def _create_runtime_repositories(version_config, had_override):
    build_label_repo_prefix = "@llvm" if had_override else ""

    for name in ["compiler-rt", "libcxx", "libcxxabi", "libunwind"]:
        _llvm_subproject_repository(
            name = name,
            build_file = _runtime_build_file(version_config, name, build_label_repo_prefix),
            dir = name,
        )

def _get_llvm_version(mctx):
    llvm_version = DEFAULT_LLVM_VERSION
    module_selected_version = None

    for mod in mctx.modules:
        module_versions = [tag.llvm_version for tag in mod.tags.version]
        if len(module_versions) > 1:
            fail("Only 1 llvm_source.version(...) tag is allowed per module")

        if not module_versions:
            continue

        if getattr(mod, "is_root", False):
            return module_versions[0]

        module_selected_version = module_versions[0]

    if module_selected_version != None:
        return module_selected_version

    return llvm_version

def _llvm_source_impl(mctx):
    llvm_version = _get_llvm_version(mctx)
    version_config = _LLVM_VERSIONS.get(llvm_version)
    if version_config == None:
        fail("Unsupported LLVM version '{}'. Supported versions: {}".format(llvm_version, ", ".join(sorted(_LLVM_VERSIONS.keys()))))

    had_override = _create_llvm_raw_repo(mctx, version_config)
    _create_support_archives()
    _create_runtime_repositories(version_config, had_override)

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
    )

_version_tag = tag_class(
    attrs = {
        "llvm_version": attr.string(mandatory = True),
    },
)

_from_path_tag = tag_class(
    attrs = {
        "path": attr.string(mandatory = True),
    },
)

_from_git_tag = tag_class(
    attrs = {
        "remote": attr.string(mandatory = True),
        "commit": attr.string(default = ""),
        "tag": attr.string(default = ""),
        "branch": attr.string(default = ""),
        "shallow_since": attr.string(default = ""),
        "init_submodules": attr.bool(default = False),
        "recursive_init_submodules": attr.bool(default = False),
        "strip_prefix": attr.string(default = ""),
        "patches": attr.label_list(default = []),
        "patch_args": attr.string_list(default = ["-p0"]),
        "patch_cmds": attr.string_list(default = []),
        "patch_cmds_win": attr.string_list(default = []),
        "patch_tool": attr.string(default = ""),
        "build_file": attr.label(allow_single_file = True),
        "build_file_content": attr.string(default = ""),
        "workspace_file": attr.label(),
        "workspace_file_content": attr.string(default = ""),
        "verbose": attr.bool(default = False),
    },
)

_from_archive_tag = tag_class(
    attrs = {
        "url": attr.string(default = ""),
        "urls": attr.string_list(default = []),
        "sha256": attr.string(default = ""),
        "integrity": attr.string(default = ""),
        "strip_prefix": attr.string(default = ""),
        "type": attr.string(default = ""),
        "patches": attr.label_list(default = []),
        "patch_args": attr.string_list(default = ["-p0"]),
        "patch_cmds": attr.string_list(default = []),
        "patch_cmds_win": attr.string_list(default = []),
        "patch_tool": attr.string(default = ""),
        "build_file": attr.label(allow_single_file = True),
        "build_file_content": attr.string(default = ""),
        "workspace_file": attr.label(),
        "workspace_file_content": attr.string(default = ""),
        "canonical_id": attr.string(default = ""),
        "remote_file_urls": attr.string_list_dict(default = {}),
        "remote_file_integrity": attr.string_dict(default = {}),
        "remote_patches": attr.string_dict(default = {}),
        "remote_patch_strip": attr.int(default = 0),
    },
)

llvm_source = module_extension(
    implementation = _llvm_source_impl,
    tag_classes = {
        "version": _version_tag,
        "from_path": _from_path_tag,
        "from_git": _from_git_tag,
        "from_archive": _from_archive_tag,
    },
)
