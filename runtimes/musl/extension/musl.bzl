load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_features//:features.bzl", "bazel_features")

def _musl_extension_impl(module_ctx):
    """Implementation of the musl module extension."""

    http_archive(
        name = "musl_libc",
        urls = ["https://musl.libc.org/releases/musl-1.2.5.tar.gz"],
        strip_prefix = "musl-1.2.5",
        patch_args = ["-p1"],
        patches = [
            "//3rd_party/libc/musl:1.2.5-CVE-2025-26519-1.patch",
            "//3rd_party/libc/musl:1.2.5-CVE-2025-26519-2.patch",
        ],
        integrity = "sha256-qaEYu+hNh2TaDqDSizqz+uhHf8fkCF2QECuFlvx8deQ=",
        build_file = "//3rd_party/libc/musl:musl.BUILD.bazel",
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = ["musl_libc"],
        root_module_direct_dev_deps = [],
        **metadata_kwargs
    )

musl = module_extension(
    implementation = _musl_extension_impl,
    doc = "Extension for downloading and configuring musl libc",
)
