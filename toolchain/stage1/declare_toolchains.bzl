load("//platforms:common.bzl", "SUPPORTED_TARGETS")
load("//toolchain:cc_toolchain.bzl", "cc_toolchain")
load(":stage1_binary.bzl", "stage1_binary", "stage1_directory")
load("@llvm-project//:vars.bzl", "LLVM_VERSION_MAJOR")
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("@rules_platform//platform_data:defs.bzl", "platform_data")

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

    stage1_binary(
        name = prefix + "/bin/clang",
        platform = prefix + "_platform",
        actual = "@llvm-project//clang:clang.stripped",
    )

    stage1_directory(
        name = prefix + "/clang_builtin_headers_include_directory",
        srcs = "@llvm-project//clang:builtin_headers_files",
        # TODO(zbarsky): Probably shouldn't force platform here.
        platform = prefix + "_platform",
        destination = prefix + "/lib/clang/%s/include" % LLVM_VERSION_MAJOR,
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

    stage1_binary(
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

    stage1_binary(
        name = prefix + "/bin/ld.lld",
        platform = prefix + "_platform",
        actual = "@llvm-project//lld:lld.stripped",
    )

    stage1_binary(
        name = prefix + "/bin/ld64.lld",
        platform = prefix + "_platform",
        actual = "@llvm-project//lld:lld.stripped",
    )

    stage1_binary(
        name = prefix + "/bin/lld",
        platform = prefix + "_platform",
        actual = "@llvm-project//lld:lld.stripped",
    )

    stage1_binary(
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

    stage1_binary(
        name = prefix + "/bin/llvm-ar",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm-ar.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-ar",
        src = prefix + "/bin/llvm-ar",
    )

    stage1_binary(
        name = prefix + "/bin/llvm-libtool-darwin",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm-libtool-darwin.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-libtool-darwin",
        src = prefix + "/bin/llvm-libtool-darwin",
    )

    stage1_binary(
        name = prefix + "/bin/llvm-objcopy",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm-objcopy.stripped",
    )

    stage1_binary(
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

def declare_toolchains():
    supported_execs = [
        (arch, os)
        for (arch, os) in SUPPORTED_TARGETS
        if arch != "none" # wasm is no good for us.
    ]

    # Hack to only make single one..
    # supported_execs = [("windows", "x86_64")]

    for (exec_os, exec_cpu) in supported_execs:
        declare_tool_map(exec_os, exec_cpu)

        cc_toolchain_name = "{}_{}_cc_toolchain".format(exec_os, exec_cpu)

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

        for (target_os, target_cpu) in SUPPORTED_TARGETS:
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
                target_settings = [
                    "//toolchain:bootstrapped",
                    "//toolchain:stage1_bootstrapped",
                ],
                toolchain = cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )
