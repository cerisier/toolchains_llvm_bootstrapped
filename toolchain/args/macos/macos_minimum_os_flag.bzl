# cat <path_to_sdk>/SDKSettings.json | jq .SupportedTargets.macosx.ValidDeploymentTargets
MACOS_MINIMUM_OS_VERSIONS = [
    "10.13",
    "10.14",
    "10.15",
    "11.0",
    "11.1",
    "11.2",
    "11.3",
    "11.4",
    "11.5",
    "12.0",
    "12.2",
    "12.3",
    "12.4",
    "13.0",
    "13.1",
    "13.2",
    "13.3",
    "13.4",
    "13.5",
    "14.0",
    "14.1",
    "14.2",
    "14.3",
    "14.4",
    "14.5",
    "14.6",
    "15.0",
    "15.1",
    "15.2",
    "15.3",
    "15.4",
    #TODO(cerisier): Update the macOS SDK.
    # "15.5",
    # "15.6",
    # "26.0",
    # "26.1",
]

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
