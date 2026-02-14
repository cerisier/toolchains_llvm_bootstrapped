load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc/private/rules_impl:cc_shared_library.bzl", "GraphNodeInfo", "graph_structure_aspect")

def _reset_sanitizers_impl(settings, attr):
    return {
        "//config:ubsan": False,
        "//config:msan": False,
        "//config:rtsan": False,
        "//config:tsan": False,
        "//config:asan": False,
        "//config:lsan": False,
        "//config:host_ubsan": False,
        "//config:host_msan": False,
        "//config:host_rtsan": False,
        "//config:host_tsan": False,
        "//config:host_asan": False,
        "//config:host_lsan": False,

        # we are compiling sanitizers, so we want all runtimes except sanitizers.
        # TODO(cerisier): Should this be exressed with a dedicated stage ?
        "//toolchain:runtime_stage": "complete",

        # We want to build those binaries using the prebuilt compiler toolchain
        "//toolchain:source": "prebuilt",
    }

_reset_sanitizers = transition(
    implementation = _reset_sanitizers_impl,
    inputs = [],
    outputs = [
        "//config:ubsan",
        "//config:msan",
        "//config:rtsan",
        "//config:tsan",
        "//config:asan",
        "//config:lsan",
        "//config:host_ubsan",
        "//config:host_msan",
        "//config:host_rtsan",
        "//config:host_tsan",
        "//config:host_asan",
        "//config:host_lsan",

        "//toolchain:runtime_stage",
        "//toolchain:source",
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
