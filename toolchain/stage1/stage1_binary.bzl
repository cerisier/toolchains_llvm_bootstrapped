load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory_bin_action")

def _bootstrap_transition_impl(settings, attr):
    return {
        "//toolchain:bootstrap_setting": False,
        "//toolchain:stage1_bootstrap_setting": True,
        # Some flags to make LLVM build sanely.
        "@llvm_zlib//:llvm_enable_zlib": False,
        "@rules_python//python/config_settings:bootstrap_impl": "script",
    }

bootstrap_transition = transition(
    implementation = _bootstrap_transition_impl,
    inputs = [],
    outputs = [
        "//toolchain:bootstrap_setting",
        "//toolchain:stage1_bootstrap_setting",
        "@llvm_zlib//:llvm_enable_zlib",
        "@rules_python//python/config_settings:bootstrap_impl",
    ],
)

def _stage1_binary_impl(ctx):
    actual = ctx.attr.actual[0][DefaultInfo]
    exe = actual.files_to_run.executable

    out = ctx.actions.declare_file(ctx.label.name)

    ctx.actions.symlink(
        target_file = exe,
        output = out,
    )

    return [
        DefaultInfo(
            files = depset([out]),
            executable = out,
            runfiles = actual.default_runfiles,
        )
    ]

stage1_binary = rule(
    implementation = _stage1_binary_impl,
    executable = True,
    attrs = {
        "actual": attr.label(
            cfg = bootstrap_transition,
            allow_single_file = True,
            mandatory = True,
        ),
    },
)

def _stage1_directory_impl(ctx):
    copy_to_directory_bin = ctx.toolchains["@bazel_lib//lib:copy_to_directory_toolchain_type"].copy_to_directory_info.bin

    dst = ctx.actions.declare_directory(ctx.attr.destination)

    copy_to_directory_bin_action(
        ctx,
        name = ctx.attr.name,
        copy_to_directory_bin = copy_to_directory_bin,
        dst = dst,
        files = ctx.files.srcs,
        replace_prefixes = {ctx.attr.strip_prefix: ""},
        include_external_repositories = ["**"],
    )

    return DefaultInfo(files = depset([dst]))

stage1_directory = rule(
    implementation = _stage1_directory_impl,
    attrs = {
        "srcs": attr.label(
            cfg = bootstrap_transition,
            mandatory = True,
        ),
        "strip_prefix": attr.string(mandatory = True),
        "destination": attr.string(mandatory = True),
    },
    toolchains = ["@bazel_lib//lib:copy_to_directory_toolchain_type"],
)
