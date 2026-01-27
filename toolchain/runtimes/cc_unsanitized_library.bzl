load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc/private/rules_impl:cc_shared_library.bzl", "GraphNodeInfo", "graph_structure_aspect")

def _reset_sanitizers_impl(settings, attr):
    return {
        "//config:ubsan": False,
        "//config:msan": False,
        "//config:asan": False,
        "//config/bootstrap:ubsan": False,
        "//config/bootstrap:msan": False,
        "//config/bootstrap:asan": False,

        # we are compiling sanitizers, so we want all runtimes except sanitizers.
        # TODO(cerisier): Should this be exressed with a dedicated stage ?
        "//toolchain:runtime_stage": "complete",

        # We want to build those binaries using the prebuilt compiler toolchain
        "//toolchain:source": "prebuilt",

        # And LLVM uses <zlib.h> instead of "zlib.h" so we disable it here too.
        "@llvm_zlib//:llvm_enable_zlib": False,
    }

_reset_sanitizers = transition(
    implementation = _reset_sanitizers_impl,
    inputs = [],
    outputs = [
        "//config:ubsan",
        "//config:msan",
        "//config:asan",
        "//config/bootstrap:ubsan",
        "//config/bootstrap:msan",
        "//config/bootstrap:asan",
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

    if GraphNodeInfo in dep:
        providers.append(dep[GraphNodeInfo])

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
            aspects = [graph_structure_aspect],
        ),
    },
)
