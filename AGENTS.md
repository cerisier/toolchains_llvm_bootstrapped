# Sanitizer Integration Blueprint

This document describes the standard workflow to add a new sanitizer runtime to
this repository, based on the existing implementations (`msan`, `tsan`,
`lsan`, `rtsan`, `tysan`).

## Goal

For a sanitizer `<san>`, wire all of the following:

1. Build settings and transitions (`//config:<san>`, host/target variants).
2. Toolchain compile/link flags.
3. Runtime-stage sanitizer flags.
4. compiler-rt runtime library targets in Bazel.
5. Runtime alias/resource-dir exposure.
6. `e2e/rules_cc` failing test coverage.

## Source of Truth (Upstream CMake)

Use upstream compiler-rt CMakeLists as the canonical source for:

- Runtime source files.
- Runtime headers/textual headers.
- OS/arch conditionals.
- Runtime-specific CFLAGS/DEFS/LINK deps.
- Name of the clang flag (`-fsanitize=...`).

Typical paths:

- `.../external/toolchains_llvm_bootstrapped++http_archive+compiler-rt/lib/<san>/CMakeLists.txt`
- Sometimes extra nested CMakeLists (for example `tsan/rtl/CMakeLists.txt`).

## Required Project Touchpoints

Apply changes in this order.

### 1) Build settings and reset transitions

- `config/defs.bzl`
  - Add `<san>` to `SANITIZERS`.
- Reset sanitizer configs in transition files:
  - `toolchain/bootstrap/bootstrap_binary.bzl`
  - `toolchain/runtimes/with_cfg_runtimes_common.bzl`
  - `toolchain/runtimes/cc_unsanitized_library.bzl`
  - `toolchain/runtimes/cc_stage0_object.bzl`

For each reset transition, include both:

- `//config:<san>`
- `//config:host_<san>`

### 2) Toolchain args

- `toolchain/args/BUILD.bazel`
  - Add:
    - `<san>_compiler_flags` (`-fsanitize=<flag>`, usually `-fno-omit-frame-pointer`)
    - `<san>_linker_flags`
    - `<san>_flags` (`select` on target+host enabled config)
- `toolchain/BUILD.bazel`
  - Add `//toolchain/args:<san>_flags` in optional sanitizer list.
- `toolchain/features/BUILD.bazel`
  - Add `//config:<san>_enabled` in sanitizer list that disables `--icf=safe`.

### 3) Runtime-stage args

- `toolchain/runtimes/args/BUILD.bazel`
  - Add `<san>_flags` for compile-time runtime rebuild (compiler flags only).
- `toolchain/runtimes/BUILD.bazel`
  - Include `//toolchain/runtimes/args:<san>_flags`.

### 4) compiler-rt Bazel runtime targets

- `3rd_party/llvm-project/21.x/compiler-rt/compiler-rt.BUILD.bazel`
  - Add a section mirroring upstream CMake:
    - filegroups for sources/headers
    - sanitizer cflags
    - one or more `cc_library` runtime components
    - final `cc_runtime_stage0_static_library` target(s)

Important:

- Follow repo style from existing sanitizer blocks.
- Preserve upstream OS/arch conditionals with Bazel `select(...)`.
- Include textual headers (`*.inc`) where required.

### 5) Runtime alias and resource directory

- `runtimes/compiler-rt/BUILD.bazel`
  - Add alias(es), usually `clang_rt.<san>.static`.
- `runtimes/BUILD.bazel`
  - Add `//config:<san>_enabled` map entry in `resource_directory`
    to produce expected clang runtime name(s), for example:
    `libclang_rt.<san>`.

### 6) e2e failing test coverage

- `e2e/rules_cc/defs.bzl`
  - Add `<san>_cc_binary` macro (set both target and host config flags).
- `e2e/rules_cc/BUILD.bazel`
  - Add:
    - `<san>_fail` binary target
    - `<san>_output_test` shell test using `exec_test`.
- Add test files:
  - `e2e/rules_cc/<san>_fail.cc`
  - `e2e/rules_cc/<san>_output_test.sh`

Test style:

- Mimic existing sanitizer scripts (`msan/asan/lsan/tsan/rtsan/tysan`).
- Assert a stable runtime diagnostic substring.
- If environment-specific runtime limitations are known, add explicit skip
  branches with clear message.

## Validation Command

Run from `e2e/rules_cc`:

```bash
bazel --batch test \
  --noexperimental_collect_system_network_usage \
  --remote_executor= \
  --remote_cache= \
  --bes_backend= \
  //:<san>_output_test
```

## How to Process CMake vs Bazel

When translating CMake to Bazel:

1. Copy source/header lists exactly first.
2. Port conditionals (`if(APPLE)`, `elseif(UNIX)`, arch-specific blocks) with
   Bazel `select(...)`.
3. Port runtime-specific flags and defs conservatively.
4. Map CMake object/runtime targets to the local Bazel pattern:
   `cc_library` + `cc_runtime_stage0_static_library`.
5. Keep naming consistent with existing runtime aliases under
   `runtimes/compiler-rt/BUILD.bazel`.

If upstream has shared+static variants but project currently uses static-only
for similar sanitizers, follow local precedent unless explicitly expanding
feature scope.

## Upgrade/Maintenance Notes (LLVM version bumps)

When updating LLVM/compiler-rt:

1. Re-diff each sanitizer CMakeLists against local Bazel section.
2. Update filegroups for added/removed/renamed sources and headers.
3. Re-check OS/arch conditions and assembly sources.
4. Re-check sanitizer-specific compile flags/defs/link deps.
5. Re-run all sanitizer e2e output tests.
6. If runtime naming changed upstream, update:
   - `runtimes/compiler-rt/BUILD.bazel` aliases
   - `runtimes/BUILD.bazel` resource mapping
7. Re-check that all transitions include the full sanitizer set.

Practical diff commands:

```bash
rg -n "compiler-rt/lib/<san>|<SAN>_SOURCES|<SAN>_HEADERS|add_compiler_rt_runtime" \
  3rd_party/llvm-project/21.x/compiler-rt/compiler-rt.BUILD.bazel \
  <upstream compiler-rt path>/lib/<san>/CMakeLists.txt
```

## Quick Checklist for New Sanitizer

- [ ] Added in `config/defs.bzl`.
- [ ] Added in all sanitizer reset transitions.
- [ ] Added toolchain compile/link flags and wired in.
- [ ] Added runtime-stage compile flags and wired in.
- [ ] Added compiler-rt runtime section in Bazel.
- [ ] Added runtime alias and resource directory mapping.
- [ ] Added `e2e/rules_cc` macro + fail target + output test.
- [ ] Local test `//:<san>_output_test` passes.
