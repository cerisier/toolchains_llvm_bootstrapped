load("@with_cfg.bzl", "with_cfg")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

ubsan_cc_binary, _ubsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@toolchains_llvm_bootstrapped//config:ubsan"), True
).build()

opt_binary, _opt_binary_internal = with_cfg(cc_binary).set(
    "compilation_mode", "opt"
).build()
