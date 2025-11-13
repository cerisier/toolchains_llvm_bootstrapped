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
    "usr/include/device/**",
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

directory(
    name = "sysroot",
    srcs = glob(["*/**"], exclude = COMMON_EXCLUDES + glob([
        "System/Library/Frameworks/Ruby.framework/**",
        "System/Cryptexes/**",
        "System/iOSSupport/**",
        "System/Library/CoreServices/**",
        "System/Library/Perl/**",
        "System/Library/PrivateFrameworks/**",
    ])),
    visibility = ["//visibility:public"],
)

# Sandboxing the entire macOS SDK dramatically slows down the build process.
# Offering a minimal sysroot allows for building basic cross platform applications.
# We may selectively add more entries to it as needed. 
directory(
    name = "sysroot-minimal",
    srcs = glob([
        # Opinionated list of frameworks for minimal macOS SDK.
        "System/Library/Frameworks/CoreFoundation.framework/**",
        "System/Library/Frameworks/Foundation.framework/**",
        "System/Library/Frameworks/Kernel.framework/**",
        "System/Library/Frameworks/OSLog.framework/**",
        "System/Library/Frameworks/Security.framework/**",
        "System/Library/Frameworks/SystemConfiguration.framework/**",

        "usr/**",
    ], exclude = COMMON_EXCLUDES),
    visibility = ["//visibility:public"],
)
