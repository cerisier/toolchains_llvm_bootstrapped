load("@bazel_skylib//rules:copy_file.bzl", "copy_file")
load("@llvm//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(
    copy_file,
)

cc_runtime_stage0_copy_file, _cc_runtime_stage0_copy_file_internal = configure_builder_for_runtimes(_builder, "stage0").build()
