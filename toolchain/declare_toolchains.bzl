load("//platforms:common.bzl", "SUPPORTED_EXECS", "SUPPORTED_TARGETS")
load("//toolchain:selects.bzl", "msvc_resource_dir_arg", "platform_cc_tool_map", "platform_module_map", "resource_dir_arg")
load(":cc_toolchain.bzl", "cc_toolchain")

def declare_toolchains(*, execs = SUPPORTED_EXECS, targets = SUPPORTED_TARGETS):
    """Declares the configured LLVM toolchains.

    Args:
        execs: List of (os, arch) tuples describing exec platforms.
        targets: List of (os, arch) tuples describing target platforms.
    """
    for (exec_os, exec_cpu) in execs:
        cc_toolchain_name = "{}_{}_cc_toolchain".format(exec_os, exec_cpu)

        # Even though `tool_map` has an exec transition, Bazel doesn't properly handle
        # binding a single `cc_toolchain` to multiple toolchains with different `exec_compatible_with`.
        # See https://github.com/bazelbuild/rules_cc/issues/299#issuecomment-2660340534
        cc_toolchain(
            name = cc_toolchain_name,
            tool_map = platform_cc_tool_map(exec_os, exec_cpu),
            module_map = platform_module_map(exec_os, exec_cpu),
            extra_args = select({
                "@llvm//platforms/config:windows_x86_64_msvc": [msvc_resource_dir_arg(exec_os, exec_cpu)],
                "@llvm//platforms/config:windows_aarch64_msvc": [msvc_resource_dir_arg(exec_os, exec_cpu)],
                "//conditions:default": [resource_dir_arg(exec_os, exec_cpu)],
            }),
        )

        for (target_os, target_cpu) in targets:
            target_settings = ["@llvm//toolchain:bootstrap_stage0_prebuilt_seed"]
            if target_os == "windows":
                target_settings.append("@llvm//platforms/config:windows_{}_mingw_compatible".format(target_cpu))

            native.toolchain(
                name = "{}_{}_to_{}_{}".format(exec_os, exec_cpu, target_os, target_cpu),
                exec_compatible_with = [
                    "@platforms//cpu:{}".format(exec_cpu),
                    "@platforms//os:{}".format(exec_os),
                ],
                target_compatible_with = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                ],
                target_settings = target_settings,
                toolchain = cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )

            if target_os == "windows":
                native.toolchain(
                    name = "{}_{}_to_{}_{}_msvc".format(exec_os, exec_cpu, target_os, target_cpu),
                    exec_compatible_with = [
                        "@platforms//cpu:{}".format(exec_cpu),
                        "@platforms//os:{}".format(exec_os),
                    ],
                    target_compatible_with = [
                        "@platforms//cpu:{}".format(target_cpu),
                        "@platforms//os:{}".format(target_os),
                    ],
                    target_settings = [
                        "@llvm//toolchain:bootstrap_stage0_prebuilt_seed",
                        "@llvm//platforms/config:windows_{}_msvc".format(target_cpu),
                    ],
                    toolchain = cc_toolchain_name,
                    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                    visibility = ["//visibility:public"],
                )
