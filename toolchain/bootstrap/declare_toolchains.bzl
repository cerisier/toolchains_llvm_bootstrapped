load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//platforms:common.bzl", "ABI_SUPPORTED_TARGETS", "SUPPORTED_TARGETS")
load("//toolchain:cc_toolchain.bzl", "cc_toolchain")
load(":bootstrap_binary.bzl", "bootstrap_binary", "bootstrap_directory")

def declare_tool_map(exec_os, exec_cpu):
    prefix = exec_os + "_" + exec_cpu

    native.platform(
        name = prefix + "_platform",
        constraint_values = [
            "@platforms//cpu:{}".format(exec_cpu),
            "@platforms//os:{}".format(exec_os),
        ],
    )

    COMMON_TOOLS = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": prefix + "/clang",
        "@rules_cc//cc/toolchains/actions:c_compile": prefix + "/clang",
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions": prefix + "/clang++",
        "@rules_cc//cc/toolchains/actions:link_actions": prefix + "/lld",
        "@rules_cc//cc/toolchains/actions:objcopy_embed_data": prefix + "/llvm-objcopy",
        "@rules_cc//cc/toolchains/actions:strip": prefix + "/llvm-strip",
    }

    cc_tool_map(
        name = prefix + "/default_tools",
        tools = COMMON_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-ar",
        },
    )

    cc_tool_map(
        name = prefix + "/tools_with_libtool",
        tools = COMMON_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-libtool-darwin",
        },
    )

    cc_tool_map(
        name = prefix + "/tools_for_msvc",  # TODO: unsure about that one still
        tools = COMMON_TOOLS | {
            # "@rules_cc//cc/toolchains/actions:assembly_actions": prefix + "/clang-cl",
            # "@rules_cc//cc/toolchains/actions:c_compile": prefix + "/clang-cl",
            # "@rules_cc//cc/toolchains/actions:cpp_compile_actions": prefix + "/clang-cl",
            "@rules_cc//cc/toolchains/actions:link_actions": prefix + "/lld-link",
        },
    )

    bootstrap_binary(
        name = prefix + "/bin/clang",
        platform = prefix + "_platform",
        actual = "@llvm-project//clang:clang.stripped",
    )

    bootstrap_directory(
        name = prefix + "/clang_builtin_headers_include_directory",
        srcs = "@llvm-project//clang:builtin_headers_files",
        # TODO(zbarsky): Probably shouldn't force platform here.
        platform = prefix + "_platform",
        # TODO(zbarsky): Previously we did `load("@llvm-project//:vars.bzl", "LLVM_VERSION_MAJOR")`
        # but that forced an eager fetch of LLVM, so we hardcode 21 for now. Does it actually matter
        # what the version is?
        destination = prefix + "/lib/clang/21/include",
        strip_prefix = "clang/lib/Headers",
    )

    cc_tool(
        name = prefix + "/clang",
        src = prefix + "/bin/clang",
        data = [
            prefix + "/clang_builtin_headers_include_directory",
        ],
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_pic"],
    )

    bootstrap_binary(
        name = prefix + "/bin/clang++",
        platform = prefix + "_platform",
        actual = "@llvm-project//clang:clang.stripped",
        # Copy instead of symlink so clang's InstalledDir matches the packaged tree.
        # This is crucial for properly locating the various linkers, since we don't use `-ld-path`.
        symlink = False,
    )

    cc_tool(
        name = prefix + "/clang++",
        src = prefix + "/bin/clang++",
        data = [
            prefix + "/clang_builtin_headers_include_directory",
        ],
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_pic"],
    )

    bootstrap_binary(
        name = prefix + "/bin/clang-cl",
        platform = prefix + "_platform",
        actual = "@llvm-project//clang:clang.stripped",
        # TODO: is it also the case for clang-cl?
        # Copy instead of symlink so clang's InstalledDir matches the packaged tree.
        # This is crucial for properly locating the various linkers, since we don't use `-ld-path`.
        symlink = False,
    )

    cc_tool(
        name = prefix + "/clang-cl",
        src = prefix + "/bin/clang-cl",
        data = [
            prefix + "/clang_builtin_headers_include_directory",
        ],
        capabilities = [],  # no pic support when targetting MSVC
    )

    bootstrap_binary(
        name = prefix + "/bin/ld.lld",
        platform = prefix + "_platform",
        actual = "@llvm-project//lld:lld.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/lld-link",
        platform = prefix + "_platform",
        actual = "@llvm-project//lld:lld-link.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/ld64.lld",
        platform = prefix + "_platform",
        actual = "@llvm-project//lld:lld.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/lld",
        platform = prefix + "_platform",
        actual = "@llvm-project//lld:lld.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/wasm-ld",
        platform = prefix + "_platform",
        actual = "@llvm-project//lld:lld.stripped",
    )

    cc_tool(
        name = prefix + "/lld",
        src = prefix + "/bin/clang++",
        data = [
            prefix + "/bin/ld.lld",
            prefix + "/bin/ld64.lld",
            prefix + "/bin/lld",
            prefix + "/bin/wasm-ld",
        ],
    )

    cc_tool(
        # TODO: unsure if needed for now
        name = prefix + "/lld-link",
        src = prefix + "/bin/lld-link",
        data = [
            prefix + "/bin/lld-link",
        ],
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-ar",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm-ar.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-ar",
        src = prefix + "/bin/llvm-ar",
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-libtool-darwin",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm-libtool-darwin.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-libtool-darwin",
        src = prefix + "/bin/llvm-libtool-darwin",
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-objcopy",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm-objcopy.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-strip",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm-objcopy.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-objcopy",
        src = prefix + "/bin/llvm-objcopy",
    )

    cc_tool(
        name = prefix + "/llvm-strip",
        src = prefix + "/bin/llvm-strip",
    )

