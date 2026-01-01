load("//platforms:common.bzl", "SUPPORTED_TARGETS", "LIBC_SUPPORTED_TARGETS", "COSMO_SUPPORTED_CPUS")
load("@bazel_skylib//lib:selects.bzl", "selects")
load("//constraints/libc:libc_versions.bzl", "LIBCS", "GLIBCS")

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

    declare_config_settings_libc_aware()

def declare_config_settings_libc_aware():
    # Linux supports multiple libc implementations (glibc, musl).
    for (target_os, target_cpu) in LIBC_SUPPORTED_TARGETS:
        for libc in ["musl"] + GLIBCS + ["unconstrained"]:
            native.config_setting(
                name = "{}_{}_{}".format(target_os, target_cpu, libc),
                constraint_values = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                    "//constraints/libc:{}".format(libc),
                ],
                visibility = ["//visibility:public"],
            )

        selects.config_setting_group(
            name = "{}_{}_gnu".format(target_os, target_cpu),
            match_all = [
                "@platforms//cpu:{}".format(target_cpu),
                "@platforms//os:{}".format(target_os),
                ":gnu",
            ],
            visibility = ["//visibility:public"],
        )

    # Cosmopolitan targets CPU only (no OS constraint).
    for target_cpu in COSMO_SUPPORTED_CPUS:
        native.config_setting(
            name = "cosmo_{}".format(target_cpu),
            constraint_values = [
                "@platforms//cpu:{}".format(target_cpu),
                "//constraints/libc:cosmo",
            ],
            visibility = ["//visibility:public"],
        )

    # Legacy names with OS prefixes for compatibility with existing selects.
    for target_os, target_cpu in SUPPORTED_TARGETS:
        native.config_setting(
            name = "{}_{}_cosmo".format(target_os, target_cpu),
            constraint_values = [
                "@platforms//cpu:{}".format(target_cpu),
                "//constraints/libc:cosmo",
            ],
            visibility = ["//visibility:public"],
        )

    selects.config_setting_group(
        name = "gnu",
        match_any = [
            "//constraints/libc:{}".format(libc) for libc in GLIBCS
        ] + [
            "{}_{}_unconstrained".format(target_os, target_cpu)
            for (target_os, target_cpu) in LIBC_SUPPORTED_TARGETS
        ],
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "musl",
        constraint_values = [
            "//constraints/libc:musl",
        ],
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "cosmo",
        constraint_values = [
            "//constraints/libc:cosmo",
        ],
        visibility = ["//visibility:public"],
    )
