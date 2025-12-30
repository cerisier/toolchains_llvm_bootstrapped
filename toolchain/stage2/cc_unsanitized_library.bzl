load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _reset_sanitizers_impl(settings, attr):
    return {
        "//config:ubsan": False,
        "//config/stage1:ubsan": False,

        # we are compiling sanitizers, so we want all runtimes except sanitizers.
        # TODO(cerisier): Should this be exressed with a dedicated stage ?
        "//toolchain:runtime_stage": "complete",

        # We want to build those binaries using the prebuilt compiler toolchain
        "//toolchain:source": "prebuilt",

        # Right now, this rule is used to compile parts of LLVM.
        # We can't use the stage2 toolchain for that.
        # "//toolchain:bootstrap_setting": False,
        # "//toolchain:stage1_bootstrap_setting": False,

        # And LLVM uses <zlib.h> instead of "zlib.h" so we disable it here too.
        "@llvm_zlib//:llvm_enable_zlib": False,
    }

_reset_sanitizers = transition(
    implementation = _reset_sanitizers_impl,
    inputs = [],
    outputs = [
        "//config:ubsan",
        "//config/stage1:ubsan",
        "//toolchain:runtime_stage",
        "//toolchain:source",
        "@llvm_zlib//:llvm_enable_zlib",
    ],
)

def _cc_unsanitized_library_impl(ctx):
    # It's a list because it's transitioned.
    dep = ctx.attr.dep[0]

    providers = [
        dep[DefaultInfo],
        dep[CcInfo],
    ]

    if OutputGroupInfo in dep:
        providers.append(dep[OutputGroupInfo])

    if InstrumentedFilesInfo in dep:
        providers.append(dep[InstrumentedFilesInfo])

    return providers

cc_unsanitized_library = rule(
    implementation = _cc_unsanitized_library_impl,
    attrs = {
        "dep": attr.label(
            cfg = _reset_sanitizers,
            providers = [CcInfo],
        ),
    },
)
