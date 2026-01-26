load("//platforms:common.bzl", "SUPPORTED_EXECS", "SUPPORTED_TARGETS")

_BUILD_TEMPLATE = """\
load("@toolchains_llvm_bootstrapped//toolchain:declare_toolchains.bzl", "declare_toolchains")
load("@toolchains_llvm_bootstrapped//toolchain/bootstrap:declare_toolchains.bzl", declare_bootstrap_toolchains = "declare_toolchains")

_EXECS = [
    {execs}
]

_TARGETS = [
    {targets}
]

declare_toolchains(execs = _EXECS, targets = _TARGETS)
declare_bootstrap_toolchains(execs = _EXECS, targets = _TARGETS)
"""

def _llvm_toolchains_repository_impl(ctx):
    ctx.file("BUILD.bazel", ctx.attr.build_file_content)

_llvm_toolchains_repository = repository_rule(
    implementation = _llvm_toolchains_repository_impl,
    attrs = {
        "build_file_content": attr.string(mandatory = True),
    },
)

def _format_platform_list(platforms):
    return ",\n    ".join([repr(platform) for platform in platforms])

def _llvm_module_extension_impl(mctx):
    execs = []
    targets = []

    for module in mctx.modules:
        for exec_tag in module.tags.exec:
            execs.append((exec_tag.os, exec_tag.arch))
        for target in module.tags.target:
            targets.append((target.os, target.arch))

    if not execs:
        execs = SUPPORTED_EXECS

    if not targets:
        targets = SUPPORTED_TARGETS

    _llvm_toolchains_repository(
        name = "llvm_toolchains",
        build_file_content = _BUILD_TEMPLATE.format(
            execs = _format_platform_list(execs),
            targets = _format_platform_list(targets),
        ),
    )

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = ["llvm_toolchains"],
        root_module_direct_dev_deps = [],
    )

_platform_tag = tag_class(
    attrs = {
        "os": attr.string(
            mandatory = True,
            values = ["linux", "macos"],
        ),
        "arch": attr.string(
            mandatory = True,
            values = ["x86_64", "aarch64"]
        ),
    },
)

llvm = module_extension(
    implementation = _llvm_module_extension_impl,
    doc = "Generates LLVM toolchains for the requested target/exec platform pairs.",
    tag_classes = {
        "target": _platform_tag,
        "exec": _platform_tag,
    },
)
