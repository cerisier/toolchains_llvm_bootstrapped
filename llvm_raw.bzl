load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

LLVM_VERSION = "21.1.7"

def _llvm_raw_impl(mctx):
    http_archive(
        name = "llvm-raw",
        build_file_content = "# EMPTY",
        sha256 = "e5b65fd79c95c343bb584127114cb2d252306c1ada1e057899b6aacdd445899e",
        patch_args = ["-p1"],
        patches = [
            "//third_party/llvm-project:llvm-extra.patch",
            "//third_party/llvm-project:llvm-bazel9.patch",
            "//third_party/llvm-project:llvm-sanitizers-ignorelists.patch",
            "//third_party/llvm-project:windows_link_and_genrule.patch",
            "//third_party/llvm-project:bundle_resources_no_python.patch",
            "//third_party/llvm-project:no_frontend_builtin_headers.patch",
            "//third_party/llvm-project:no_zlib_genrule.patch",
            "//third_party/llvm-project:no_rules_python.patch",
        ],
        strip_prefix = "llvm-project-{LLVM_VERSION}.src".format(LLVM_VERSION = LLVM_VERSION),
        urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-{LLVM_VERSION}/llvm-project-{LLVM_VERSION}.src.tar.xz".format(LLVM_VERSION = LLVM_VERSION)],
    )

    http_archive(
        name = "llvm_zlib",
        build_file = "@llvm-raw//utils/bazel/third_party_build:zlib-ng.BUILD",
        sha256 = "e36bb346c00472a1f9ff2a0a4643e590a254be6379da7cddd9daeb9a7f296731",
        strip_prefix = "zlib-ng-2.0.7",
        urls = ["https://github.com/zlib-ng/zlib-ng/archive/refs/tags/2.0.7.zip"],
    )

    http_archive(
        name = "llvm_zstd",
        build_file = "@llvm-raw//utils/bazel/third_party_build:zstd.BUILD",
        sha256 = "7c42d56fac126929a6a85dbc73ff1db2411d04f104fae9bdea51305663a83fd0",
        strip_prefix = "zstd-1.5.2",
        urls = ["https://github.com/facebook/zstd/releases/download/v1.5.2/zstd-1.5.2.tar.gz"],
    )

    # http_archive(
    #     name = "vulkan_headers",
    #     build_file = "@llvm-raw//utils/bazel/third_party_build:vulkan_headers.BUILD",
    #     sha256 = "19f491784ef0bc73caff877d11c96a48b946b5a1c805079d9006e3fbaa5c1895",
    #     strip_prefix = "Vulkan-Headers-9bd3f561bcee3f01d22912de10bb07ce4e23d378",
    #     urls = ["https://github.com/KhronosGroup/Vulkan-Headers/archive/9bd3f561bcee3f01d22912de10bb07ce4e23d378.tar.gz"],
    # )

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
    )

llvm_raw = module_extension(
    implementation = _llvm_raw_impl,
)
