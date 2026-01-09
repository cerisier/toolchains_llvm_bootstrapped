load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _msvc_extension_impl(module_ctx):
    """Implementation of the msvc module extension."""

    # Download default Microsoft Windows SDK (headers)
    http_archive(
        name = "windows_sdk",
        urls = ["https://globalcdn.nuget.org/packages/microsoft.windows.sdk.cpp.10.0.22621.3233.nupkg"],
        integrity = "sha256-5O/hdo6mH0+Znb72GwmJUyBin5dfnO7YKQqWM+DDFiM=",
        build_file = "//runtimes/msvc:BUILD_windows_sdk_common.tpl",
    )
    http_archive(
        name = "windows_sdk_arm64",
        urls = ["https://globalcdn.nuget.org/packages/microsoft.windows.sdk.cpp.arm64.10.0.22621.3233.nupkg"],
        integrity = "sha256-YQrGXNYmz0X0z/HQ1uR9ri3bR2Y+6GgP3LfejQRbihk=",
        build_file = "//runtimes/msvc:BUILD_windows_sdk.tpl",
    )
    http_archive(
        name = "windows_sdk_x64",
        urls = ["https://globalcdn.nuget.org/packages/microsoft.windows.sdk.cpp.x64.10.0.22621.3233.nupkg"],
        integrity = "sha256-+Edc+GVHY91dXbBQuZeI7zzq5ENqL7qP5Oo7Aixlbhk=",
        build_file = "//runtimes/msvc:BUILD_windows_sdk.tpl",
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = ["windows_sdk", "windows_sdk_arm64", "windows_sdk_x64"],
        root_module_direct_dev_deps = [],
        **metadata_kwargs
    )

msvc = module_extension(
    implementation = _msvc_extension_impl,
    tag_classes = {
        # TODO: add possibility to wire a user-packaged MSVC runtime via Label/url
        # "runtime": _msvc_runtime,
    },
    doc = "Extension for downloading and configuring MSVC",
)
