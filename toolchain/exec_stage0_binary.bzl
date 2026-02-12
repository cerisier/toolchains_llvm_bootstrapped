load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")
load("@with_cfg.bzl", "with_cfg")

_exec_stage0_binary_builder = with_cfg(
    cc_binary,
)

_exec_stage0_binary_builder.set(Label("//config:ubsan"), False)
_exec_stage0_binary_builder.set(Label("//config:msan"), False)
_exec_stage0_binary_builder.set(Label("//config:asan"), False)
_exec_stage0_binary_builder.set(Label("//config:host_ubsan"), False)
_exec_stage0_binary_builder.set(Label("//config:host_msan"), False)
_exec_stage0_binary_builder.set(Label("//config:host_asan"), False)
_exec_stage0_binary_builder.set(Label("//config/bootstrap:ubsan"), False)
_exec_stage0_binary_builder.set(Label("//config/bootstrap:msan"), False)
_exec_stage0_binary_builder.set(Label("//config/bootstrap:asan"), False)
_exec_stage0_binary_builder.set(Label("//config/bootstrap:host_ubsan"), False)
_exec_stage0_binary_builder.set(Label("//config/bootstrap:host_msan"), False)
_exec_stage0_binary_builder.set(Label("//config/bootstrap:host_asan"), False)

exec_stage0_binary, _exec_stage0_binary_internal  = configure_builder_for_runtimes(_exec_stage0_binary_builder, "stage0").build()
