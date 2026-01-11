load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    cc_binary,
)

cc_runtime_stage0_binary, _cc_stage0_binary_internal  = configure_builder_for_runtimes(_builder, "stage0").build()
