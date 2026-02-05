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

    # Sandboxing the entire macOS SDK dramatically slows down the build process.
    # Offering a minimal sysroot allows for building basic cross platform applications.
    # Users can extend the sysroot via `osx.framework` module extension tags.

    includes = ["usr/**"]
    for framework in frameworks:
        includes.append("System/Library/Frameworks/%s.framework/**" % framework)

    # The following directories are unused, deprecated, or private headers.
    # These components:
    # - Are not part of the documented macOS SDK
    # - Belong to legacy, internal, or low-level subsystems not used in typical builds
    # - May require entitlements or special privileges to use
    excludes = [
        "usr/include/device.modulemap",
        "usr/share/**",
        "usr/libexec/**",
        # "usr/lib/log/**", # SIGNPOST ??
        "usr/lib/swift/**",
        "usr/lib/updaters/**",
        "usr/include/apache2/**",
        "usr/include/AppleArchive/**",
        "usr/include/apr-1/**",
        "usr/include/atm/**",
        "usr/include/bank/**",
        "usr/include/cups/**",
        "usr/include/default_pager/**",
        "usr/include/EndpointSecurity/**",
        "usr/include/libexslt/**",
        "usr/include/libxslt/**",
        "usr/include/net-snmp/**",
        "usr/include/netkey/**",
        "usr/include/networkext/**",
        "usr/include/pexpert/**",
        "usr/include/Spatial/**",
        "usr/include/tidy/**",
    ]

    if "IOKit" not in frameworks:
        excludes.append("usr/include/device/**")
    if "Security" not in frameworks:
        excludes.append("usr/include/libDER/**")

    http_pkg_archive(
        name = "macosx15.4.sdk",
        build_file = "//third_party/macosx.sdk:BUILD.MacOSX15.4.sdk.tpl",
        sha256 = "ba3453d62b3d2babf67f3a4a44e8073d6555c85f114856f4390a1f53bd76e24a",
        includes = ["Payload/" + i for i in includes],
        excludes = ["Payload/" + e for e in excludes],
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

