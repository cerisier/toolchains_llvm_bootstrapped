# Toolchain definition

Toolchains are defined as a composition of canonical argument groups, each representing a stable semantic aspect of the toolchain:
- Linker choice.
- Sysroot.
- Resource directory.
- Default startfiles.
- Hermetic compile and link flags.
- Deterministic compile and link flags.
- Default compile and link flags.
- Default libs.
- Sanitizers.

Each group has a stable meaning across all platforms and targets, even if its concrete flags differ or the group is empty.

Groups are defined at the level of the most constrained targets, so that more feature-rich or hosted environments compose or extend existing groups rather than redefining their semantics. For example, default_libs may be empty for freestanding or embedded targets, while being non-empty for hosted environments.

### Package structure

**//toolchain/args:BUILD.bazel**:
- Defines generic argument implementations and reusable compiler-personality
  implementations.
- Groups may be empty, but their semantic meaning must remain stable.
- Does not own the final target-OS/platform-family route.

This package provides the generic and personality-specific pieces from which a
platform family builds its implementation.

**//toolchain/args/\<platform\>:BUILD.bazel**:
- Defines the semantic implementation for one target OS/platform family.
- May select and compose platform-local axes such as ABI, CRT, SDK, runtime
  family, or intentional empty implementations.
- References concrete variant leaves rather than embedding raw flags.

For example, `//toolchain/args/windows` owns the Windows choice between MinGW
and the native MSVC ABI route, while preserving the canonical meaning of each
group.

**//toolchain/args/\<platform\>/\<variant\>:BUILD.bazel**:
- Defines concrete flags, action bindings, inputs, and data for one platform
  variant.
- Contains no selection between target OS, ABI, CRT, SDK, or runtime families.
- May still condition a concrete implementation on non-routing semantics such
  as a runtime build stage.

This is what “no platform select logic” means: concrete leaves do not decide
which platform variant applies. Their parent platform package owns that route.
Compiler personality is a separate axis and remains in reusable compiler
argument/feature layers; a supported toolchain route composes it explicitly
with the selected target platform implementation.

**//toolchain:BUILD.bazel**:
- Assembles the final toolchain by selecting the top-level target OS/platform
  family once for each canonical group.
- Contains only cc_args_list targets.
- No raw flags or action bindings.
- Does not select subordinate platform-local ABI, CRT, SDK, or runtime variants.

This package answers which platform-family implementation applies. The selected
platform package answers which of its local variants applies.

TODO(cerisier): Support macOS specific flags (objc and frameworks). Still needed ?

# Other Resources

https://github.com/bazelbuild/rules_cc/blob/main/docs/toolchain_api.md
https://github.com/CACI-International/cpp-toolchain/blob/74efb5bc636f48db86652f0cfdb7d46af100e51f/bazel/toolchain.bzl#L31
https://github.com/cortecs-lang/cortecs-cc-toolchain/blob/78792fba9eec75bfac14a0cd20cb0e4973175871/sysroot/alpine/BUILD
https://github.com/lukasoyen/bazel_linux_packages/blob/c50a9bf22122a507d2bb5e348231413a05e6d90f/e2e/toolchains/gcc/BUILD.bazel
https://github.com/lowRISC/opentitan/blob/6d29bb86581892c43d3dea8856b275dc3a40c575/toolchain/README.md
https://cs.opensource.google/pigweed/pigweed/+/main:pw_toolchain/cc/args/BUILD.bazel
https://github.com/envoyproxy/envoy/blob/main/bazel/rbe/toolchains/configs/linux/clang/cc/cc_toolchain_config.bzl
