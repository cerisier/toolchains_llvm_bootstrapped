load("@bazel_skylib//rules/directory:directory.bzl", "directory")

COMMON_EXCLUDES = [
    # The following directories are unused, deprecated, or private headers.
    # These components:
    # - Are not part of the documented macOS SDK
    # - Belong to legacy, internal, or low-level subsystems not used in typical builds
    # - May require entitlements or special privileges to use
    "usr/include/device.modulemap",
] + glob([
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
    "usr/include/libDER/**",
    "usr/include/libexslt/**",
    "usr/include/libxslt/**",
    "usr/include/net-snmp/**",
    "usr/include/netkey/**",
    "usr/include/networkext/**",
    "usr/include/pexpert/**",
    "usr/include/Spatial/**",
    "usr/include/tidy/**",
])

# Sandboxing the entire macOS SDK dramatically slows down the build process.
# Offering a minimal sysroot allows for building basic cross platform applications.
# Users can extend the sysroot via `osx.framework` module extension tags.
directory(
    name = "sysroot",
    srcs = glob([
{frameworks}

        "usr/**",
    ], exclude = COMMON_EXCLUDES),
    visibility = ["//visibility:public"],
)
