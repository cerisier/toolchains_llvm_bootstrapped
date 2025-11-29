load("//platforms:common.bzl", _supported_targets = "SUPPORTED_TARGETS")

def declare_config_settings():
    for (target_os, target_cpu) in _supported_targets:
        native.config_setting(
            name = "{}_{}".format(target_os, target_cpu),
            constraint_values = [
                "@platforms//cpu:" + target_cpu,
                "@platforms//os:" + target_os,
            ],
            visibility = ["//visibility:public"],
        )
