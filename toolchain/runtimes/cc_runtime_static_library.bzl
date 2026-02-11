load("@rules_cc//cc:cc_static_library.bzl", "cc_static_library")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    cc_static_library,
)

# NOTE: runtime static libraries do not have >stage0 dependencies.
# Those are only needed for shared libraries.
cc_runtime_stage0_static_library, _cc_stage0_static_library_internal = configure_builder_for_runtimes(_builder.clone(), "stage0", sanitizers = False).build()
cc_runtime_stage0_unsanitized_static_library, _cc_stage0_static_unsanitized_library_internal = configure_builder_for_runtimes(_builder.clone(), "stage0", sanitizers = False).build()
