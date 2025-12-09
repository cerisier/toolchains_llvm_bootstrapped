load("@rules_cc//cc:cc_static_library.bzl", "cc_static_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_common.bzl", "configure_builder_for_stage2")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    cc_static_library,
)

configure_builder_for_stage2(_builder)

cc_stage2_static_library, _cc_stage2_static_library_internal = _builder.build()
