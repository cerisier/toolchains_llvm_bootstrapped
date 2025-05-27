load("@with_cfg.bzl", "with_cfg")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

_builder = with_cfg(
    cc_library,
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

cc_stage2_library, _cc_stage2_library_internal  = _builder.build()
