load("//platforms:common.bzl", "SUPPORTED_TARGETS")

def declare_config_settings():
    for (target_os, target_cpu) in SUPPORTED_TARGETS:
        native.config_setting(
            name = "{}_{}".format(target_os, target_cpu),
            constraint_values = [
                "@platforms//cpu:" + target_cpu,
                "@platforms//os:" + target_os,
            ],
            visibility = ["//visibility:public"],
        )
