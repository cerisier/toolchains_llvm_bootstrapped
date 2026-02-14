load("@with_cfg.bzl", "with_cfg")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

ubsan_cc_binary, _ubsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@toolchains_llvm_bootstrapped//config:ubsan"), True
).set(
    Label("@toolchains_llvm_bootstrapped//config:host_ubsan"), True
).build()

msan_cc_binary, _msan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@toolchains_llvm_bootstrapped//config:msan"), True
).set(
    Label("@toolchains_llvm_bootstrapped//config:host_msan"), True
).build()

tsan_cc_binary, _tsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@toolchains_llvm_bootstrapped//config:tsan"), True
).set(
    Label("@toolchains_llvm_bootstrapped//config:host_tsan"), True
).build()

asan_cc_binary, _asan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@toolchains_llvm_bootstrapped//config:asan"), True
).set(
    Label("@toolchains_llvm_bootstrapped//config:host_asan"), True
).build()

lsan_cc_binary, _lsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@toolchains_llvm_bootstrapped//config:lsan"), True
).set(
    Label("@toolchains_llvm_bootstrapped//config:host_lsan"), True
).build()

opt_binary, _opt_binary_internal = with_cfg(cc_binary).set(
    "compilation_mode", "opt"
).build()
