MACOS_MINIMUM_OS_VERSIONS = [
    "13.0",
    "13.1",
    "13.2",
    "13.3",
    "13.4",
    "13.5",
    "13.6",
    "13.7",
    "14.0",
    "14.1",
    "14.2",
    "14.3",
    "14.4",
    "14.5",
    "14.6",
    "14.7",
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
