
load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("//constraints/libc:libc_versions.bzl", "GLIBC_VERSIONS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")

GLIBC_RELEASE_COMMITS = {
    "2.28": "92d25389c255b0da9b56bc05694f0702cd22921a", # release/2.28/master
    "2.29": "2417ddb64590b7197d6df15b9df67866561713e0", # release/2.29/master
    "2.30": "f8db9906d759152db9977c8774470d05a80519da", # release/2.30/master
    "2.31": "7b27c450c34563a28e634cccb399cd415e71ebfe", # release/2.31/master
    "2.32": "5ad449c398a845a9c84808e4ac603beaa1006909", # release/2.32/master
    "2.33": "5f08d1df2c07904c1dc98bdf2b363c65874266f7", # release/2.33/master
    "2.34": "26b14f335d53ce4bdaed5dbdd0e7268b8c7b5484", # release/2.34/master
    "2.35": "d2febe7c407665c18cfea1930c65f41899ab3aa3", # release/2.35/master
    "2.36": "03e0cad3a0d8cfb6e761e8e16cc09e6c96f9fd44", # release/2.36/master
    "2.37": "032545ebd3ab2248b137bc92df0bd2864031cc8b", # release/2.37/master
    "2.38": "5a08d049dc5037e89eb95bb1506652f0043fa39e", # release/2.38/master
    "2.39": "68f3f1a1d08f7f3e0fb74391461699717efbb4bc", # release/2.39/master
    "2.40": "8d3dd23e3de8b4c6e4b94f8bbfab971c3b8a55be", # release/2.40/master
    "2.41": "5cf17ebc659c875aff3c49d2a59ce15f46167389", # release/2.41/master
}

def _glibc_trampoline_repository_impl(repository_ctx):
    repository_ctx.template("BUILD.bazel", repository_ctx.attr._build_file)

_glibc_trampoline_repository = repository_rule(
    implementation = _glibc_trampoline_repository_impl,
    attrs = {
        "_build_file": attr.label(
            allow_single_file = True,
            default = ":BUILD.trampoline.tpl",
        ),
    }
)

def _glibc_impl(module_ctx):
    """glibc sources and headers extension."""

    index = {}
    for mod in module_ctx.modules:
        for index in mod.tags.index:
            file_path = module_ctx.path(index.file)
            file_content = module_ctx.read(file_path)
            index = json.decode(file_content, default = None)

    for version in GLIBC_VERSIONS:
        for (target_os, target_arch) in LIBC_SUPPORTED_TARGETS:
            target = "{}-{}-gnu".format(target_arch, target_os)
            #TODO(cerisier): Share the repository between targets
            git_repository(
                name = "glibc_%s.%s" % (target, version),
                remote = "https://sourceware.org/git/glibc.git",
                commit = GLIBC_RELEASE_COMMITS.get(version),
                build_file = "//third_party/libc/glibc:BUILD.tpl",
                patches = [
                    # This file is generated when compiling the glibc.
                    #
                    # We add it as an empty file because all the constant it
                    # normally defines are manually passed as `defines`
                    "//third_party/libc/glibc:0001-Add-empty-config.h.patch",

                    # This file is generated when compiling the glibc.
                    #
                    # It defines the ABI tag value used in the ELF note included
                    # in the startup code linked into every program.
                    #
                    # On linux, it is the same value all the time:
                    # .*-.*-linux.* 0 2.0.0 # earliest compatible kernel version
                    "//third_party/libc/glibc:0002-Add-abi-tag.h.patch",

                    # This file is generated when compiling the glibc.
                    #
                    # It defines constants and macros used during the glibc c
                    # files compilation. We can hardcode the values safely as
                    # long as every module that existed in the range of libc 
                    # we support is listed in this file with a value associated.
                    "//third_party/libc/glibc:0003-Adding-libc-modules.h.patch",
                ],
                patch_args = [
                    "-p1",
                ],
            )

            index_entry = index.get(version, {}).get(target, None)
            if index_entry == None:
                fail("Missing index entry for %s %s in index.json" % (version, target))

            repo = "glibc_headers_%s.%s" % (target, version)
            http_archive(
                name = repo,
                url = index_entry.get("url"),
                sha256 = index_entry.get("sha256"),
                strip_prefix = target,
                build_file = ":BUILD.glibc-headers.tpl",
            )

    _glibc_trampoline_repository(
        name = "glibc",
    )

    repos = ["glibc"]
    is_non_dev_dependency = module_ctx.root_module_has_non_dev_dependency
    root_direct_deps = list(repos) if is_non_dev_dependency else []
    root_direct_dev_deps = list(repos) if not is_non_dev_dependency else []

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = root_direct_deps,
        root_module_direct_dev_deps = root_direct_dev_deps,
        **metadata_kwargs
    )

glibc_index = tag_class(
    attrs = {
        "file": attr.label(
            allow_single_file = True,
            default = ":glibc_index.json",
            mandatory = True,
        ),
    }
)

glibc = module_extension(
    implementation = _glibc_impl,
    tag_classes = {
        "index": glibc_index,
    }
)
