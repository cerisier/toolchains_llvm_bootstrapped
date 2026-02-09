load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")
load("@bazel_skylib//lib:structs.bzl", "structs")

# Keep this in sync with MODULE.bazel.
LLVM_VERSION = "21.1.8"

_LLVM_RAW_ARCHIVE = struct(
    sha256 = "4633a23617fa31a3ea51242586ea7fb1da7140e426bd62fc164261fe036aa142",
    strip_prefix = "llvm-project-{LLVM_VERSION}.src".format(LLVM_VERSION = LLVM_VERSION),
    urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-{LLVM_VERSION}/llvm-project-{LLVM_VERSION}.src.tar.xz".format(LLVM_VERSION = LLVM_VERSION)],
    patch_args = ["-p1"],
    patches = [
        "//third_party/llvm-project/21.x/patches:llvm-extra.patch",
        "//third_party/llvm-project/21.x/patches:llvm-bazel9.patch",
        "//third_party/llvm-project/21.x/patches:llvm-dsymutil-corefoundation.patch",
        "//third_party/llvm-project/21.x/patches:llvm-driver-tool-order.patch",
        "//third_party/llvm-project/21.x/patches:llvm-sanitizers-ignorelists.patch",
        "//third_party/llvm-project/21.x/patches:windows_link_and_genrule.patch",
        "//third_party/llvm-project/21.x/patches:bundle_resources_no_python.patch",
        "//third_party/llvm-project/21.x/patches:no_frontend_builtin_headers.patch",
        "//third_party/llvm-project/21.x/patches:no_zlib_genrule.patch",
        "//third_party/llvm-project/21.x/patches:no_rules_python.patch",
        "//third_party/llvm-project/21.x/patches:llvm-overlay-starlark.patch",
    ],
)

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

_LLVM_RELEASE_ASSETS_SHA256 = {
    "compiler-rt": "dd54ae21aee1780fac59445b51ebff601ad016b31ac3a7de3b21126fd3ccb229",
    "libcxx": "6422a58a5c29b7f4fda224cfdc07842be8a208a61301bbba7a219116e3351809",
    "libcxxabi": "709c9a63bde1e36a80d8675becc38073b85f0fa1b4111e34542b885c9e1239da",
    "libunwind": "03e8adc6c3bdde657dcaedc94886ea70d1f7d551d622fcd8a36a8300e5c36cbc",
}

def _create_llvm_raw_repo(mctx):
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
            **structs.to_dict(_LLVM_RAW_ARCHIVE),
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

def _llvm_source_impl(mctx):
    had_override = _create_llvm_raw_repo(mctx)
    _create_support_archives()

    if had_override:
        for name in _LLVM_RELEASE_ASSETS_SHA256.keys():
            _llvm_subproject_repository(
                name = name,
                build_file = "@toolchains_llvm_bootstrapped//third_party/llvm-project/21.x/{name}:{name}.BUILD.bazel".format(name = name),
                dir = name,
            )

    else:
        for (name, sha256) in _LLVM_RELEASE_ASSETS_SHA256.items():
            http_archive(
                name = name,
                build_file = "//third_party/llvm-project/21.x/{name}:{name}.BUILD.bazel".format(name = name),
                patch_args = ["-p1"],
                patches = ["//third_party/llvm-project/21.x/libcxx:lgamma_r.patch"] if name == "libcxx" else [],
                sha256 = sha256,
                strip_prefix = "{name}-{llvm_version}.src".format(
                    name = name,
                    llvm_version = LLVM_VERSION,
                ),
                urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-{llvm_version}/{name}-{llvm_version}.src.tar.xz".format(
                    name = name,
                    llvm_version = LLVM_VERSION,
                )],
            )

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
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
        "from_path": _from_path_tag,
        "from_git": _from_git_tag,
        "from_archive": _from_archive_tag,
    },
)