def declare_toolchains(*, execs = None, targets = SUPPORTED_TARGETS):
    """Declares the configured LLVM toolchains.

    Args:
        execs: List of (os, arch) tuples describing exec platforms.
        targets: List of (os, arch) tuples describing target platforms.
    """
    if not execs:
        execs = [
            (arch, os)
            # Any supported target that can run a compiler is a supported exec.
            # If we can compile a compiler for that target, we can use that compiler
            # to compile for any other target.
            for (arch, os) in targets
            if arch != "none"  # wasm is no good for us.
        ]

    for (exec_os, exec_cpu) in execs:
        declare_tool_map(exec_os, exec_cpu)

        cc_toolchain_name = "bootstrap_{}_{}_cc_toolchain".format(exec_os, exec_cpu)

        # Even though `tool_map` has an exec transition, Bazel doesn't properly handle
        # binding a single `cc_toolchain` to multiple toolchains with different `exec_compatible_with`.
        # See https://github.com/bazelbuild/rules_cc/issues/299#issuecomment-2660340534
        cc_toolchain(
            name = cc_toolchain_name,
            tool_map = select({
                "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_macos_setting": ":{}_{}/tools_with_libtool".format(exec_os, exec_cpu),
                "//conditions:default": ":{}_{}/default_tools".format(exec_os, exec_cpu),
            }),
        )

        for (target_os, target_cpu) in targets:
            native.toolchain(
                name = "bootstrap_{}_{}_to_{}_{}".format(exec_os, exec_cpu, target_os, target_cpu),
                exec_compatible_with = [
                    "@platforms//cpu:{}".format(exec_cpu),
                    "@platforms//os:{}".format(exec_os),
                ],
                target_compatible_with = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                    "//constraints/abi:unconstrained",
                ],
                target_settings = [
                    "@toolchains_llvm_bootstrapped//toolchain:bootstrapped_toolchain",
                ],
                toolchain = cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )

        msvc_cc_toolchain_name = "bootstrap_{}_{}_msvc_cc_toolchain".format(exec_os, exec_cpu)
        cc_toolchain(
            name = msvc_cc_toolchain_name,
            tool_map = ":{}_{}/tools_for_msvc".format(exec_os, exec_cpu),
            compiler = "clang",  # FIXME: should we change to clang-cl?
        )
        for (target_os, target_cpu) in ABI_SUPPORTED_TARGETS:
            native.toolchain(
                name = "bootstrap_{}_{}_to_{}_{}_msvc".format(exec_os, exec_cpu, target_os, target_cpu),
                exec_compatible_with = [
                    "@platforms//cpu:{}".format(exec_cpu),
                    "@platforms//os:{}".format(exec_os),
                ],
                target_compatible_with = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                    "//constraints/abi:msvc",
                ],
                target_settings = [
                    "@toolchains_llvm_bootstrapped//toolchain:bootstrapped_toolchain",
                ],
                toolchain = msvc_cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )
