load("@bazel_tools//tools/build_defs/repo:utils.bzl", "patch")
load("@bazel_features//:features.bzl", "bazel_features")

def _cosmo_repo_impl(rctx):
    rctx.download_and_extract(
        url = rctx.attr.urls,
        integrity = rctx.attr.integrity,
        strip_prefix = rctx.attr.strip_prefix,
    )

    patch(rctx)

    rctx.file("BUILD.bazel", rctx.read(rctx.attr.build_file))

    replacements = {
        "#include \"third_party/intel/x86gprintrin.internal.h\"": "#if defined(__x86_64__) || defined(__i386__)\n#include \"third_party/intel/clang/x86gprintrin.h\"\n#endif",
        "#include \"third_party/intel/x86gprintrin.h\"": "#if defined(__x86_64__) || defined(__i386__)\n#include \"third_party/intel/clang/x86gprintrin.h\"\n#endif",
        "third_party/aarch64/arm_acle.internal.h": "third_party/aarch64/clang/arm_acle.h",
        "\"third_party/intel/tmmintrin.internal.h\"": "<tmmintrin.h>",
        "\"third_party/intel/emmintrin.internal.h\"": "<emmintrin.h>",
        "\"third_party/intel/smmintrin.internal.h\"": "<smmintrin.h>",
        "\"third_party/intel/xmmintrin.internal.h\"": "<xmmintrin.h>",
        "\"third_party/intel/wmmintrin.internal.h\"": "<wmmintrin.h>",
        "\"third_party/intel/immintrin.internal.h\"": "<immintrin.h>",
    }

    replace_files = [
        "third_party/zlib/adler32_simd.c",
        "third_party/zlib/chunkcopy.inc",
        "third_party/zlib/crc_folding.c",
        "third_party/zlib/crc32_simd.inc",
        "third_party/zlib/slide_hash_simd.inc",
        "third_party/zlib/insert_string.inc",
    ]

    for path in replace_files:
        content = rctx.read(path)
        for old, new in replacements.items():
            content = content.replace(old, new)
        rctx.file(path, content)


cosmo_repository = repository_rule(
    implementation = _cosmo_repo_impl,
    attrs = {
        "urls": attr.string_list(mandatory = True),
        "integrity": attr.string(),
        "strip_prefix": attr.string(),
        "build_file": attr.label(allow_single_file = True, mandatory = True),
        "patches": attr.label_list(allow_files = True, default = []),
        "patch_args": attr.string_list(),
    },
    doc = "Repository rule that fetches, extracts, patches, and prepares Cosmopolitan libc.",
)

def _cosmo_extension_impl(mctx):
    """Implementation of the cosmo module extension."""

    cosmo_repository(
        name = "cosmo_libc",
        integrity = "sha256-5GYQaxgGTgyZbvZNJhEzr4Z7zNkhrRTlSXXYmqF6hxc=",
        urls = ["https://github.com/jart/cosmopolitan/releases/download/4.0.2/cosmopolitan-4.0.2.tar.gz"],
        strip_prefix = "cosmopolitan-4.0.2",
        build_file = "//runtimes/cosmo:BUILD.tpl",
        patches = [
            "//runtimes/cosmo/patches:0001-make-pt_blkmask-atomic.patch",
            "//runtimes/cosmo/patches:0002-memchr-sse2.patch",
            "//runtimes/cosmo/patches:0003-memchr-guard-mmx-builtins.patch",
            "//runtimes/cosmo/patches:0004-musl-errno-runtime-cases.patch",
            #"//runtimes/cosmo/patches:0005-openmp-disable-mm-malloc.patch",
            "//runtimes/cosmo/patches:0006-nsync-atomic-pointer-cast.patch",
            "//runtimes/cosmo/patches:0007-musl-lookup-name-errno-runtime.patch",
            "//runtimes/cosmo/patches:0008-clang-intrin-wrappers.patch",
            #"//runtimes/cosmo/patches:0009-clang-mmintrin-vector-conversion.patch",
            "//runtimes/cosmo/patches:0010-disable-mmx-intrinsics.patch",
            # TODO(zbarsky): We should fix the header isntead!
            "//runtimes/cosmo/patches:0011-errno-no-nocallersavedregisters.patch",
            "//runtimes/cosmo/patches:0012-disable-tmmintrin-mmx.patch",
            "//runtimes/cosmo/patches:0013-tprecode8to16-conditional-neon.patch",
            #"//runtimes/cosmo/patches:0014-guard-max-align.patch",
            "//runtimes/cosmo/patches:0016-dlmalloc-atomic-loads.patch",
            #"//runtimes/cosmo/patches:0017-immintrin-include-xmmintrin.patch",
            #"//runtimes/cosmo/patches:0018-guard-avx-includes.patch",
            #"//runtimes/cosmo/patches:0019-guard-avx512vlvnni.patch",
            #"//runtimes/cosmo/patches:0020-sigblock-external-sig.patch",
            "//runtimes/cosmo/patches:0021-musl-getnameinfo-af-constants.patch",
            #"//runtimes/cosmo/patches:0022-mmintrin-internal-respect-cosmo-disable-mmx.patch",
            #"//runtimes/cosmo/patches:0023-chunkcopy-scalar-fallback.patch",
            "//runtimes/cosmo/patches:0024-sysv-aarch64-local-registers.patch",
            "//runtimes/cosmo/patches:0025-arm-neon-f16-compare.patch",
            "//runtimes/cosmo/patches:0026-arm64-clang-compat.patch",
            "//runtimes/cosmo/patches:0027-arm-neon-compare.patch",
            "//runtimes/cosmo/patches:0028-arm64-fenv-demangle.patch",
            "//runtimes/cosmo/patches:0029-brain16-clang-fallback.patch",
            "//runtimes/cosmo/patches:0030-auto-disable-mmx-when-no-builtins.patch",
            "//runtimes/cosmo/patches:0031-arm64-build-fixes.patch",
            "//runtimes/cosmo/patches:0032-demangle-jmpbuf-x86.patch",
            "//runtimes/cosmo/patches:0033-xmmintrin-sse-without-mmx.patch",
            "//runtimes/cosmo/patches:0034-guard-avx512-popcnt-builtins.patch",
            "//runtimes/cosmo/patches:0035-str-guard-arch-intrinsics.patch",
            "//runtimes/cosmo/patches:0037-pthread-arm64-setjmp-constraints.patch",
            "//runtimes/cosmo/patches:0045-rdseed-guard-nonx86.patch",
            "//runtimes/cosmo/patches:0051-ape-aarch64-balign.patch",
            #"//runtimes/cosmo/patches:0046-mmintrin-forward-decls.patch",
            #"//runtimes/cosmo/patches:0047-mmintrin-cosmo-disable-mmx.patch",
            #"//runtimes/cosmo/patches:0048-intrin-guard-clang.patch",
            #"//runtimes/cosmo/patches:0049-use-clang-intrin-when-mmx-disabled.patch",
        ],
        patch_args = ["-p1", "-l"],
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return mctx.extension_metadata(
        root_module_direct_deps = ["cosmo_libc"],
        root_module_direct_dev_deps = [],
        **metadata_kwargs
    )

cosmo = module_extension(
    implementation = _cosmo_extension_impl,
    doc = "Extension for downloading and configuring cosmo",
)
