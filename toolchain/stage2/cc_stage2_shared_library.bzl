load("@rules_cc//cc:cc_shared_library.bzl", "cc_shared_library")
load("@rules_cc//cc/common:cc_shared_library_info.bzl", "CcSharedLibraryInfo")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_common.bzl", "configure_builder_for_stage2")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    cc_shared_library,
    extra_providers = [CcSharedLibraryInfo],
)

configure_builder_for_stage2(_builder)

cc_stage2_shared_library, _cc_stage2_shared_library_internal = _builder.build()
