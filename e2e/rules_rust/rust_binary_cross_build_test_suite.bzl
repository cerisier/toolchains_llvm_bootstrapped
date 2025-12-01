load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

def rust_binary_test_suite(name, check, **kwargs):
    platform = kwargs.get("platform", None)
    rust_binary(
        name = name,
        **kwargs
    )

    # Temporary hack to get an exec compatible binary to run inside a sh_test.
    native.genrule(
        name = "file_" + name,
        tools = ["@libmagic//:file"],
        outs = ["file_output_" + name],
        cmd = "cp $(execpath @libmagic//:file) $@",
        executable = True,
    )

    # Test if the host binary works.
    sh_test(
        name = "test_" + name,
        srcs = ["test_platform.sh"] if platform else ["test_hello_world.sh"],
        args = [
            "$(rootpath :" + name + ")",
            check,
        ] if platform else [
            "$(rlocationpath :" + name + ")",
        ],
        env = {
            "FILE_BINARY": "$(rlocationpath :file_" + name + ")",
            "MAGIC_FILE": "$(rlocationpath @libmagic//:magic.mgc)",
        } if platform else {},
        data = ([
            ":file_" + name,
            "@libmagic//:magic.mgc",
        ] if platform else []) + [":" + name],
        deps = [
            "@bazel_tools//tools/bash/runfiles",
        ],
    )

def rust_binary_cross_build_test_suite(name, platforms, **kwargs):

    rust_binary(
        name = name,
        **kwargs,
    )

    kwargs.pop("experimental_use_cc_common_link", None)

    for (platform, check) in platforms.items():
        for experimental_use_cc_common_link in [0, 1]:
            rust_binary_test_suite(
                name = name + "_" + platform.split(":")[-1] + (
                    "_cc_common_link" if experimental_use_cc_common_link else ""
                ),
                check = check,
                platform = platform,
                experimental_use_cc_common_link = experimental_use_cc_common_link,
                **kwargs,
            )
