load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")
load("//toolchain/runtimes:with_cfg_runtimes_common.bzl", "configure_builder_for_runtimes")

ppc64le_stage1_binary, _ppc64le_stage1_binary_internal = configure_builder_for_runtimes(
    with_cfg(cc_binary),
    "stage1",
).build()

ppc64le_stage1_hosted_binary, _ppc64le_stage1_hosted_binary_internal = configure_builder_for_runtimes(
    with_cfg(cc_binary),
    "stage1_hosted",
).build()
