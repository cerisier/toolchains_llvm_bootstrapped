load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")
load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory_bin_action")

def _bootstrap_transition_impl(settings, attr):
    return {
        "//command_line_option:platforms": str(attr.platform),

        # we are compiling final programs, so we want all runtimes.
        "//toolchain:runtime_stage": "complete",

        # We want to build those binaries using the prebuilt compiler toolchain
        "//toolchain:source": "prebuilt",

        # Enable the same set of tools we provide with prebuilts.
        "@llvm-project//llvm:driver-tools": [
            "clang",
            "dsymutil",
            "lld",
            "llvm-ar",
            "llvm-cxxfilt",
            "llvm-libtool-darwin",
            "llvm-nm",
            "llvm-objcopy",
            "llvm-size",
            "llvm-symbolizer",
        ],
    }

bootstrap_transition = transition(
    implementation = _bootstrap_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:platforms",
        "//toolchain:runtime_stage",
        "//toolchain:source",
        "@llvm-project//llvm:driver-tools",
    ],
)

def _bootstrap_binary_impl(ctx):
    actual = ctx.attr.actual[0][DefaultInfo]
    exe = actual.files_to_run.executable

    out = ctx.actions.declare_file(ctx.label.name)

    if ctx.attr.symlink:
        ctx.actions.symlink(
            output = out,
            target_file = exe,
        )
    else:
        copy_file_action(ctx, exe, out)

    return [
        DefaultInfo(
            files = depset([out]),
            executable = out,
            runfiles = actual.default_runfiles,
        )
    ]

bootstrap_binary = rule(
    implementation = _bootstrap_binary_impl,
    executable = True,
    attrs = {
        "actual": attr.label(
            cfg = bootstrap_transition,
            allow_single_file = True,
            mandatory = True,
        ),
        "platform": attr.label(
            mandatory = True,
        ),
        "symlink": attr.bool(
            default = True,
            doc = "If set to False, will copy the tool instead of symlinking",
        ),
    },
    toolchains = COPY_FILE_TOOLCHAINS,
)

# TODO(zbarsky): This should replace bootstrap_binary once rules_cc is fixed.
def _exec_bootstrap_transition_impl(settings, attr):
    return {
        # we are compiling final programs, so we want all runtimes.
        "//toolchain:runtime_stage": "complete",

        # We want to build those binaries using the prebuilt compiler toolchain
        "//toolchain:source": "prebuilt",

        # Enable the same set of tools we provide with prebuilts.
        "@llvm-project//llvm:driver-tools": [
            "clang",
            "dsymutil",
            "lld",
            "llvm-ar",
            "llvm-cxxfilt",
            "llvm-libtool-darwin",
            "llvm-nm",
            "llvm-objcopy",
            "llvm-size",
            "llvm-symbolizer",
        ],
    }

exec_bootstrap_transition = transition(
    implementation = _exec_bootstrap_transition_impl,
    inputs = [],
    outputs = [
        "//toolchain:runtime_stage",
        "//toolchain:source",
        "@llvm-project//llvm:driver-tools",
    ],
)

# TODO(zbarsky): This should replace bootstrap_binary once rules_cc is fixed.
exec_bootstrap_binary = rule(
    implementation = _bootstrap_binary_impl,
    executable = True,
    attrs = {
        "actual": attr.label(
            cfg = exec_bootstrap_transition,
            allow_single_file = True,
            mandatory = True,
        ),
        "symlink": attr.bool(
            default = True,
            doc = "If set to False, will copy the tool instead of symlinking",
        ),
    },
    toolchains = COPY_FILE_TOOLCHAINS,
)

def _bootstrap_directory_impl(ctx):
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

bootstrap_directory = rule(
    implementation = _bootstrap_directory_impl,
    attrs = {
        "srcs": attr.label(
            cfg = bootstrap_transition,
            mandatory = True,
        ),
        "platform": attr.label(
            mandatory = True,
        ),
        "strip_prefix": attr.string(mandatory = True),
        "destination": attr.string(mandatory = True),
    },
    toolchains = ["@bazel_lib//lib:copy_to_directory_toolchain_type"],
)
