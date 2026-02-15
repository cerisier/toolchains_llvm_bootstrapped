def _rbe_platform_repo_impl(rctx):
    arch = rctx.os.arch
    if arch in ["x86_64", "amd64"]:
        cpu = "x86_64"
        exec_arch = "amd64"
    elif arch in ["aarch64", "arm64"]:
        cpu = "aarch64"
        exec_arch = "arm64"
    else:
        fail("Unsupported host arch for rbe platform: {}".format(arch))

    rctx.file("BUILD.bazel", """\
platform(
    name = "rbe_platform",
    constraint_values = [
        "@platforms//cpu:{cpu}",
        "@platforms//os:linux",
        "@bazel_tools//tools/cpp:clang",
        "@toolchains_llvm_bootstrapped//constraints/libc:gnu.2.28",
    ],
    exec_properties = {{
        "container-image": "docker://ubuntu:22.04",
        "Arch": "{arch}",
        "OSFamily": "Linux",
    }},
    visibility = ["//visibility:public"],
)
""".format(
        cpu = cpu,
        arch = exec_arch,
    ))

rbe_platform_repository = repository_rule(
    implementation = _rbe_platform_repo_impl,
    doc = "Sets up a platform for remote builds with an Arch exec_property matching the host.",
)
