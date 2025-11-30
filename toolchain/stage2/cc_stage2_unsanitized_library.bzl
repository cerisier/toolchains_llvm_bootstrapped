load("@with_cfg.bzl", "with_cfg")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc/private/rules_impl:cc_shared_library.bzl", "GraphNodeInfo")

_builder = with_cfg(
    cc_library,
    extra_providers = [GraphNodeInfo],
)

# The problem is that compiler-rt and start libs can only be compiled with
# a specific set of flags and compilation mode. It is not safe to let the user
# interfere with them using default command line flags.
# TODO: Expose a build setting to extend stage1 flags.
_builder.set("copt", [])
_builder.set("cxxopt", [])
_builder.set("linkopt", [])
_builder.set("host_copt", [])
_builder.set("host_cxxopt", [])
_builder.set("host_linkopt", [])

_builder.set(
    Label("//toolchain:bootstrap_setting"),
    True,
)

_builder.set(Label("//config:ubsan"), False)
_builder.set(Label("//config:msan"), False)
_builder.set(Label("//config:asan"), False)

cc_stage2_unsanitized_library, _cc_stage2_unsanitized_library_internal  = _builder.build()

