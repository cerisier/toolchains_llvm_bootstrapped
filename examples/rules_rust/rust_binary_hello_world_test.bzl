load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

def rust_binary_hello_world_test(name, **kwargs):

    rust_binary(
        name = name,
        **kwargs,
    )

    arch_check = {
        "@toolchains_llvm_bootstrapped//platforms:linux_x86_64": "x86-64",
        "@toolchains_llvm_bootstrapped//platforms:linux_aarch64": "aarch64",
        "@toolchains_llvm_bootstrapped//platforms:macos_x86_64": "x86-64",
        "@toolchains_llvm_bootstrapped//platforms:macos_aarch64": "aarch64",
    }

    platform = kwargs.get("platform", None)

    # Test if the host binary works.
    # Note, we cannot test for platform since Bazel determines the host platform automatically
    sh_test(
        name = "test_" + name,
        srcs = ["test_platform.sh"] if platform else ["test_hello_world.sh"],
        args = [
            "$(rootpath :" + name + ")",
            arch_check.get(platform),
        ] if platform else [
            "$(rlocationpath :" + name + ")",
        ],
        data = [
            ":" + name,
        ],
        deps = [
            "@bazel_tools//tools/bash/runfiles",
        ],
    )
