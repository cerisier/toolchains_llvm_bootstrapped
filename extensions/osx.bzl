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
    experimental_include_all_sdk_libs = False

    for module in mctx.modules:
        for frameworks_tag in module.tags.frameworks:
            frameworks.extend(frameworks_tag.names)
        if len(module.tags.experimental_include_all_sdk_libs) > 0:
            experimental_include_all_sdk_libs = True

    if not frameworks:
        frameworks = _DEFAULT_FRAMEWORKS

    # Sandboxing the entire macOS SDK dramatically slows down the build process.
    # Offering a minimal sysroot allows for building basic cross platform applications.
    # Users can extend the sysroot via `osx.frameworks` module extension tag.

    includes = [
        "usr/include/*",
        "usr/lib/libc++*",
    ]

    if experimental_include_all_sdk_libs:
        includes.append("usr/lib/*.tbd")
    else:
        includes.extend([
            "usr/lib/libc.tbd",
            "usr/lib/libcharset*",
            "usr/lib/libdl*",
            "usr/lib/libiconv*",
            "usr/lib/libm.tbd",
            "usr/lib/libobjc*",
            "usr/lib/libresolv*",
            "usr/lib/libpthread.tbd",
            "usr/lib/libSystem*",
        ])

    for framework in frameworks:
        includes.append("System/Library/Frameworks/%s.framework/*" % framework)
        includes.append("System/Library/PrivateFrameworks/%s.framework/*" % framework)

    # The following directories are unused, deprecated, or private headers.
    # These components:
    # - Are not part of the documented macOS SDK
    # - Belong to legacy, internal, or low-level subsystems not used in typical builds
    # - May require entitlements or special privileges to use
    excludes = [
        "usr/include/device.modulemap",
        "usr/share/*",
        "usr/libexec/*",
        # "usr/lib/log/*", # SIGNPOST ??
        "usr/lib/swift/*",
        "usr/lib/updaters/*",
        "usr/include/apache2/*",
        "usr/include/AppleArchive/*",
        "usr/include/apr-1/*",
        "usr/include/atm/*",
        "usr/include/bank/*",
        "usr/include/default_pager/*",
        "usr/include/EndpointSecurity/*",
        "usr/include/libexslt/*",
        "usr/include/libxslt/*",
        "usr/include/net-snmp/*",
        "usr/include/netkey/*",
        "usr/include/networkext/*",
        "usr/include/pexpert/*",
        "usr/include/Spatial/*",
        "usr/include/tidy/*",

        # Probably not needed, saves space
        "usr/lib/log/*",
        "usr/lib/rdma/*",
        "usr/lib/system/*",
        "usr/lib/usd/*",
        "usr/lib/i18n/*",
        "usr/lib/libicucore*",

        # These are symlinks to frameworks directory, which might not be included
        "usr/lib/lib*blas*",
        "usr/lib/libclapack.tbd",
        "usr/lib/libcom_err.tbd",
        "usr/lib/libdes425.tbd",
        "usr/lib/libextension.tbd",
        "usr/lib/libf77lapack.tbd",
        "usr/lib/libgssapi_krb5.tbd",
        "usr/lib/libipconfig.tbd",
        "usr/lib/libk5crypto.tbd",
        "usr/lib/libkrb4.tbd",
        "usr/lib/libkrb5.tbd",
        "usr/lib/libkrb524.tbd",
        "usr/lib/libkrb5support.tbd",
        "usr/lib/liblapack.tbd",
        "usr/lib/liblber.tbd",
        "usr/lib/libldap*",
        "usr/lib/libnet*",
        "usr/lib/libtcl*",
        "usr/lib/libtk*",
    ]

    if "IOKit" not in frameworks:
        excludes.append("usr/include/device/*")
    if "Security" not in frameworks:
        excludes.append("usr/include/libDER/*")
    if "Tcl" not in frameworks:
        excludes.append("usr/include/tcl*")
    if "Tk" not in frameworks:
        excludes.append("usr/include/tk*")
    if "PrintCore" not in frameworks:
        excludes.append("usr/include/cups/*")

    http_pkg_archive(
        name = "macos_sdk",
        files = {
            "sysroot/BUILD.bazel": "//3rd_party/macos_sdk:CLTools_macOSNMOS_SDK.BUILD.bazel",
        },
        dst = "sysroot",
        sha256 = "466ae4667fde372ef4402fc583298bfd5fba18c96a19f628da570855538c7c67",
        includes = includes,
        excludes = excludes,
        strip_prefix = "Payload/Library/Developer/CommandLineTools/SDKs/MacOSX26.2.sdk",
        # 26.2.0
        urls = ["https://swcdn.apple.com/content/downloads/60/22/089-71960-A_W8BL1RUJJ6/5zkyplomhk1cm7z6xja2ktgapnhhti6wwd/CLTools_macOSNMOS_SDK.pkg"],
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return mctx.extension_metadata(**metadata_kwargs)

_frameworks_tag = tag_class(
    attrs = {
        "names": attr.string_list(mandatory = True),
    },
)

_experimental_include_all_sdk_libs_tag = tag_class(
    doc = "Include most usr/lib/*.tbd from the macOS SDK sysroot instead of only the minimal default set. Some libraries that are symlinks to frameworks are still excluded.",
)

osx = module_extension(
    implementation = _osx_extension_impl,
    doc = "Generates an OSX sysroot with the requested set of frameworks (or a reasonable default)",
    tag_classes = {
        "frameworks": _frameworks_tag,
        "experimental_include_all_sdk_libs": _experimental_include_all_sdk_libs_tag,
    },
)
