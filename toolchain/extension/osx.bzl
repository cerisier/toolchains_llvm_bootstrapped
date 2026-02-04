load("@bazel_features//:features.bzl", "bazel_features")
load("//:http_pkg_archive.bzl", "http_pkg_archive")

# Opinionated list of frameworks for minimal macOS SDK.
_DEFAULT_FRAMEWORKS = [
    "CoreFoundation",
    "Foundation",
    "Kernel",
    "OSLog",
    "Security",
    "SystemConfiguration",
]

def _osx_extension_impl(mctx):
    frameworks = []

    for module in mctx.modules:
        for framework_tag in module.tags.framework:
            frameworks.append(framework_tag.name)

    if not frameworks:
        frameworks = _DEFAULT_FRAMEWORKS


    build_file_content = mctx.read(Label("//third_party/macosx.sdk:BUILD.MacOSX15.4.sdk.tpl"))
    build_file_content = build_file_content.replace(
        "{frameworks}",
        "\n".join(['       "System/Library/Frameworks/%s.framework/**",' % framework for framework in frameworks]))

    http_pkg_archive(
        name = "macosx15.4.sdk",
        build_file_content = build_file_content,
        sha256 = "ba3453d62b3d2babf67f3a4a44e8073d6555c85f114856f4390a1f53bd76e24a",
        strip_files = [
            "Payload/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk/System/Library/Frameworks/Ruby.framework/Versions/Current/Headers/ruby",
        ],
        strip_prefix = "Payload/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk",
        # urls = ["https://swcdn.apple.com/content/downloads/10/32/082-12052-A_AHPGDY76PT/1a419zaf3vh8o9t3c0usblyr8eystpnsh5/CLTools_macOSNMOS_SDK.pkg"],
        urls = ["https://swcdn.apple.com/content/downloads/52/01/082-41241-A_0747ZN8FHV/dectd075r63pppkkzsb75qk61s0lfee22j/CLTools_macOSNMOS_SDK.pkg"],
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return mctx.extension_metadata(**metadata_kwargs)

_framework_tag = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
    },
)

osx = module_extension(
    implementation = _osx_extension_impl,
    doc = "Generates an OSX sysroot with the requested set of frameworks (or a reasonable default)",
    tag_classes = {
        "framework": _framework_tag,
    },
)

