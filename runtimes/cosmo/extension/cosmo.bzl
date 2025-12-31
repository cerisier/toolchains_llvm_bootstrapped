load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_features//:features.bzl", "bazel_features")

def _cosmo_extension_impl(module_ctx):
    """Implementation of the cosmo module extension."""

    http_archive(
        name = "cosmo_libc",
        urls = ["https://github.com/jart/cosmopolitan/releases/download/4.0.2/cosmopolitan-4.0.2.tar.gz"],
        strip_prefix = "cosmopolitan-4.0.2",
        build_file = "//runtimes/cosmo:BUILD.tpl",
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = ["cosmo"],
        root_module_direct_dev_deps = [],
        **metadata_kwargs
    )

cosmo = module_extension(
    implementation = _cosmo_extension_impl,
    doc = "Extension for downloading and configuring cosmo",
)
