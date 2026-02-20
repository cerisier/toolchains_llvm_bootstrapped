load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _picolibc_extension_impl(module_ctx):
    """Implementation of the picolibc module extension."""

    http_archive(
        name = "picolibc",
        urls = ["https://github.com/picolibc/picolibc/archive/refs/tags/1.8.11.tar.gz"],
        strip_prefix = "picolibc-1.8.11",
        integrity = "sha256-KOYKLSGNpwxxJ4cIiHrcXssIQ+0xV53LaR6C11Z8ID8=",
        build_file = "//3rd_party/libc/picolibc:picolibc.BUILD.bazel",
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = ["picolibc"],
        root_module_direct_dev_deps = [],
        **metadata_kwargs
    )

picolibc = module_extension(
    implementation = _picolibc_extension_impl,
    doc = "Extension for downloading and configuring picolibc",
)
