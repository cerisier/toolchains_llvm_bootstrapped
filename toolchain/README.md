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

**//toolchain:BUILD.bazel**:
- Owns complete rules_cc argument-list ordering and composition.
- Exposes the public `toolchain_args` target consumed by `cc_toolchain`.
- Selects between complete generic and Windows compositions at the target-OS
  boundary.
- References named semantic implementations; it contains no raw flags or
  action bindings.

`windows_toolchain_args` is intentionally a complete composition rather than a
late platform-specific delta. Its semantic slots may use generic
implementations unchanged or select Windows, clang-cl, COFF, MSVC ABI, CRT, and
SDK implementations as appropriate. This explicit duplication is temporary
while those semantics are normalized. `platform_specific_args` remains only as
a legacy holder for generic platform behavior that has not yet been decomposed;
it is not the Windows extension point.

**//toolchain/args:BUILD.bazel**:
- Defines generic argument implementations and reusable compiler-personality
  implementations.
- Groups may be empty, but their semantic meaning must remain stable.
- Does not own complete toolchain ordering.

This package provides generic and personality-specific semantic pieces for the
top-level compositions.

**//toolchain/args/\<platform\>:BUILD.bazel**:
- Defines named semantic overrides for one target OS/platform family.
- May select a platform-local implementation for one semantic—such as ABI,
  CRT, SDK/runtime family, or an intentional empty implementation.
- Does not define the complete rules_cc argument list or its ordering.

For example, `//toolchain/args/windows:unwindlib` selects the applicable
Windows implementation of that one semantic. `//toolchain:windows_toolchain_args`
composes it in the complete Windows toolchain.

**//toolchain/args/\<platform\>/\<variant\>:BUILD.bazel**:
- Defines concrete flags, action bindings, inputs, and data for one platform
  variant.
- Contains no selection between target OS, ABI, CRT, SDK, or runtime families.
- May still condition a concrete implementation on non-routing semantics such
  as a runtime build stage.

This is what “no platform select logic” means for concrete leaves: they do not
decide which target OS or platform variant applies. The named semantic override
and the complete top-level composition own that routing.

Compiler personality is a separate axis from target OS, object format, ABI,
CRT, SDK/runtime family, C++ runtime, and execution platform. Reusable clang-cl
grammar stays in compiler-personality argument and feature layers. A supported
Windows composition explicitly combines that grammar with its COFF and MSVC
target semantics.

**//toolchain/runtimes:BUILD.bazel** follows the same ownership rule for staged
runtime toolchains: its public `toolchain_args` selects complete generic or
Windows runtime compositions, while concrete runtime compiler/linker semantics
remain in argument implementation packages.

TODO(cerisier): Support macOS specific flags (objc and frameworks). Still needed ?

# Other Resources

https://github.com/bazelbuild/rules_cc/blob/main/docs/toolchain_api.md
https://github.com/CACI-International/cpp-toolchain/blob/74efb5bc636f48db86652f0cfdb7d46af100e51f/bazel/toolchain.bzl#L31
https://github.com/cortecs-lang/cortecs-cc-toolchain/blob/78792fba9eec75bfac14a0cd20cb0e4973175871/sysroot/alpine/BUILD
https://github.com/lukasoyen/bazel_linux_packages/blob/c50a9bf22122a507d2bb5e348231413a05e6d90f/e2e/toolchains/gcc/BUILD.bazel
https://github.com/lowRISC/opentitan/blob/6d29bb86581892c43d3dea8856b275dc3a40c575/toolchain/README.md
https://cs.opensource.google/pigweed/pigweed/+/main:pw_toolchain/cc/args/BUILD.bazel
https://github.com/envoyproxy/envoy/blob/main/bazel/rbe/toolchains/configs/linux/clang/cc/cc_toolchain_config.bzl
