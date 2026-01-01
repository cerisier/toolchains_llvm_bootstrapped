load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_features//:features.bzl", "bazel_features")

def _cosmo_extension_impl(module_ctx):
    """Implementation of the cosmo module extension."""

    http_archive(
        name = "cosmo_libc",
        integrity = "sha256-5GYQaxgGTgyZbvZNJhEzr4Z7zNkhrRTlSXXYmqF6hxc=",
        urls = ["https://github.com/jart/cosmopolitan/releases/download/4.0.2/cosmopolitan-4.0.2.tar.gz"],
        strip_prefix = "cosmopolitan-4.0.2",
        build_file = "//runtimes/cosmo:BUILD.tpl",
        patches = [
            #"//runtimes/cosmo/patches:0001-make-pt_blkmask-atomic.patch",
            #"//runtimes/cosmo/patches:0002-memchr-sse2.patch",
            #"//runtimes/cosmo/patches:0003-memchr-guard-mmx-builtins.patch",
            #"//runtimes/cosmo/patches:0004-musl-errno-runtime-cases.patch",
            #"//runtimes/cosmo/patches:0005-openmp-disable-mm-malloc.patch",
            #"//runtimes/cosmo/patches:0006-nsync-atomic-pointer-cast.patch",
            #"//runtimes/cosmo/patches:0007-musl-lookup-name-errno-runtime.patch",
            #"//runtimes/cosmo/patches:0008-clang-intrin-wrappers.patch",
            #"//runtimes/cosmo/patches:0009-clang-mmintrin-vector-conversion.patch",
            #"//runtimes/cosmo/patches:0010-disable-mmx-intrinsics.patch",
            #"//runtimes/cosmo/patches:0011-errno-no-nocallersavedregisters.patch",
            #"//runtimes/cosmo/patches:0012-disable-tmmintrin-mmx.patch",
            #"//runtimes/cosmo/patches:0013-tprecode8to16-conditional-neon.patch",
            #"//runtimes/cosmo/patches:0014-guard-max-align.patch",
            #"//runtimes/cosmo/patches:0016-dlmalloc-atomic-loads.patch",
            #"//runtimes/cosmo/patches:0017-immintrin-include-xmmintrin.patch",
            #"//runtimes/cosmo/patches:0018-guard-avx-includes.patch",
            #"//runtimes/cosmo/patches:0019-guard-avx512vlvnni.patch",
            #"//runtimes/cosmo/patches:0020-sigblock-external-sig.patch",
            #"//runtimes/cosmo/patches:0021-musl-getnameinfo-af-constants.patch",
            #"//runtimes/cosmo/patches:0022-mmintrin-internal-respect-cosmo-disable-mmx.patch",
            #"//runtimes/cosmo/patches:0023-chunkcopy-scalar-fallback.patch",
            #"//runtimes/cosmo/patches:0024-sysv-aarch64-local-registers.patch",
            #"//runtimes/cosmo/patches:0025-arm-neon-f16-compare.patch",
            #"//runtimes/cosmo/patches:0026-arm64-clang-compat.patch",
            #"//runtimes/cosmo/patches:0027-arm-neon-compare.patch",
            #"//runtimes/cosmo/patches:0028-arm64-fenv-demangle.patch",
        ],
        patch_args = ["-p1", "-l"],
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = ["cosmo_libc"],
        root_module_direct_dev_deps = [],
        **metadata_kwargs
    )

cosmo = module_extension(
    implementation = _cosmo_extension_impl,
    doc = "Extension for downloading and configuring cosmo",
)
