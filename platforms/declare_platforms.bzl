
load("//platforms:common.bzl", "ARCH_ALIASES", "SUPPORTED_TARGETS", "LIBC_SUPPORTED_TARGETS")
load("//constraints/libc:libc_versions.bzl", "LIBCS")

def declare_platforms():
    for (target_os, target_cpu) in SUPPORTED_TARGETS:
        native.platform(
            name = "{}_{}".format(target_os, target_cpu),
            constraint_values = [
                "@platforms//cpu:{}".format(target_cpu),
                "@platforms//os:{}".format(target_os),
                # TODO(cerisier): Use the right default glibc version for the target architecture.
                #
                # We choose 2.28 as the default which is ok because we only support
                # x86_64 and aarch64, but loongarch, risc and csky were introduced later.
                #
                # We should choose the minimum version of the glibc that supports the
                # target architecture.
                "//constraints/libc:gnu.2.28",
            ],
            visibility = ["//visibility:public"],
        )

        for alias in ARCH_ALIASES.get(target_cpu, []):
            native.platform(
                name = "{}_{}".format(target_os, alias),
                constraint_values = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                ],
                visibility = ["//visibility:public"],
            )

    declare_platforms_libc_aware()

def declare_platforms_libc_aware():
    for target_os, target_cpu in LIBC_SUPPORTED_TARGETS:
        for libc in LIBCS:
            native.platform(
                name = "{}_{}_{}".format(target_os, target_cpu, libc),
                constraint_values = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                    "//constraints/libc:{}".format(libc),
                ],
                visibility = ["//visibility:public"],
            )

            for alias in ARCH_ALIASES.get(target_cpu, []):
                native.platform(
                    name = "{}_{}_{}".format(target_os, alias, libc),
                    constraint_values = [
                        "@platforms//cpu:{}".format(target_cpu),
                        "@platforms//os:{}".format(target_os),
                        "//constraints/libc:{}".format(libc),
                    ],
                    visibility = ["//visibility:public"],
                )
