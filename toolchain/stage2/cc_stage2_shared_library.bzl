load("@rules_cc//cc:cc_shared_library.bzl", "cc_shared_library")
load("@rules_cc//cc/common:cc_shared_library_info.bzl", "CcSharedLibraryInfo")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    cc_shared_library,
    extra_providers = [CcSharedLibraryInfo],
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
_builder.set("features", [])
_builder.set("host_features", [])

_builder.set(
    Label("//toolchain:bootstrap_setting"),
    True,
)

cc_stage2_shared_library, _cc_stage2_shared_library_internal = _builder.build()
