load("@bazel_features_version//:version.bzl", "version")

def validate_static_library_compatible():
    if not version:
        return []
    if int(version.split(".", 1)[0]) >= 9:
        return []

    # Bazel 8 drops `cc_args(env = ...)` on the validate_static_library action.
    # Keep this validator integration coverage on Bazel 9+, where the tool env
    # is propagated correctly.
    return ["@platforms//:incompatible"]
