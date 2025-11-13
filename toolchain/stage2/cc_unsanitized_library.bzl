load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _reset_sanitizers_impl(settings, attr):
    return {
        "//config:ubsan": False,
    }

_reset_sanitizers = transition(
    implementation = _reset_sanitizers_impl,
    inputs = [],
    outputs = [
        "//config:ubsan",
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
