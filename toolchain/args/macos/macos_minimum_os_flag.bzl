load("@macosx15.4.sdk//sysroot:valid_deployment_targets.bzl", "MACOS_VALID_DEPLOYMENT_TARGETS")

MACOS_MINIMUM_OS_VERSIONS = MACOS_VALID_DEPLOYMENT_TARGETS

def _macos_minimum_os_flag_impl(ctx):
    value = ctx.fragments.apple.macos_minimum_os_flag
    if value == None:
        value = "14.0"
    else:
        value = str(value)

    if value not in MACOS_MINIMUM_OS_VERSIONS:
        fail("Unsupported --macos_minimum_os value '{}'. Supported values: {}".format(
            value,
            ", ".join(MACOS_MINIMUM_OS_VERSIONS),
        ))

    return [config_common.FeatureFlagInfo(value = value)]

macos_minimum_os_flag = rule(
    implementation = _macos_minimum_os_flag_impl,
    fragments = ["apple"],
)
