load("@rules_cc//cc:cc_static_library.bzl", "cc_static_library")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:cc_stage0_common.bzl", "configure_builder_for_stage0")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    cc_static_library,
)

configure_builder_for_stage0(_builder)

cc_stage0_static_library, _cc_stage0_static_library_internal = _builder.build()
