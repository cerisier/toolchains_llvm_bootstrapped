"""Helpers to extract a single static library artifact from a cc target."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _cc_static_lib_file_impl(ctx):
    ccinfo = ctx.attr.lib[CcInfo]
    target_lib = None
    for linker_input in ccinfo.linking_context.linker_inputs.to_list():
        for lib in linker_input.libraries:
            if lib.static_library:
                target_lib = lib.static_library
                break
            if not target_lib and lib.pic_static_library:
                target_lib = lib.pic_static_library
        if target_lib:
            break
    if not target_lib:
        fail("no static library found for %s" % ctx.attr.lib.label)

    out = ctx.actions.declare_file(ctx.attr.out)
    ctx.actions.symlink(output = out, target_file = target_lib)
    return [DefaultInfo(files = depset([out]))]

cc_static_lib_file = rule(
    implementation = _cc_static_lib_file_impl,
    attrs = {
        "lib": attr.label(providers = [CcInfo]),
        "out": attr.string(mandatory = True),
    },
)
