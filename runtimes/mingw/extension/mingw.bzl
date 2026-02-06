load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_features//:features.bzl", "bazel_features")

def _mingw_extension_impl(module_ctx):
    """Implementation of the mingw module extension."""

    http_archive(
        name = "mingw",
        urls = ["https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v13.0.0.tar.bz2"],
        integrity = "sha256-Wv6CKvXE7b9n2q9F7sYdU49J7vaxlSTeZIl8a5WCjK8=",
        strip_prefix = "mingw-w64-v13.0.0",
        build_file = "//runtimes/mingw:mingw.BUILD.bazel",
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = ["mingw"],
        root_module_direct_dev_deps = [],
        **metadata_kwargs
    )

mingw = module_extension(
    implementation = _mingw_extension_impl,
    doc = "Extension for downloading and configuring mingw",
)
