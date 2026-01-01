
load("//platforms:common.bzl", "ARCH_ALIASES", "SUPPORTED_TARGETS", "LIBC_SUPPORTED_TARGETS", "COSMO_SUPPORTED_CPUS")
load("//constraints/libc:libc_versions.bzl", "LIBCS", "GLIBCS", "DEFAULT_LIBC")

def declare_platforms():
    for (target_os, target_cpu) in SUPPORTED_TARGETS:

        constraints = [
            "@platforms//cpu:{}".format(target_cpu),
            "@platforms//os:{}".format(target_os),
        ]

        if target_os == "linux":
            # We add a default glibc constraint for linux platforms.
            #
            # This is needed because some toolchains require a libc constraint
            # to be present on the platform in order to select the right
            # toolchain implementation.
            #
            # Users can still create their own platforms without a libc
            # constraint if they want to.
            constraints.append("//constraints/libc:{}".format(DEFAULT_LIBC))

        for alias in [target_cpu] + ARCH_ALIASES.get(target_cpu, []):
            native.platform(
                name = "{}_{}".format(target_os, alias),
                constraint_values = constraints,
                visibility = ["//visibility:public"],
            )

    declare_platforms_libc_aware()

def declare_platforms_libc_aware():
    # Linux supports glibc/musl variants.
    for target_os, target_cpu in LIBC_SUPPORTED_TARGETS:
        for libc in GLIBCS + ["musl"]:
            for alias in [target_cpu] + ARCH_ALIASES.get(target_cpu, []):
                native.platform(
                    name = "{}_{}_{}".format(target_os, alias, libc),
                    constraint_values = [
                        "@platforms//cpu:{}".format(target_cpu),
                        "@platforms//os:{}".format(target_os),
                        "//constraints/libc:{}".format(libc),
                    ],
                    visibility = ["//visibility:public"],
                )

    # Cosmopolitan targets CPU only (no OS constraint).
    for target_cpu in COSMO_SUPPORTED_CPUS:
        for alias in [target_cpu] + ARCH_ALIASES.get(target_cpu, []):
            native.platform(
                name = "cosmo_{}".format(alias),
                constraint_values = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "//constraints/libc:cosmo",
                ],
                visibility = ["//visibility:public"],
            )
