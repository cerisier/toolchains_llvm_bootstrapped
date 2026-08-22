# Windows MSVC prebuilt LLVM execution plan

Status: Steps 1-4, 6-10, and 10.1 are complete. Step 5 is intentionally
skipped. Step 11 is implemented locally; matching-Windows CI execution remains
unproved. Step 12 remains proposed and requires separate authorization.

Date: 2026-08-20 (Asia/Tokyo)
Revised: 2026-08-22 (Asia/Tokyo)

## Activation and baseline

- Objective: make the source-built minimal LLVM archive under `//prebuilt/llvm`
  build for `@llvm//platforms:windows_x86_64_msvc` and
  `@llvm//platforms:windows_aarch64_msvc` while retaining the completed Layer 1
  clang-cl, UCRT/VCRuntime, and static-libc++ contract.
- Base branch: `cerisier/windows-msvc-libcxx`.
- Exact base: `9c460c7ee876c94a03da79a55a54eb9ea7050a00`.
- Planning branch: `cerisier/windows-msvc-prebuilt-llvm-plan`.
- Planning worktree:
  `/Users/corentinkerisit/code/github.com/hermeticbuild/hermetic-llvm-msvc-prebuilt-plan`.
- Default source line: LLVM 22.1.8. Compatibility lines: LLVM 21.1.8 and
  23.1.0-rc1.
- Required target products: optimized PE/COFF `llvm.exe` multicall archives for
  x86-64 and ARM64, with deterministic `llvm-ar` intermediate archives and the
  existing minimal-toolchain archive layout.

The planning branch contains only this plan. This revision records completed
local implementation through Step 11 but does not authorize pushing the
implementation, triggering CI, release publication, README edits, a new PR, or
`gh stack` operations.

## Implementation progress

Steps 1-4 and 6-7 are implemented on draft hermetic-llvm PR #711 through its
current remote head, `3be43832dd40e995ff248de38f8ea13dd4b992d0`:

- Step 1: `1347780b` adds the temporary Stage-1-backed MSVC route.
- Step 2: `d948c9f3` closes the curated COM compiler-support dependency.
- Step 3: `df2b6187` fixes ARM64 native configuration. The corresponding LLVM
  change was merged as llvm-project PR #217557.
- Step 4: `c14d2bbd` through `24869f63` complete the full x86-64 and ARM64
  Stage 1 builds. The BLAKE3 clang-cl fix was merged as llvm-project PR
  #217695; the libc++ VCRuntime `std::nothrow` fix remains draft PR #217694;
  the conditional static-Clang configuration remains downstream only by owner
  decision.
- Step 6: `88d95603` moves C++17 and release intent into dialect-aware
  toolchain features while retaining the existing generic spellings and
  effective behavior.
- Step 7: `21ee5d74` and `97584336` implement the LLVM lld weak-alias fix and
  repository-owned clang-cl/COFF ThinLTO protocol. `36ab3da5` and `3be43832`
  then simplify the supported contract to source-backed bootstrap tools and
  remove the temporary indexing launcher, special linker alias, environment
  plumbing, and downstream rules_cc patch.

Steps 8-9.1 are implemented locally on the same branch through
`73d74238c2168146ffdcfea90197d4366eca6199`; they are not yet pushed:

- the Step 8 prerequisite `1c066553` resets release features for runtime
  builds, `0b305d7c` generates and merges the MSVC bootstrap profiles, and
  `96d570a8` uses the correct trapping-math spelling for clang-cl workloads;
- Step 9 commit `e81af7a6` selects and applies the MSVC profile to direct Stage
  3 compile and ThinLTO backend actions;
- Step 9.1 commit `73d74238` removes the conservative MSVC-only full-bitcode
  indexing override and asserts the standard rules_cc dual-output contract:
  minimized `.indexing.o` for indexing, complete `.obj` for each backend.

Step 10 is implemented locally on the same branch through
`1088aa6898e5fd9e15fa3b3cca66def5932830eb`; it is not yet pushed:

- `5aecdb5e` promotes both explicit MSVC package labels to the normal Stage 3
  input and removes the temporary `windows_msvc_prebuilt` config, Stage 1
  override, and unused `llvm_binary` parameter;
- `1088aa68` adds default-LLVM canonical release package builds for both
  target CPUs to CI, recording each configured archive path and SHA-256.

Step 10.1 is implemented locally through
`e98a818bc4e5a4a4c9ae9a7809e97c20ddd87c77`; it is not yet pushed:

- archive inspection exposed that the first accepted Stage 3 executables used
  the ordinary consumer `/MD` default and imported `MSVCP140.dll`,
  `VCRUNTIME140.dll`, and, on x86-64, `VCRUNTIME140_1.dll`, while the archives
  intentionally contained no DLLs;
- `b226292b` was the initial ownership attempt, selecting the static CRT from
  Stage 3 through a new generic bootstrap attribute. Owner review rejected
  that coupling. Follow-up `e98a818b` fully restores generic
  `bootstrap_binary` and makes the existing `--config=release` disable
  `dynamic_link_msvcrt` and enable `static_link_msvcrt` instead;
- therefore every MSVC release product selects `/MT`, while ordinary MSVC
  consumers outside `--config=release` retain `/MD`. The policy is expressed
  at the product-configuration/toolchain boundary, not in bootstrap topology.

Step 11 is implemented locally through
`24379cfdca6ec768a870da082ac73d83bd86872f`; it is not yet pushed and its two
native Windows cells have not run:

- a CI helper creates an exact temporary minimal-prebuilt index entry using
  the locally built archive's `file://` URL and computed SHA-256, then appends
  a CI-only extension instance to the e2e module. No local URL or placeholder
  release metadata enters the committed public index;
- local x86-64 and ARM64 import proofs show that the existing version-neutral
  Windows repository names and BUILD overlay consume the new archives
  unchanged;
- the Windows matrix keeps both existing MinGW rows and adds matching x86-64
  and ARM64 MSVC rows. Each MSVC cell builds its unpublished archive remotely,
  registers it only in that workspace, executes the prebuilt compiler on the
  matching Windows runner, inspects selection/actions/imports, and runs the
  existing `/MD`, `/MT`, and DLL behaviors;
- the superseded standalone package-only job and Windows/macOS host-analysis
  duplicates are removed. Linux x86-64 and ARM64 retain the source-bootstrap
  action/artifact checks; native Windows runners now own completed-prebuilt
  consumer execution.

Both complete Stage 1 outputs were inspected: x86-64 is
`IMAGE_FILE_MACHINE_AMD64`; ARM64 is `IMAGE_FILE_MACHINE_ARM64`, not ARM64EC.
An unchanged packaging feasibility probe also produced and extracted both
Stage 1 archives (`fa08b192-ba5f-4e8d-a859-003f2c2bee9f`), but no packaging
edit, commit, or delivery followed. The probe is evidence that the existing
archive machinery works; it is not an accepted package checkpoint.

A later temporary, uncommitted swap of the same package rule to the proved
Stage 3 input built and extracted both LLVM 22.1.8 MSVC archives under the
canonical release config (invocation
`89586cd3-b4bd-4606-9612-591f3537a1f1`). The x86-64 archive is 45,082,317
bytes with SHA-256
`3aac82a3c61f12fdf8dcb4f37eaa12f9265a530f8ee4a35348a1ff740f521fcc`;
the ARM64 archive is 42,094,158 bytes with SHA-256
`a8f4d2ecc2a742f9ea3967cba0d334ca5d8b07c142500b0940142d3cc14bc588`.
Both have the same 346-entry layout, 281 builtin headers, the expected
multicall symlinks, and AMD64/native-ARM64 `llvm.exe` respectively. The probe
was restored immediately and does not promote the dormant package labels or
complete Step 10.

The permanent Step 10 graph then rebuilt both accepted archives under only
`--config=remote --config=release` (invocation
`075d34a5-fc80-4821-813a-3b6d86adeae1`) and reproduced those exact sizes and
hashes. Both archives have 346 entries in identical order, 281 extracted
builtin-header files, 49 multicall symlinks plus the real `llvm.exe`, both
ignorelists, fixed uid/gid/timestamps, and no packaged `.pdb`, `.dll`, or
`.lib`. Their debug directories contain only a reproducibility entry and no
PDB reference. Selective download of only the generated mtree spec
(`b77486e0-d58b-430f-a72e-532dcd324eda`) proved that its real binary input is
`//toolchain/bootstrap/stage3:llvm` and that it contains no absolute host path.
The x86-64 binary is AMD64 and the ARM64 binary is native ARM64, not ARM64EC.

Both complete source-backed ThinLTO LLVM monoliths were also built directly as
`@llvm-project//llvm:llvm` with
`--//toolchain:bootstrap_stage=stage1_from_source`: x86-64 invocation
`e8217f53-6129-4f1c-98ed-f72e0b2b0e89` and ARM64 invocation
`074f1a25-fa93-46ac-a1b9-f55558007a15`. Their PE machine types are respectively
AMD64 and native ARM64. Action inspection proved normal source-built clang-cl
with its declared sibling source-built lld-link for indexing and final link,
plus target `.obj` backend outputs. The rules_cc-owned merged intermediate
remains named `.lto.merged.o`; selective downloads proved it is AMD64/ARM64
COFF and the final lld-link action consumes it. No custom launcher,
`COMPILER_PATH`, launcher environment, special linker path, or rules_cc patch
remains. Stage 0 prebuilt ThinLTO is not a supported correctness boundary for
the known weak-alias case.

Direct ThinLTO/FDO Stage 3 builds completed for x86-64 (invocation
`20f7251b-b159-4217-97de-b271d4d0413d`) and ARM64 (invocation
`cef15446-e68c-4e02-8141-cdf3a6533225`). Their PE machine types are AMD64 and
native ARM64 respectively, not ARM64EC. The generated Stage 3 compile actions
apply the declared merged MSVC profile, emit both complete and minimized
ThinLTO bitcode, and use the source-backed clang-cl/lld-link COFF protocol.
Representative minimized summaries were 26,192 bytes for ARM64 Stage 1 and
23,896 bytes for profiled x86-64 Stage 3, versus complete objects of 1,284,576
and 1,286,832 bytes. Normalized `llvm-dis --print-thinlto-index-only` output
matched its corresponding complete object at the semantic-summary level.
Backends and final link parameter files reference complete target `.obj`
files only. No LLVM or rules_cc production patch was required.

The same complete direct Stage 3 ThinLTO/FDO graph also passed unchanged for
LLVM 21.1.8: x86-64 invocation
`7f44605b-6473-4f40-a852-9c35eba324c5` and ARM64 invocation
`2efc19d0-758f-4377-bb73-575f0beff61b`. Their embedded version is 21.1.8 and
their PE machine types are AMD64 and native ARM64 respectively. Materialized
compile/index/link parameters retain the declared profile, minimized
`.indexing.o` inputs, suffix mapping, complete `.obj` backend route, target
triples, and `/MACHINE` values without a compatibility-specific change.

## Objective and non-goals

The final supported path will package a ThinLTO-optimized, instrumentation-FDO
Stage 3 LLVM for the MSVC ABI, using the same Stage 1 -> instrumented Stage 2
-> workload/profile merge -> profile-applied Stage 3 topology as the existing
release products. It will expose two explicit platform-transitioned labels:

- `//prebuilt/llvm:for_windows_x86_64_msvc`
- `//prebuilt/llvm:for_windows_aarch64_msvc`

The directly configurable product label is
`//prebuilt/llvm:windows_msvc_llvm_release`. Step 1 currently backs these manual
labels with Stage 1 only as temporary implementation scaffolding; Step 10 has
removed that debt and made Stage 3 under `--config=release` the accepted
product. Do not publish or advertise the archives until the separately
authorized release-delivery step. The existing
`//prebuilt/llvm:windows_llvm_release` and `for_windows_amd64`/
`for_windows_arm64` remain the GNU/MinGW products and keep their current Stage
3 behavior.

Non-goals for this plan:

- using a Windows PE Stage 1/2 compiler as an executable construction tool;
- Microsoft's `cl.exe` or `link.exe`; the supported MSVC-compatible path is
  exec-platform clang-cl/llvm-ar/lld-link targeting the MSVC ABI;
- Microsoft STL headers or Microsoft STL as the selected standard library;
- shared libc++, shared LLVM, DLL packaging, debug-CRT packaging, sanitizer or
  coverage enablement;
- a parallel test framework or broad new behavior suite. Extend the existing
  MSVC action/analysis/artifact scripts and CI jobs for focused regression
  coverage; full LLVM compilation and artifact/action inspection remain the
  authoritative acceptance surface;
- README/release-note changes, artifact publication, EULA redistribution, new
  CI secrets, or a prebuilt-release workflow cutover;
- expanding source-bootstrap construction-host support beyond the existing
  Linux RBE executors already used by the generic Stage 2/3 graph. Step 11's
  focused matching-Windows consumer cells execute the completed prebuilt
  compiler but do not rebuild LLVM from source.

## Current graph and exact labels

The unconfigured graph is:

```text
//prebuilt/llvm:windows_llvm_release
  -> //toolchain/bootstrap/stage3:llvm
     -> @llvm-project//llvm:llvm
     -> //toolchain/bootstrap/stage3:llvm_fdo_profdata
        -> every Stage 2 workload in SUPPORTED_TARGETS

//toolchain/bootstrap/stage1:llvm
  --bootstrap_transition-->
     @llvm-project//llvm:llvm
     target: requested Windows MSVC platform
     compiler: Stage 0 prebuilt seed for the selected exec platform
     runtime_stage: complete
     compilation_mode: opt
```

`prebuilt/llvm/BUILD.bazel` currently creates only generic platform wrappers
from `prebuilt/platforms.bzl`. Its Windows entries are
`//platforms:windows_amd64` and `//platforms:windows_arm64`, which explicitly
carry the repository's GNU ABI. Therefore neither existing convenience label
is an MSVC target. The current direct diagnostic labels are:

```sh
bazel build --config=remote \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //prebuilt/llvm:windows_llvm_release

bazel build --config=remote \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //prebuilt/llvm:windows_llvm_release
```

They intentionally fail on the baseline for the reasons below. Until direct
Stage 3 proof, use the temporary config only for direct bootstrap diagnostics.
The manual package wrappers remain dormant:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage1:llvm

bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //toolchain/bootstrap/stage1:llvm
```

Do not use `//prebuilt/llvm:windows_msvc_llvm_release` as an acceptance target
before Stage 3 promotion.

After the Stage 3 promotion and cleanup step, the canonical product command is:

```sh
bazel build --config=remote --config=release \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  //prebuilt/llvm:for_windows_x86_64_msvc \
  //prebuilt/llvm:for_windows_aarch64_msvc
```

## Demonstrated baseline failure ledger

Facts below were reproduced without tracked implementation edits. Temporary
action-query output was written only under `/tmp` and removed after evidence
capture.

| ID | Probe | Result and owner |
|---|---|---|
| B0 | `bazel query --config=remote '//prebuilt/llvm:*' --output=label_kind` | Passed; invocation `9f4b46a2-9b7f-4285-ad4d-3fb667415c69`. Confirmed both release targets and only generic platform wrappers. |
| B1 | MSVC cquery without EULA opt-in | Repository fetch stopped on the Visual Studio runtime EULA; invocation `d5c0e948-f0bb-426a-80e5-4db6e59f1272`. This is a mandatory caller/CI prerequisite, not a product bug. |
| B2 | Direct x64 release with only `--config=remote` | Stage 3 expanded the complete FDO workload matrix and failed C++ toolchain resolution; invocation `10a00462-725e-48be-af13-12439d9c23e0`. Later cqueries selected `none_wasm32` and other workloads. The particular workload is incidental; the owner is the unconditional Stage 3 dependency and the command also lacks `--config=release`'s extra toolchains. |
| B3 | Direct x64 release with `--config=remote --config=release` | Analysis failed with the intentional Layer 1 message `MSVC ABI Layer 1 does not support feature(s): thin_lto`; invocation `b34b7bd8-2aef-47d1-be8b-64d4f61a2a02`. This is the correct baseline boundary and remains until the ThinLTO step proves the complete MSVC action protocol. |
| B4 | Same release plus `--features=-thin_lto` | Stage 3 still expanded FDO and failed because the selected toolchain had no enabled `llvm-profdata` action; invocation `e9ba8690-b383-4067-842b-41f6bcdf3911`, after 459,269 configured targets. Disabling the command-line feature cannot turn Stage 3 into a non-FDO build. |
| B5 | `//toolchain/bootstrap/stage1:llvm`, x64 | Analysis succeeded through 93,874 configured targets/6,966 actions. LLVM `Support`/`Demangle` compilation failed because `std::is_integral_v` and `std::optional` were unavailable; no `/std:c++17` was present. Invocation `c38b1e76-b378-4fed-9997-a430ef41f77d`. |
| B6 | Stage 1, ARM64 | Same missing-standard failure at `std::optional`; invocation `a618ddc3-2514-46f2-bd4d-157462d19150`. |
| B7 | Stage 1 x64 plus `--cxxopt=/std:c++17` | Compilation advanced to `@llvm-project//llvm:WindowsDriver` and failed at `MSVCPaths.cpp:43`, missing `comdef.h`; invocation `77667245-d3ba-4373-8d67-d54d28398ce9`. |
| B8 | Stage 1 ARM64 plus `--cxxopt=/std:c++17` | Same `comdef.h` failure; invocation `77b4f926-e4f6-44dd-a210-5a0f2147f094`. |
| B9 | Stage 1 x64 with release flags, ThinLTO disabled, and C++17 | Reached 6,607 scheduled actions and the same `comdef.h` failure, but clang-cl warned that raw `-fno-exceptions`, `-fno-rtti`, and `-fomit-frame-pointer` from `.bazelrc` were ignored. Invocation `1ad641f5-5ef3-4280-8db7-87f5467dc941`. The generic release config is not a valid clang-cl optimization config. |
| B10 | ARM64 materialized compile params | Target triple was `aarch64-pc-windows-msvc`, but `LLVM_NATIVE_ARCH` was `X86` and host/default triples were `x86_64-pc-win32`. Owner: LLVM upstream `utils/bazel/llvm-project-overlay/llvm/config.bzl`; all three supported source lines and upstream main select every Windows CPU as x86-64. |
| B11 | `TdGenerate` aquery | Windows target-generated files were produced by `clang-tblgen`/`llvm-min-tblgen` under `rbe_linux_aarch64-opt-exec`; invocation `f263f805-4b7a-44c8-bcd8-e941a8371a60`. `mlir/tblgen.bzl` declares its executable with `cfg = "exec"`. This boundary is correct and must not regress. |
| B12 | Whole Stage 1 action inventory | 6,503 `CppCompile`, 841 `CppArchive`, 352 `TdGenerate`, 278 `CppLink`, 218 `DefParser`, 70 `CopyToDirectory`, 14 `CopyFile`, and declared Windows case actions, among others; invocation `282e9af9-296d-4a9d-9e81-d17c70ae9c10`. |
| B13 | Archive aquery | Target archives use exec-host `llvm-ar`, Windows `.lib` names, and deterministic `rcsD`; invocation `39efcf0e-df70-4c95-9c47-72de5b94cfd0`. Action generation succeeded; archive execution remains unproven because compilation stops earlier. |
| B14 | Final-link aquery | The planned x64 action launches exec-host clang-cl, targets x64 MSVC, selects sibling lld-link, declares SDK/UCRT/VCRuntime/libc++ resource and library directories, emits `/MACHINE:X64`, `/Brepro`, `/INCREMENTAL:NO`, `/lldignoreenv`, deterministic PDB path controls, `/SUBSYSTEM:CONSOLE`, `.lib` dependencies, and `/WHOLEARCHIVE`; invocation `bfde2c52-ed47-4c22-b72e-87b3cc64d6f3`. It does not execute because B7 fails. Link success remains unproven. |
| B15 | Packaging source inspection | `prebuilt/llvm/llvm_release.bzl` hardcodes Stage 3 and maps an extensionless bootstrap output to `bin/llvm.exe`. Stage ownership and Windows output naming must be proven when the package target is reached. Existing release genrules are accepted and are not cleanup targets. |
| B16 | COM closure inspection | The pinned payload contains `comdef.h`, `comdefsp.h`, `comip.h`, `comutil.h`, `new.h`, and x64/ARM64 `comsuppw.lib`; Layer 1's curated trees expose none of them. `comdef.h` auto-links retail Unicode `comsuppw.lib`, `user32.lib`, `ole32.lib`, and `oleaut32.lib`. The ARM64 `comsuppw.lib` is a vendor fat archive with both ARM64EC and ARM64 members; target-member selection is not yet proven. |

The generated external `vars.bzl` sets `CMAKE_CXX_STANDARD = "17"`, and LLVM's
own `utils/bazel/.bazelrc` supplies `/std:c++17` in its Windows config. The
overlay explicitly says general compiler flags belong in a toolchain or
`.bazelrc`, not `llvm_copts`. Therefore C++17 is a hermetic-llvm invocation/
toolchain ownership issue; it is not an upstream target-local patch.

The attempt to suppress `_MSC_VER` only for `MSVCPaths.cpp` caused UCRT macro
failures (`9b7bd60e-464e-4e48-8239-e3437f9896a1`) and is rejected. The source
uses COM Setup Configuration intentionally for MSVC-environment discovery.

## Architectural invariants

1. **Truthful optimization stage.** Until direct Stage 3 proof, no MSVC package
   is accepted, registered, advertised, or added to persistent package CI. The
   current manual labels may still resolve to Stage 1 only as dormant temporary
   scaffolding. The final labels consume Stage 3 and must contain the complete
   Stage 1 -> ThinLTO/instrumented Stage 2 -> MSVC workload -> `llvm-profdata`
   merge -> ThinLTO/profile-applied Stage 3 graph. No label may claim a later
   stage before its actions and artifacts have been proved. Existing non-MSVC
   Stage 3 products remain unchanged.
2. **Exec/target separation.** TableGen, config generators, DEF parsing,
   archive creation, manifest creation, copying, and tar/zstd tools execute for
   the resolved exec platform. LLVM objects/libraries/binaries always use the
   requested Windows target platform. No target executable runs while cross-
   compiling.
3. **MSVC action identity.** Target compilation/linking uses clang-cl; archives
   use llvm-ar `rcsD`; clang-cl selects the declared sibling lld-link. Every
   source/link action has the x86-64 or ARM64 MSVC triple and the matching
   `/MACHINE:` value.
4. **Declared platform closure.** Only declared pinned Windows SDK, UCRT,
   VCRuntime/compiler-support, Clang resource, and static-libc++ directories
   are reachable. `LIB` remains the sentinel empty value; ambient Visual
   Studio, SDK, `PATH`, `CL`, and `_CL_` do not affect target actions.
5. **Static libc++ only.** Public C++ headers/types come from libc++. The
   already-approved CRT-selected Microsoft ABI helper provider and the narrow
   COM support archive are permitted; Microsoft STL headers, `c++.dll`, and a
   Microsoft-STL selection are not.
6. **Source standard and dialect.** LLVM source receives C++17 in target
   configuration, matching LLVM's CMake and Bazel source of truth. clang-cl
   options use CL spelling or audited `/clang:` escapes. No silently ignored
   Unix-only flag is acceptable.
7. **Upstream ownership.** Files copied from
   `llvm-project/utils/bazel/llvm-project-overlay` are fixed upstream first.
   Temporary line-specific patch files must contain the same reviewable change
   and be removable when a released LLVM source includes it. No hermetic-
   llvm-only macro, build setting, or path may enter an upstream patch.
8. **Scope discipline.** Existing llvm-project and release shell/genrule
   actions are accepted unless an exact supported build demonstrates that one
   blocks compilation or packaging. Do not replace them for style,
   portability, or hermeticity as part of this task.
9. **Windows artifact naming.** Target executables are `.exe`, target objects
   `.obj`, target archives `.lib`. Wrapper/copy actions preserve configured
   extensions. Response files use Layer 1's independent UTF-8 compiler,
   archive, and linker protocols.
10. **Release artifacts.** The archive contains one real `bin/llvm.exe`, the
    existing multicall aliases, Clang builtin headers, and ignorelists with
    fixed uid/gid/mtime. The optimized monolithic EXE produces no import
    library. No PDB is expected unless `/DEBUG` and a declared PDB output are
    deliberately enabled; an undeclared or referenced-but-unpackaged PDB is a
    failure.
11. **No accidental compatibility widening.** New direct/package labels state
    Windows + MSVC ABI + UCRT + libc++ compatibility. MinGW actions, outputs,
    release labels, and Stage 3 selection do not change.
12. **Optimization dialect ownership.** Release intent is expressed through
    toolchain features or other target-aware semantics. Generic Clang keeps
    its current effective ThinLTO/FDO/release arguments; clang-cl receives
    audited CL or `/clang:` spellings. ThinLTO backend outputs use configured
    `.obj` naming and lld-link's COFF protocol. After Step 9.1, the index action
    consumes only Clang's minimized `.indexing.o` summaries and maps them back
    to the complete `.obj` module paths; backends retain the complete bitcode
    objects. The rules_cc-owned merged internal may retain its `.lto.merged.o`
    name when its contents are proved COFF and the final link consumes it. FDO
    instrumentation runs in the Linux exec-platform compiler process; no
    Windows target binary executes while profiles are collected or merged.
13. **Validation graduates one capability at a time.** Layer 1's unsupported-
    feature validation remains intact except for an exact feature after its
    dedicated step proves analysis, actions, and artifacts. ThinLTO support
    does not imply FDO support; internal bootstrap profile generation does not
    silently enable unrelated public profiling, coverage, sanitizer, or PDB
    configurations.
14. **Temporary Step 1 debt.** `--config=windows_msvc_prebuilt`, its
    config-local `/std:c++17` and release-policy flags, the Stage 1
    `llvm_binary` override, and the `llvm_release(llvm_binary=...)` parameter
    are temporary unless another non-test caller demonstrates a durable need.
    Remove each as soon as the next accepted graph makes it unnecessary and
    remove all remaining debt in the Stage 3 promotion step. The explicit MSVC
    product label, wrappers, compatibility constraints, and any proven generic
    executable-suffix fix remain.

## Mergeability contract

Every numbered step is a potential merge point, not merely a checkpoint in an
unreviewable long-lived branch:

- the step ends with its advertised labels truthful and buildable to the
  stated finish line; dormant support may land before a public label uses it,
  but no public label may enter a partially implemented downstream stage;
- existing `for_windows_amd64` and `for_windows_arm64` continue to select GNU
  platforms and the unchanged generic Stage 3 dependency topology;
- generic Linux/macOS/Windows release actions retain their effective release,
  ThinLTO, FDO, tool, artifact, and exec/target semantics. Any intentional
  argument-order-only difference is documented from an aquery comparison;
- existing Layer 1 MSVC smoke/configuration checks retain their default `/MD`,
  opt/dbg, `/MT` route, archive/link, unsupported-feature, and target/exec
  behavior except for the single capability deliberately graduated by that
  step;
- a newly discovered owner that changes LLVM source semantics, public
  toolchain behavior, shared release infrastructure, or another platform is
  split into its own predecessor step rather than hidden inside an owner loop;
- each step records a before/after cquery or aquery for the graph boundary it
  changes and inspects the produced action/artifact, not only command status.
- a step that graduates a public feature or package boundary extends the
  existing MSVC action/analysis/artifact CI surface for default LLVM 22.1.8 in
  the same merge. After Step 11's native cells are green, Step 12 expands that
  default coverage to the full source-version matrix; it is not the first
  persistent coverage for Steps 7-11.

At every step, run and retain the common regression gate in addition to that
step's owning commands:

```sh
bazel cquery --config=remote --config=release \
  'set(//prebuilt/llvm:for_windows_amd64 //prebuilt/llvm:for_windows_arm64)' \
  --output=label_kind

bazel aquery --config=remote --config=release \
  'deps(//prebuilt/llvm:for_windows_amd64)' \
  --output=text --include_artifacts=false \
  --output_file=/tmp/windows-gnu-release-regression-actions.txt

(
  cd e2e/rules_cc
  bash ./windows_msvc_action_test.sh --config=remote
  bash ./windows_msvc_analysis_test.sh --config=remote
)
```

Compare the generic configured Stage 3/profile labels, representative action
tools/arguments, and output categories to the predecessor evidence. Run the
existing MSVC artifact matrix for both CPUs when a step changes action flags,
tool maps, artifact naming, SDK/runtime inputs, or validation. A remote-only
failure is classified before changing semantics. Remove the temporary dump
after its facts are recorded.

## Dependency graph and assignment order

```text
Step 1: Stage-1 MSVC release route/config
  +--> Step 2: curated COM compiler-support closure
  +--> Step 3: upstream ARM64 configuration patch
              (Steps 2-3 can proceed independently once Step 1 exposes probes)
                    |
                    v
          Step 4: build-to-completion owner loop
                    |
                    v
          Step 5: skipped (Stage 1 packaging feasibility only)
                    |
                    v
          Step 6: dialect-aware shared release semantics
                    |
                    v
          Step 7: MSVC ThinLTO action protocol
                    |
                    v
          Step 8: MSVC FDO instrumentation/workloads/merge
                    |
                    v
          Step 9: MSVC FDO application + direct Stage 3 proof
                    |
                    v
          Step 9.1: minimized clang-cl/COFF ThinLTO indexing
                    |
                    v
          Step 10: first Stage 3 packages + remove Step 1 debt
                    |
                    v
          Step 10.1: self-contained release compiler CRT
                    |
                    v
          Step 11: register prebuilts + Windows consumer matrix
                    |
                    v
          Step 12: supported-source Stage 3 build jobs
```

Each implementation step belongs on an isolated branch/worktree based on the
then-current accepted predecessor. Do not create a stack or submit a PR until
the owner separately approves that delivery workflow.

To reduce coordination overhead, one authorized goal may execute Steps 6-7
continuously and another may execute Steps 8-9 continuously, provided each
step retains its own traced owner, reviewable commits, and advertised finish
line. Step 9.1 remains a separate post-Step-9 correction. Step 10 is gated on
both complete direct Stage 3 proof and the minimized-indexing proof from Step
9.1.

## Step 1 — Add a truthful Stage-1-backed MSVC release route

**Codex-agent-ready goal:** Add explicit MSVC package labels and a dedicated
optimized clang-cl config that cannot enter Stage 2/3, ThinLTO, or FDO. Preserve
all existing release labels and their Stage 3 graph.

Likely owned files:

- `.bazelrc`;
- `prebuilt/llvm/BUILD.bazel`;
- `prebuilt/llvm/llvm_release.bzl`;
- optionally `toolchain/bootstrap/bootstrap_binary.bzl` if the configured
  output extension must be fixed before packaging.

Implementation shape:

- parameterize `llvm_release` with its LLVM binary label;
- instantiate a manual, MSVC-compatible
  `windows_msvc_llvm_release` from `//toolchain/bootstrap/stage1:llvm`;
- add manual platform-transition wrappers named exactly
  `for_windows_x86_64_msvc` and `for_windows_aarch64_msvc`;
- keep the existing generic releases on Stage 3 and out of the new config;
- create `--config=windows_msvc_prebuilt` from source-of-truth release pieces,
  not by expanding `--config=release`: opt mode, static dependency mode,
  `--extra_toolchains=//toolchain:all`, stripping if the PE action proves it,
  `/std:c++17`, explicit `--features=-thin_lto`, and clang-cl-correct
  equivalents for no-exceptions/no-RTTI/frame-pointer flags;
- keep remote-executor and execution-platform selection in `--config=remote`,
  outside the product config;
- do not weaken Layer 1's unsupported-feature validation.

Build/action commands:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage1:llvm

bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //toolchain/bootstrap/stage1:llvm

bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  //prebuilt/llvm:for_windows_x86_64_msvc \
  //prebuilt/llvm:for_windows_aarch64_msvc

bazel aquery --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  'deps(//prebuilt/llvm:for_windows_x86_64_msvc)' \
  --output=text --include_artifacts=false \
  --output_file=/tmp/windows-msvc-prebuilt-x64-actions.txt
```

Success criteria:

- both new wrappers resolve to `windows_msvc_llvm_release`, Stage 1, and the
  intended platform;
- cquery/aquery contains no configured Stage 2/3, FDO workload/profile/merge,
  `thin_lto`, or `llvm-profdata` action;
- target compile params contain `/std:c++17` and no ignored raw `-fno-*`;
- the build reaches B7/B8 or a later traced blocker without B2-B6;
- existing `for_windows_amd64` and `for_windows_arm64` still resolve to the
  GNU platforms and Stage 3.

**Potentially mergeable finish line:** The two new manual labels truthfully
expose only Stage 1, reach the first source-owned blocker, and leave every
existing product graph unchanged. The dedicated config and parameterized
binary input are accepted only as recorded temporary debt; they must not be
documented as the final release interface.

Risks/stop conditions:

- stop if the only available design disables ThinLTO/FDO globally or changes
  non-MSVC Stage 3;
- stop if target-dialect config flags leak into exec-configured Linux tools;
- if `.exe` cannot be preserved by the current wrapper, fix the generic
  wrapper from the configured executable basename rather than hardcoding an
  exec host or target CPU.

Upstream llvm-project patch expected: **no**.

## Step 2 — Close the declared MSVC COM support dependency

**Codex-agent-ready goal:** Make LLVM's existing Windows Setup Configuration
source compile/link with a minimal, audited Microsoft compiler-support closure
while libc++ remains the only selected STL.

Likely owned files:

- `windows/BUILD.bazel`;
- only if a target-scoped argument group proves necessary,
  `toolchain/args/msvc/BUILD.bazel` and the relevant toolchain assembly file.

Start with the source-required set demonstrated by `MSVCPaths.cpp` and the
pinned payload: `comdef.h`, `comdefsp.h`, `comip.h`, `comutil.h`, `new.h`, and
retail Unicode `comsuppw.lib`. The SDK already owns `Ole2.h`, `OleCtl.h`,
`roerrorapi.h`, `user32.lib`, `ole32.lib`, and `oleaut32.lib`. `type_traits`
must continue to resolve from libc++, not the Microsoft include tree.

Preferred implementation:

- extend or separately stage a named compiler-support header directory with
  only the five audited headers; include it in the existing case VFS;
- expose `comsuppw.lib` from both target-selected retail MSVC library trees;
  its COFF directive selects it only for sources including `comdef.h`;
- never add the full MSVC include directory or unfiltered MSVC lib directory;
- retain the default `/MD` product. `/MT` is not a package acceptance cell in
  this layer, but the directory change must not corrupt Layer 1's `/MT` route.

Build/artifact commands:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage1:llvm --remote_download_all

bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //toolchain/bootstrap/stage1:llvm --remote_download_all

bazel aquery --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  --include_param_files \
  'outputs(".*llvm/llvm.exe", mnemonic("CppLink", deps(//toolchain/bootstrap/stage1:llvm)))' \
  --output=commands \
  --output_file=/tmp/windows-msvc-prebuilt-arm64-link.txt
```

Success criteria:

- `MSVCPaths.cpp` compiles for both architectures from declared inputs;
- its include trace resolves `type_traits`, `string`, allocation, and other
  standard headers through libc++; no Microsoft STL header becomes an input;
- final links resolve `comsuppw.lib` plus SDK COM import libraries without an
  ambient `LIB` path;
- `llvm readobj --file-headers` shows selected x64 AMD64 and ARM64 ARM64
  members; ARM64EC-only member selection is a failure;
- final PE imports/directives contain only the approved CRT/provider/SDK
  closure and no Microsoft-STL DLL selection beyond Layer 1's already-approved
  narrow ABI helper.

**Potentially mergeable finish line:** Both Stage 1 builds pass the COM-owned
compile/link boundary with the same curated inputs available to ordinary MSVC
consumers; no package-stage or optimization-stage routing changes.

Risks/stop conditions:

- stop if the minimal headers transitively require the Microsoft STL include
  tree or a contradictory CRT family;
- stop if ARM64 lld-link selects ARM64EC members or cannot disambiguate the
  vendor fat archive;
- do not patch `_MSC_VER`, remove Setup Configuration, or duplicate Microsoft
  headers downstream. If the minimal vendor closure is fundamentally unusable,
  propose an upstream, feature-preserving optional Setup Configuration design
  and obtain owner approval before changing source semantics.

Upstream llvm-project patch expected: **no** on the preferred path; **possible
only after the stop condition**, with native discovery preserved when support
headers exist.

## Step 3 — Fix upstream Windows ARM64 architecture configuration

**Codex-agent-ready goal:** Make the LLVM Bazel overlay generate correct
ARM64 native configuration without changing other platform semantics.

Likely upstream files/targets:

- `llvm-project/utils/bazel/llvm-project-overlay/llvm/BUILD.bazel`:
  only the Windows CPU/compiler config settings needed by `config.bzl`;
- `llvm-project/utils/bazel/llvm-project-overlay/llvm/config.bzl`:
  `llvm_config_defines`;
- temporary identical downstream backports under
  `3rd_party/llvm-project/21.x/patches`,
  `3rd_party/llvm-project/22.x/patches`, and
  `3rd_party/llvm-project/x.x/patches`, plus `extensions/llvm.bzl` and patch
  package BUILD files.

Required semantics:

- Windows ARM64 clang-cl/MSVC defines `LLVM_NATIVE_ARCH="AArch64"`, all
  `LLVM_NATIVE_*` initializers as AArch64, and host/default triple
  `aarch64-pc-windows-msvc`;
- do not apply MSVC triples blindly to Windows GNU/MinGW. Add CPU/compiler-
  aware settings or preserve/define that route's GNU triple explicitly;
- Windows x86-64 retains its existing X86 configuration; Linux, macOS, and all
  other CPUs remain byte-for-byte semantically unchanged.

Build/action commands:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage1:llvm

bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //toolchain/bootstrap/stage1:llvm

bazel aquery --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  --include_param_files \
  'mnemonic("CppCompile", deps(//toolchain/bootstrap/stage1:llvm))' \
  --output=commands \
  --output_file=/tmp/windows-msvc-prebuilt-arm64-compiles.txt
```

Success criteria:

- materialized ARM64 params contain only AArch64 native initializer names and
  the intended ARM64 triple; x64 params remain X86/x86-64;
- the final ARM64 PE machine and reported default target agree with the
  configured ARM64 target;
- generic MinGW and non-Windows configured definitions remain correct.

**Potentially mergeable finish line:** The upstream-shaped ARM64 correction
and exact release-line backports produce correct configured definitions while
x64, MinGW, and non-Windows configurations retain their prior semantics. The
step is independently reviewable from downstream packaging and optimization.

Risks/stop conditions:

- stop if a single Windows CPU select would silently assign an MSVC triple to
  MinGW; model compiler/ABI distinctions in upstream-generic terms;
- stop if a backport embeds `@llvm` repository-specific labels, custom ABI
  constraints, or hermetic-llvm paths;
- do not use string substitution in generated files after compilation.

Upstream llvm-project patch expected: **yes**. Explain the Bazel target-
platform bug, compare to the CMake/native target result, and run relevant
upstream non-ARM64 and MinGW configurations. Submit only after the owner
separately authorizes upstream publication. Carry clean release-line backports
only until a source release contains the patch.

## Step 4 — Drive both Stage 1 builds to completion, one traced owner at a time

**Codex-agent-ready goal:** After Steps 1-3, build the entire monolithic LLVM
binary for both targets, record each next real failure, and fix only its owning
layer. Do not preemptively bulk-port Unix selects/flags.

Likely scope: no predetermined file beyond the demonstrated owners. Candidate
areas may include the LLVM overlay, hermetic MSVC argument groups, or declared
Windows inputs, but every new edit needs a saved failing action and source
owner before assignment.

Loop commands:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage1:llvm \
  --verbose_failures --materialize_param_files --remote_download_all

bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //toolchain/bootstrap/stage1:llvm \
  --verbose_failures --materialize_param_files --remote_download_all
```

For each failure, save the exact target, mnemonic, exec/target platforms,
command/response file, environment, missing input/tool, and source BUILD owner.
Classify before editing:

- LLVM overlay source/select/linkopts issue: upstream-quality patch and clean
  line backports;
- missing declared SDK/compiler/runtime file: smallest curated hermetic input;
- toolchain dialect/action variable issue: hermetic-llvm MSVC action layer;
- remote-only infrastructure/download/lost-input failure: rerun locally or on
  another claimed executor before altering BUILD semantics;
- resource exhaustion: reduce jobs/retain logs; do not change dependency
  semantics.

Specific audits after successful compilation:

- scan materialized compiler/linker response files for raw GNU-only `-Wl,`,
  `-L`, `-l`, flags rejected as errors or changing required release semantics,
  host absolute target paths, target/exec CPU leaks, undeclared input paths,
  and mismatched `.o`/`.a` suffixes. Record ignored non-blocking upstream flags
  without turning them into drive-by fixes;
- inspect all `CppArchive` commands for exec-host llvm-ar, target `.obj`
  members, target `.lib` output, `rcsD`, stable ordering, and response-file
  encoding;
- inspect all `CppLink` commands for clang-cl, sibling lld-link data,
  response-safe joined target/resource arguments, `/MACHINE`, `/Fe`,
  `/WHOLEARCHIVE`, SDK/runtime directories, and absence of target execution;
- confirm Windows-only/Unix-only source selects by tracing the configured
  source owner. The patched BLAKE3 Unix-named assembly is allowed only because
  its existing source patch explicitly supports non-ELF COFF assembly;
- inspect case-sensitive RBE inputs, especially `Ole2.h`/`OleCtl.h`, through
  the declared VFS/copy actions.

Success criteria:

- both full `//toolchain/bootstrap/stage1:llvm` targets compile, archive, and
  link, not merely analyze;
- x64 `llvm.exe` is `IMAGE_FILE_MACHINE_AMD64`; ARM64 is
  `IMAGE_FILE_MACHINE_ARM64` and not ARM64EC;
- no warning says a required product option was ignored;
- no ambient Visual Studio/SDK path appears in target actions;
- no new downstream-only LLVM source workaround exists.

**Potentially mergeable finish line:** Full Stage 1 `llvm.exe` builds for x64
and ARM64 with inspected PE/COFF outputs. Any new cross-cutting owner discovered
by the loop is split before this step is considered complete.

Risks/stop conditions:

- stop and split a newly discovered owner into its own patch if it changes
  LLVM source semantics, public toolchain behavior, or another platform;
- stop for a Microsoft payload redistribution/EULA change, missing vendor
  architecture library, incompatible ABI directive, or a required undeclared
  output;
- a remote executor failure reproduced only on BuildBuddy is reported as
  infrastructure-specific, not papered over with a local/non-hermetic action.

Upstream llvm-project patch expected: **only for traced overlay/source-owned
failures**. Every such change needs exact upstream file/target/semantic scope
and non-Windows regression coverage.

## Step 5 — Skipped: do not package or register Stage 1

The owner removed the Stage 1 package checkpoint from the delivery sequence.
There is no useful prebuilt product until ThinLTO and FDO Stage 3 are complete.

The unchanged feasibility probe recorded under Implementation progress proves
that the existing release rule can package both current PE binaries and that
the basic `.exe` layout survives extraction. Do not repeat that probe as a
merge gate, add Stage 1 package CI, publish its archives, update the prebuilt
index, or register them as compiler toolchains.

Keep the already-implemented manual labels and `llvm_binary` parameter only as
dormant temporary scaffolding needed for the final atomic promotion. Step 10
performs the first accepted package builds from proved Stage 3 inputs, runs the
archive checks formerly specified here, and removes all Step 1 debt.

## Step 6 — Move release intent from config-local dialect flags into toolchains

**Codex-agent-ready goal:** Give generic Clang and clang-cl the same effective
release policy through target-aware toolchain semantics, while keeping direct
Stage 1 behavior and every generic Stage 3 dependency unchanged. Dormant MSVC
package labels are not an acceptance or CI surface in this step.

Likely owned files:

- `.bazelrc`;
- `toolchain/bootstrap/bootstrap_binary.bzl`;
- `toolchain/cc_toolchain.bzl`;
- `toolchain/features/BUILD.bazel` and
  `toolchain/features/msvc/BUILD.bazel`;
- `toolchain/args/msvc/BUILD.bazel` only where an argument belongs to the
  MSVC platform closure rather than a feature;
- existing `e2e/rules_cc/windows_msvc_action_test.sh` and
  `.github/workflows/ci.yaml` for focused flag/dialect regression coverage.

Implementation shape:

- make C++17 a normal MSVC C++ compile default, parallel to the existing
  generic legacy default; do not keep `/std:c++17` in a product config;
- represent release no-exceptions, no-RTTI, and frame-pointer intent with
  target-aware features named `llvm_release_no_exceptions`,
  `llvm_release_no_rtti`, and `llvm_release_omit_frame_pointer`: retain the
  current effective GNU spellings for the generic toolchain and use audited CL
  or `/clang:` spellings for clang-cl;
- make the post-Stage-1 bootstrap transition request those semantic features
  instead of appending raw GNU `_LLVM_TOOL_COPTS` to every target dialect;
- make the transitional `windows_msvc_prebuilt` config request the same
  release-policy semantics while it still selects Stage 1; remove its
  config-local `/std:c++17`, exception, RTTI, and frame-pointer flags;
- preserve `--config=release`'s current opt, strip, ThinLTO, static dependency,
  toolchain-registration, and execution-platform behavior. Do not move or
  broaden existing generic execution-platform selection as part of this
  MSVC-owned refactor;
- save representative generic Linux, macOS, and GNU Windows release aquery
  parameters before editing and compare effective flags/tools afterwards.
- extend the existing MSVC action script to assert the C++17 and release
  semantic spellings and the absence of ignored GNU spellings; keep its
  existing archive/link assertions intact.

Build/action commands:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage1:llvm

bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //toolchain/bootstrap/stage1:llvm

bazel aquery --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  --include_param_files \
  'mnemonic("CppCompile", deps(//toolchain/bootstrap/stage1:llvm))' \
  --output=commands \
  --output_file=/tmp/windows-msvc-prebuilt-release-semantics.txt
```

Success criteria:

- MSVC C++ actions contain `/std:c++17`; release LLVM actions receive the
  intended exception, RTTI, and frame-pointer policy with no ignored raw
  `-fno-*` argument;
- Linux exec-platform tools receive only the generic dialect selected by their
  own configured target platform; no `/std:`, `/EH`, or `/GR` leaks into them;
- generic representative release actions retain the same effective flags,
  tools, target triples, artifacts, and Stage 3 dependencies;
- the dormant MSVC package labels are not built, registered, or added to CI.

**Potentially mergeable finish line:** Release-policy ownership moves into the
toolchains with demonstrated generic semantic equivalence. Direct Stage 1
behavior remains buildable and the remaining Step 1 debt is stage selection,
ThinLTO suppression, and the dormant release-rule parameterization.

Risks/stop conditions:

- stop if the refactor changes generic optimization meaning, user-flag
  precedence, or bootstrap exec-tool flags without an explicit owner-approved
  compatibility decision;
- do not infer target dialect from the machine running Bazel or from an exec
  host string; use configured target constraints/features.

Upstream llvm-project patch expected: **no**.

## Step 7 — Implement the clang-cl/COFF ThinLTO action protocol

**Codex-agent-ready goal:** Make `thin_lto` a real supported MSVC toolchain
feature for compile, index, backend, archive, and final-link actions with
source-backed bootstrap tools, without promoting or building the dormant
package labels. Stage 0 prebuilt ThinLTO is not part of this contract.

Likely owned files:

- `toolchain/features/msvc/BUILD.bazel`;
- `toolchain/cc_toolchain.bzl`;
- `toolchain/bootstrap/declare_toolchains.bzl`;
- `toolchain/llvm/llvm.bzl` for the installed/prebuilt MSVC action bindings,
  while correctness proof uses `stage1_from_source` or a later source-backed
  bootstrap stage;
- existing `e2e/rules_cc/windows_msvc_action_test.sh`, artifact inspection
  macros/scripts, and `.github/workflows/ci.yaml`;
- a focused rules_cc compatibility patch only if a demonstrated action
  variable or COFF artifact protocol cannot be expressed by the current
  repository-owned feature.

Implementation shape:

- do not attach the pinned generic rules_cc ThinLTO feature blindly: it emits
  clang-driver `-Wl,`, `-o`, and `-x ir` spellings;
- define an MSVC feature named `thin_lto` with clang-cl-correct bitcode,
  indexing, imports, prefix/suffix replacement, merged object, backend input,
  backend index, and `.obj` output arguments;
- bind the `lto_backend` action to an exec-platform LLVM driver with a coherent
  argument dialect; route all three index variants through normal clang-cl and
  keep its declared sibling lld-link as the COFF index/final linker;
- use configured artifact naming and existing independent response-file
  protocols; never hardcode `.o`, an exec CPU, or an exec-host path;
- remove `--features=-thin_lto` from the temporary product config once Stage 1
  does not request ThinLTO by default, and remove only `thin_lto` from Layer
  1's unsupported list after both architectures pass;
- leave all generic toolchains on the existing rules_cc ThinLTO feature and do
  not route `windows_msvc_llvm_release` to Stage 2/3 in this step.
- extend the existing MSVC action test with a source-backed
  `--features=thin_lto` query that asserts compile/index/backend/link tools and
  spellings, no compatibility launcher or linker-path environment, and extend
  the existing artifact CI cell to build/inspect a ThinLTO PE for both CPUs.

Build/action commands:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --features=thin_lto \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  --//toolchain:bootstrap_stage=stage1_from_source \
  @llvm-project//llvm:llvm --remote_download_all

bazel build --config=remote --config=windows_msvc_prebuilt \
  --features=thin_lto \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  --//toolchain:bootstrap_stage=stage1_from_source \
  @llvm-project//llvm:llvm --remote_download_all

bazel aquery --config=remote --config=windows_msvc_prebuilt \
  --features=thin_lto \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  --//toolchain:bootstrap_stage=stage1_from_source \
  'deps(@llvm-project//llvm:llvm)' \
  --output=text --include_artifacts=true \
  --output_file=/tmp/windows-msvc-prebuilt-thinlto-x64.txt
```

Success criteria:

- both full LLVM builds contain ThinLTO bitcode/index/backend actions and link
  a valid AMD64/ARM64 PE; merely passing `-flto=thin` to one compile is not
  sufficient;
- index and backend actions use declared exec-platform LLVM tools, MSVC target
  triples, COFF inputs, configured backend `.obj` outputs, and declared
  response files; the rules_cc merged internal may remain `.lto.merged.o` when
  its COFF contents and final-link consumption are proved;
- no raw generic-only `-Wl,`, `-o`, or `-x ir` token is ignored by clang-cl;
- non-ThinLTO direct Stage 1 commands retain their prior action graph;
- existing generic ThinLTO aquery topology and artifacts are unchanged.

**Potentially mergeable finish line:** `--features=thin_lto` is independently
supported and artifact-proved for source-backed MSVC targets, while the manual
MSVC prebuilt labels remain dormant temporary scaffolding. All other Layer 1
rejected capabilities remain rejected.

Risks/stop conditions:

- stop if support requires disabling distributed/indexed ThinLTO globally,
  changing rules_cc's generic feature semantics, or hiding an ignored driver
  option;
- split a rules_cc defect into a focused upstream/downstream compatibility
  patch with a minimal COFF reproduction before continuing the LLVM build.

Upstream patch expected: **no additional llvm-project patch and no rules_cc
patch for the proved executable path**. The lld weak-alias correction remains
an LLVM-owned patch; dynamic-library ThinLTO variants remain outside this
monolithic executable acceptance surface.

## Step 8 — Generate and merge MSVC-target bootstrap FDO profiles

**Codex-agent-ready goal:** Use ThinLTO/instrumented Linux exec-platform Stage
2 compilers in clang-cl mode to compile/link explicit MSVC workloads, emit raw
profiles from those compiler processes, and merge them with declared Linux
`llvm-profdata`, without applying the profile or changing package stage yet.

Likely owned files:

- `toolchain/bootstrap/fdo_profile.bzl`;
- `toolchain/bootstrap/stage3/BUILD.bazel`;
- `toolchain/bootstrap/declare_toolchains.bzl`;
- `.github/workflows/ci.yaml` for default-LLVM MSVC profile build/inspection.

Implementation shape:

- reuse the existing generic `host_profile` instrumentation when building the
  Stage 2 compiler for its Linux exec platform. That ELF compiler process emits
  `.profraw` while invoked through the `clang-cl` multicall name; do not
  instrument the Windows workload or link a target profile runtime into it;
- bind `ACTION_NAMES.llvm_profdata` in the MSVC bootstrap tool map to the
  existing exec-platform Stage 1 `llvm-profdata` tool and ensure it is in the
  action's declared tool closure;
- replace hardcoded workload `.o` names with the configured toolchain artifact
  name for an object, producing `.obj` on MSVC;
- replace hardcoded GNU workload flags with target-aware workload semantics.
  Preserve the existing zstd workload sources and generic flags exactly; use
  audited clang-cl/lld-link spellings for the workload's optimization,
  ThinLTO, frame-pointer, language, defines, and hosted link behavior;
- add explicit x64 and ARM64 MSVC workload labels for both existing Linux FDO
  executor architectures. They compile/link Windows targets but do not execute
  the resulting PE;
- add an MSVC-only profile aggregate/alias containing the existing workload
  set plus the MSVC workloads. Do not add MSVC workloads to the existing
  generic `llvm_fdo_profdata_linux_*` lists or change their configured deps;
- keep public `//config:profile`, coverage, sanitizers, and unrelated Layer 1
  features rejected. The MSVC target toolchain does not gain target-program
  profile instrumentation in this step;
- add a default LLVM 22.1.8 CI cell that builds both selected MSVC profile
  aliases and records `llvm-profdata show`; reuse the existing MSVC/LLVM job
  structure and EULA handling.

Build/action commands:

```sh
bazel build --config=remote --config=release --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage3:llvm_fdo_profdata_msvc \
  --remote_download_toplevel

bazel build --config=remote --config=release --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //toolchain/bootstrap/stage3:llvm_fdo_profdata_msvc \
  --remote_download_toplevel

bazel aquery --config=remote --config=release --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  'deps(//toolchain/bootstrap/stage3:llvm_fdo_profdata_msvc)' \
  --output=text --include_artifacts=true \
  --output_file=/tmp/windows-msvc-prebuilt-fdo-profile-x64.txt
```

Download each merged profile and inspect it with `llvm profdata show
--counts --all-functions <profile>`. Record raw profile count, merged profile
size, representative compiler functions, and any hash/out-of-date warning.

Success criteria:

- aquery shows ThinLTO/instrumented Stage 2 compiler tools executing on Linux,
  clang-cl MSVC-target workload compile/link actions, nonempty `.profraw`
  outputs, and one declared Linux `llvm-profdata` merge;
- x64 workload outputs are AMD64 COFF and ARM64 outputs are pure ARM64 COFF;
- the hosted zstd workload links for MSVC without `-pthread`, GNU-only linker
  tokens, a target profile runtime, ambient SDK paths, or running its PE
  output;
- merged profiles are nonempty and readable; profile generation does not rely
  on a target Windows executor;
- existing generic profile aggregate labels have the same configured workload
  dependency lists as before.

**Potentially mergeable finish line:** A direct MSVC-only profile label builds
and yields inspected profile data, but no public release or Stage 3 label
consumes it yet. ThinLTO remains independently supported and generic profiles
remain unchanged.

Risks/stop conditions:

- stop if profile generation requires executing the Windows workload binary;
  the intended data comes from the instrumented Linux compiler process;
- stop if the only design changes the existing generic profile contents or
  configures MSVC dialect flags into Linux target tools;
- split a rules_cc FDO variable defect when it has an independently
  reproducible owner.

Upstream patch expected: **no llvm-project patch**; **possible focused
rules_cc patch only for a demonstrated FDO action-variable defect**.

## Step 9 — Apply the MSVC profile and prove the direct Stage 3 binary

**Codex-agent-ready goal:** Add clang-cl-correct instrumentation-profile use,
select the MSVC-only aggregate for MSVC Stage 3, and build the direct Stage 3
LLVM binaries with both ThinLTO and FDO before any package label is promoted.

Likely owned files:

- `toolchain/features/msvc/BUILD.bazel`;
- `toolchain/cc_toolchain.bzl`;
- `toolchain/bootstrap/stage3/BUILD.bazel`;
- `toolchain/bootstrap/bootstrap_binary.bzl` only if the existing transition
  cannot request the semantic features from Step 6 without dialect leakage;
- `.github/workflows/ci.yaml` for default-LLVM direct Stage 3 builds.

Implementation shape:

- implement an MSVC FDO-optimize feature using the existing
  `fdo_profile_path` variable and clang-cl-correct profile-use/warning
  arguments; do not reuse the generic GNU argument group blindly;
- make that feature known to the MSVC toolchain so Bazel's configured
  `--fdo_profile` path activates it on compile and ThinLTO backend actions as
  required;
- make `stage3:llvm_fdo_profdata` select the MSVC aggregate only for the two
  explicit MSVC platforms. Preserve the existing alias and configured deps for
  every generic platform;
- retain the normal Stage 3 bootstrap topology and tool-stage transitions; do
  not create an MSVC-specific replacement bootstrap macro;
- keep `windows_msvc_llvm_release` on Stage 1 until this direct binary and its
  complete aquery/artifacts pass for both target CPUs; do not build or register
  that dormant package target.
- add default LLVM 22.1.8 direct Stage 3 x64/ARM64 builds to the existing
  MSVC/LLVM CI surface; no package cell exists before Step 10.

Build/action commands:

```sh
bazel build --config=remote --config=release --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage3:llvm --remote_download_toplevel

bazel build --config=remote --config=release --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //toolchain/bootstrap/stage3:llvm --remote_download_toplevel

bazel aquery --config=remote --config=release --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  'deps(//toolchain/bootstrap/stage3:llvm)' \
  --output=text --include_artifacts=true \
  --output_file=/tmp/windows-msvc-prebuilt-stage3-x64.txt
```

Success criteria:

- both direct outputs are valid AMD64/ARM64 PE binaries;
- cquery/aquery contains the expected Stage 1 tools, ThinLTO/instrumented Stage
  2 tools, explicit MSVC workloads, `LLVMFDOProfileMerge`, and ThinLTO/FDO-
  applied Stage 3 actions;
- Stage 3 compile/backend parameters reference the merged MSVC profile and
  contain clang-cl-correct profile-use flags; the profile is a declared input;
- no FDO out-of-date/hash warning is hidden. Any expected partial profile
  coverage caused by platform-conditional LLVM code is quantified and accepted
  explicitly rather than suppressed without evidence;
- generic Stage 3 cquery dependency topology and representative aquery
  commands remain unchanged.

**Potentially mergeable finish line:** Direct `//toolchain/bootstrap/stage3:llvm`
is fully buildable for both MSVC platforms with inspected ThinLTO and FDO
actions/artifacts. The dormant package labels are not accepted until the next
atomic promotion/cleanup step.

Risks/stop conditions:

- stop if the only profile that applies cleanly was generated by dropping the
  MSVC workloads, disabling ThinLTO, or changing the generic profile;
- stop if Bazel applies the target profile to Linux exec-configured helper
  tools or requires executing the final PE during the build.

Upstream llvm-project patch expected: **no** unless an exact LLVM source/build
select fails only under the now-proved optimization configuration.

## Step 9.1 — Restore minimized clang-cl/COFF ThinLTO indexing

**Codex-agent-ready goal:** Replace the conservative full-bitcode ThinLTO
index inputs from Step 7 with Clang's minimized thin-link bitcode for Windows
MSVC, while retaining the complete bitcode objects for every backend. Prove
the correction against the completed direct Stage 3 ThinLTO/FDO graph before
any package label is promoted.

Demonstrated starting facts:

- before Step 9.1, Step 7 made MSVC `thin_lto` imply
  `no_use_lto_indexing_bitcode_file`, so rules_cc neither declares the
  minimized compile output nor passes `-fthin-link-bitcode`;
- the comment that lld-link cannot consume Clang's minimized bitcode is not
  supported by LLVM's implementation. LLVM 22.1.8 contains
  `lld/test/COFF/thinlto-object-suffix-replace.ll`, which indexes a minimized
  thin-link file, maps its suffix back to the full `.obj`, and compares its
  index with the full-bitcode result;
- rules_cc's normal path declares a `.indexing.o` summary output, passes it to
  the index action, and supplies `thinlto_object_suffix_replace` to map that
  name to the configured target object extension. Its TODO about deriving the
  `.indexing.o` spelling from Starlark file types is a naming TODO, not an LLVM
  support boundary;
- the downstream lld COFF weak-alias prevailing fix remains required and is
  semantically independent of whether the index reads the full or minimized
  representation.

Completion evidence (2026-08-22):

- baseline compile/index/backend action captures proved that the MSVC feature
  forced complete `.obj` inputs into indexing and suppressed the minimized
  output; the focused regression failed before the fix because
  `/clang:-fthin-link-bitcode=` was absent;
- source-backed full LLVM builds passed for x86-64 (invocation
  `dc041e77-2991-4618-a23b-e7af0a64567c`) and ARM64 (invocation
  `22543b16-f224-4e92-9c26-084321cdf23f`);
- direct profiled Stage 3 builds passed for x86-64 (invocation
  `20f7251b-b159-4217-97de-b271d4d0413d`) and ARM64 (invocation
  `cef15446-e68c-4e02-8141-cdf3a6533225`), with AMD64 and native ARM64 PE
  outputs respectively;
- the same direct Stage 3 builds passed unchanged on LLVM 21.1.8 for x86-64
  (invocation `7f44605b-6473-4f40-a852-9c35eba324c5`) and ARM64 (invocation
  `2efc19d0-758f-4377-bb73-575f0beff61b`);
- representative compile, index, and backend actions proved the intended
  split. Indexing declares `.indexing.o` and uses
  `/thinlto-object-suffix-replace:.indexing.o;.obj`; backends declare the
  complete `.obj`, imports, and index, and final-link parameters contain no
  `.indexing.o`;
- the focused MSVC action regression, both MSVC artifact tests, negative MSVC
  analysis boundaries, buildifier, and representative Linux and MinGW
  ThinLTO builds passed. Generic actions retain their GNU protocol;
- no full remote download was used. Selective regular-expression downloads
  materialized only representative complete/minimized objects and final-link
  parameters.

Likely owned files:

- `toolchain/features/msvc/BUILD.bazel`;
- existing `e2e/rules_cc/windows_msvc_action_test.sh` and artifact inspection
  coverage;
- an LLVM source/backport patch only if the complete minimized graph exposes a
  focused LLVM defect that also reproduces outside hermetic-llvm;
- a rules_cc patch only if its standard minimized/full mapping produces an
  incorrect declared action after the existing COFF artifact fixes.

Implementation shape:

- before editing, capture representative Step 9 compile, index, backend, and
  final-link actions that demonstrate the current full-bitcode indexing route;
- remove the MSVC `thin_lto` implication of
  `no_use_lto_indexing_bitcode_file`. Remove the local feature declaration and
  feature-set entry only if no live MSVC caller remains; do not change Bazel or
  generic toolchains' support for the feature;
- let the existing `lto_indexing_bitcode_file` variable make clang-cl emit both
  the complete ThinLTO `.obj` and rules_cc's separate minimized `.indexing.o`;
- make the index action consume the minimized file and the existing
  `/thinlto-object-suffix-replace` protocol, while every backend continues to
  consume its corresponding complete bitcode `.obj`, generated index, and
  imports;
- replace the incorrect full-bitcode comment and negative tests with focused
  assertions for the actual dual-output/index/backend contract. Do not rename
  `.indexing.o` to `.indexing.obj` merely for Windows aesthetics; it is an
  internal rules_cc artifact whose mapped target/backend output remains
  `.obj`;
- compare a representative minimized file with its complete bitcode object
  using `llvm-dis --print-thinlto-index-only`, `llvm-bcanalyzer`, and byte
  sizes. The minimized input must not contain function bodies needed by the
  backend;
- preserve source-backed clang-cl and its declared sibling source-built
  lld-link, COFF response protocols, target `.obj` backend outputs, and the
  Step 9 FDO profile inputs/flags;
- if the complete graph fails, classify the exact owner before editing:
  hermetic MSVC feature, rules_cc/Bazel action protocol, LLVM Clang bitcode
  writer, lld COFF input/symbol resolution, declared input, remote
  infrastructure, or resource exhaustion. Do not infer an LLVM defect from a
  linker symptom;
- develop a proved LLVM semantic fix against current upstream main with a
  focused fail-before/pass-after regression, then carry the same supported-line
  backport for LLVM 22.1.x. Do not invent an LLVM production change if the
  existing implementation is already correct, and do not publish an upstream
  review without separate authorization.

Build/action commands:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --features=thin_lto \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  --//toolchain:bootstrap_stage=stage1_from_source \
  @llvm-project//llvm:llvm --remote_download_toplevel

bazel build --config=remote --config=windows_msvc_prebuilt \
  --features=thin_lto \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  --//toolchain:bootstrap_stage=stage1_from_source \
  @llvm-project//llvm:llvm --remote_download_toplevel

bazel build --config=remote --config=release --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage3:llvm --remote_download_toplevel

bazel build --config=remote --config=release --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  //toolchain/bootstrap/stage3:llvm --remote_download_toplevel

bazel aquery --config=remote --config=release --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  'deps(//toolchain/bootstrap/stage3:llvm)' \
  --output=text --include_artifacts=true \
  --output_file=/tmp/windows-msvc-prebuilt-minimized-thinlto-x64.txt
```

Prefer selective BuildBuddy downloads or `--remote_download_regex` for
representative complete/minimized bitcode, index, backend, and merged objects.
Use `--remote_download_all` only when an exact inspection cannot otherwise
materialize its required artifact, and record why.

Success criteria:

- x64 and ARM64 compile actions declare both the complete ThinLTO `.obj` and a
  nonempty, substantially smaller `.indexing.o`, with
  `-fthin-link-bitcode=<declared output>` reaching clang-cl correctly;
- every `CppLTOIndexing` action declares the minimized objects and does not
  declare the corresponding complete bitcode objects merely for indexing;
- every ThinLTO backend declares the complete bitcode `.obj`, its index and
  imports, and produces the configured target `.obj`; no backend attempts to
  compile the minimized representation;
- suffix/prefix replacement and final-link parameter files name the complete
  backend/native `.obj` paths, not `.indexing.o`, with no ambient path or host
  CPU leak;
- complete source-backed ThinLTO and direct Stage 3 ThinLTO/FDO LLVM builds
  finish for both targets. Final outputs inspect as AMD64 and native ARM64,
  not ARM64EC;
- the lld weak-alias/COMDAT case remains correct under minimized indexing;
- representative full-input and minimized-input lld indexes are semantically
  equivalent, while measured index-action inputs demonstrate the intended
  transfer/parse reduction;
- generic Linux, macOS, GNU/MinGW, and unrelated MSVC actions retain their
  existing feature selection, tools, arguments, and artifacts.

**Completed finish line:** Both complete direct Stage 3 products use minimized
summary inputs only for ThinLTO indexing and complete bitcode only for
backends, with inspected action and PE proof. Package labels remain dormant
until Step 10.

Risks/stop conditions:

- do not call a successful small `lld-link` probe sufficient; the complete
  source-backed and FDO-applied LLVM graphs are the acceptance boundary;
- stop before a change to LLVM source semantics beyond a focused reproduced
  COFF ThinLTO defect, to generic rules_cc ThinLTO behavior, or to another
  platform;
- do not fall back silently to full-bitcode indexing, disable ThinLTO/FDO, or
  drop the weak-alias fix to make the build pass.

Upstream patch expected: **none based on the demonstrated LLVM 22.1.8
contract; prepare an llvm-project or rules_cc patch only for an independently
reproduced defect exposed by the complete graph**.

## Step 10 — Build the first MSVC packages from Stage 3 and remove Step 1 debt

**Codex-agent-ready goal:** After both direct Stage 3 binaries pass, atomically
switch the dormant MSVC package labels from the temporary Stage 1 route to the
normal Stage 3 input, use the canonical `--config=release`, remove all obsolete
Step 1 plumbing, build the first accepted MSVC archives, and inspect them.

Completion evidence (2026-08-22):

- baseline aquery `12089790-a7b2-4bea-8a7c-645e678f0852` showed the MSVC
  package backed by Stage 1 with no FDO merge. Post-change aquery
  `b19129b1-47f9-453b-85a8-e11151920fa8` shows Stage 3, four configured profile
  merges, minimized ThinLTO indexing, complete-object backends, and the normal
  clang-cl/lld-link final route;
- pre/post GNU x86-64 package aquery dumps from
  `75b7ad7f-c1e6-4fee-9502-169a9267801b` and
  `cad7df14-a027-466c-88ec-3a7e26c0c64f` are byte-identical, SHA-256
  `e9f900490307c0d57cc8d691e33f0c07feda19ecfd697545cf2cd985e00b5c6a`;
- the dual-package build, archive sizes/hashes, PE metadata, layout, imports,
  debug directories, fixed metadata, stable path ordering, and absence of
  unexpected packaged outputs are recorded under Implementation progress;
- representative x86-64 and ARM64 params retain their MSVC triples,
  `/std:c++17`, ordered release-policy flags, declared MSVC profile use,
  minimized `.indexing.o` output, complete `.obj` backend route, `/MACHINE`,
  `/Fe`, SDK/runtime library directories, deterministic `llvm-ar rcsD`,
  sentinel `LIB`, and no ambient host path or raw GNU linker protocol;
- buildifier (`cd0ce6d6-9f09-4822-9f13-6cfc0330bf41`), Gazelle diff
  (`e2d3a748-c7bb-425b-9c2e-da0e3aec6cae`), public Starlark docs
  (`602b4a63-af8f-4409-8e54-3083b250dce8` and
  `ba2174b9-cb51-4f6c-943a-2c2aec033361`), focused action/analysis checks, and
  both artifact tests (`31073324-5e9f-450d-ae1a-e533d72e0425`) passed;
- commits `5aecdb5e` and `1088aa68` implement the promotion/cleanup and CI
  enforcement separately. They have not been pushed and CI has not been
  triggered or monitored.

Likely owned files:

- `.bazelrc`;
- `prebuilt/llvm/BUILD.bazel`;
- `prebuilt/llvm/llvm_release.bzl`;
- `.github/workflows/ci.yaml` to add the canonical Stage 3 package build;
- only if previously proven necessary,
  `toolchain/bootstrap/bootstrap_binary.bzl` for generic configured executable
  suffix preservation.

Implementation shape:

- make `windows_msvc_llvm_release` consume the default
  `//toolchain/bootstrap/stage3:llvm`, retaining its explicit compatibility and
  platform-transition wrappers;
- remove `--config=windows_msvc_prebuilt` entirely;
- remove the `llvm_binary` argument and Stage 1 override if no non-test caller
  remains. If an independently useful caller exists, keep the parameter but
  remove the override and document that the public MSVC product uses Stage 3;
- remove all remaining config-local C++17/release-policy/ThinLTO suppression
  from Step 1; C++17 and dialect-aware release semantics remain in their
  toolchain-owned final locations;
- use the existing release mtree/tar/layout and `.exe` aliases unchanged;
- add a default LLVM 22.1.8
  `--config=remote --config=release` Stage 3 package build; retain the direct
  Stage 3 and focused action/profile assertions;
- compare generic package cquery/aquery topology before and after the promotion.

Build/artifact commands:

```sh
bazel build --config=remote --config=release \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  //prebuilt/llvm:for_windows_x86_64_msvc \
  //prebuilt/llvm:for_windows_aarch64_msvc \
  --remote_download_toplevel

bazel cquery --config=remote --config=release \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  'set(//prebuilt/llvm:for_windows_x86_64_msvc //prebuilt/llvm:for_windows_aarch64_msvc)' \
  --output=files

bazel aquery --config=remote --config=release \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  'deps(//prebuilt/llvm:for_windows_x86_64_msvc)' \
  --output=text --include_artifacts=true \
  --output_file=/tmp/windows-msvc-prebuilt-final-x64.txt
```

For each cquery-reported archive, extract to a fresh `mktemp -d` directory and
inspect the release layout and PE metadata:

```sh
bsdtar -tvf <archive.tar.zst>
bsdtar -xf <archive.tar.zst> -C <temporary-directory>
llvm readobj --file-headers --coff-imports --coff-debug-directory \
  <temporary-directory>/bin/llvm.exe
```

Also inspect the final action dump for each expected optimization stage and for
absence of the deleted config/Stage 1 package override.

Success criteria:

- both wrappers resolve to `windows_msvc_llvm_release`, the intended MSVC
  platform, and Stage 3 under `--config=remote --config=release`;
- action graphs contain ThinLTO Stage 2/3, MSVC workloads, nonempty profile
  merge, and FDO application; no dedicated product config is needed;
- cquery reports one `.tar.zst` per transition label in distinct platform
  output directories;
- the existing release genrules complete on the claimed Linux RBE construction
  host and preserve fixed manifest ownership, modes, mtimes, aliases, and
  ordering without storing an absolute execroot path;
- archives contain valid matching-machine `bin/llvm.exe`, existing `.exe`
  aliases, Clang builtin headers, and both ignorelists;
- the optimized EXE has no import-library output. A PDB is absent without a
  CodeView/PDB requirement or is deliberately declared and packaged; an
  orphaned reference is a failure;
- `.bazelrc` contains no `windows_msvc_prebuilt`; the MSVC release has no
  Stage 1 override; `llvm_binary` parameterization is gone unless its retained
  independent caller is named and tested;
- existing GNU Windows wrappers still select GNU platforms and their original
  generic Stage 3 graph.

**Completed finish line:** This is the final product merge point:
one canonical release config and the same truthful optimized bootstrap topology
for generic and MSVC products, with platform-specific action dialects only.
No temporary Step 1 mechanism remains.

Risks/stop conditions:

- stop rather than promote if either direct Stage 3 proof is incomplete, if
  cleanup would change a generic package graph, or if the archive loses its
  configured `.exe` artifact;
- do not retain the temporary config as a fallback. A fallback that silently
  returns to Stage 1 would make the public support claim configuration-dependent.

Upstream llvm-project patch expected: **no**.

## Step 10.1 — Make release compiler archives runtime-self-contained

**Codex-agent-ready goal:** Ensure accepted Windows MSVC release compilers do
not depend on an ambient Visual C++ redistributable, while leaving the ordinary
MSVC consumer default and the generic bootstrap graph unchanged.

Owner review and final implementation (2026-08-22):

- baseline Step 10 archive inspection showed `/MD`-built compilers importing
  `MSVCP140.dll`, `VCRUNTIME140.dll`, and, on x86-64,
  `VCRUNTIME140_1.dll`. Neither archive packaged Microsoft DLLs, so execution
  on a GitHub Windows image would have relied on ambient machine state;
- the first implementation, `b226292b`, added a `static_msvc_runtime`
  attribute to generic `bootstrap_binary` and selected it only from Stage 3.
  This produced self-contained executables but put product/ABI policy in a
  generic bootstrap rule and covered only one product stage;
- the accepted follow-up, `e98a818b`, removes that attribute and all Stage 3
  selection. `common:release` now requests
  `--features=-dynamic_link_msvcrt` followed by
  `--features=static_link_msvcrt`. MSVC toolchains interpret those semantic
  features as `/MT`; generic toolchains do not provide them and retain their
  established release actions;
- consumers that do not request `--config=release` retain the toolchain's
  ordinary `/MD` default. The existing action test passed after the change,
  beginning with invocation `1c5dc2a9-9224-4c97-9bfc-98360627622c` and
  explicitly observing `/MD` on the representative consumer compile;
- a controlled GNU/MinGW comparison queried the same compile and link once
  with the two MSVC release feature requests (invocation
  `fdc25c52-6d8d-4aaf-9208-803d94be181b`) and once without them (invocation
  `eaf4d25e-6a33-44c7-ad70-5118c72cc291`). Commands differed only in Bazel's
  transitioned-configuration path segment; after normalizing that segment,
  both command files have SHA-256
  `8f5ef0203ceaddfa2ea951f6d5efcaa31eda4800d8af1259f24c282426f2751b`.

The identical dual archive command from Step 10 then passed as invocation
`ce05848d-268f-4fad-a43e-dcc203758bb3` with only top-level downloads:

| Product | Archive bytes | Archive SHA-256 | `llvm.exe` SHA-256 | Machine |
|---|---:|---|---|---|
| x86-64 MSVC | 45,233,312 | `bc7731b9d0b661f646c8de4ec24598b18b85b456a375f6e744fcc24a4be8e868` | `c2c8c16042fb25e15dc26655cf80d35aacf4cb83a191ad69a62cf687fdbc1afe` | AMD64 |
| ARM64 MSVC | 42,245,669 | `3fc3667774f3c8545411e5558601683f7705d6a8654d3c097c664c6acf4eb30a` | `10481ac9cc2555bdae0dbc341f0839fc65fc7ff536877d9884707f22d6e430bf` | native ARM64 |

Fresh extraction plus `llvm readobj --file-headers --coff-imports` showed the
same system-DLL-only import set for both executables: `VERSION.dll`,
`ole32.dll`, `ntdll.dll`, `ADVAPI32.dll`, `SHELL32.dll`, `OLEAUT32.dll`, and
`KERNEL32.dll`. Neither imports `MSVCP*` nor `VCRUNTIME*`; ARM64 is not
ARM64EC. Buildifier passed as invocation
`9ab328c9-1ad3-43b1-807b-3f5cc5732064`.

**Completed finish line:** Windows MSVC products built under the canonical
release config use the static retail CRT and are self-contained with respect to
the Visual C++ redistributable. Generic bootstrap remains ABI-agnostic and
ordinary MSVC consumers remain `/MD` unless their product configuration asks
for static CRT semantics.

Upstream patch expected: **no**.

## Step 11 — Register the MSVC-built prebuilts and exercise them as compiler toolchains

**Codex-agent-ready goal:** Make the final Windows MSVC Stage 3 archives
selectable as the version-neutral Windows compiler prebuilts, then add an
explicit Windows MSVC consumer row alongside the existing Windows MinGW row.
Prove both target routes with the selected prebuilt compiler; do not replace or
weaken the MinGW row.

Preconditions:

- Step 10 produced and inspected the default LLVM 22.1.8 x86-64 and ARM64
  Stage 3 archives;
- Step 10.1 proved that the accepted release executables do not depend on an
  ambient MSVC redistributable;
- local registration/testing may use an exact temporary index or repository
  override without publication;
- committing release URLs and SHA-256 entries requires separately authorized,
  completed release upload. Do not commit a placeholder URL, local path, or
  unpublished index entry.

Likely owned files after the registration path is proved:

- `extensions/llvm_toolchain_minimal_index.json` for real published release
  metadata;
- `extensions/llvm_toolchain_minimal.bzl` only if the existing version-neutral
  Windows repository selection cannot consume the archives unchanged;
- `toolchain/llvm/llvm_release_windows.BUILD.bazel` or toolchain registration
  only for an exact exposed archive/tool mismatch;
- `.github/workflows/ci.yaml`, a narrow CI-local registration helper, and the
  existing Windows consumer targets.

Local implementation evidence (2026-08-22):

- the helper derives the selected LLVM version from the root `MODULE.bazel`,
  computes the archive SHA-256, changes exactly the corresponding
  `windows-amd64` or `windows-arm64` entry in a generated index, and registers
  all version-neutral repositories from a second CI-only extension instance;
- a real x86-64 `http_archive` import using the generated index passed as
  invocation `0dc7ed3a-1350-41d4-bacf-b2147732ed74`. The selected
  version-neutral repository exposed the expected AMD64 compiler with
  SHA-256
  `c2c8c16042fb25e15dc26655cf80d35aacf4cb83a191ad69a62cf687fdbc1afe`;
- the corresponding ARM64 import passed as invocation
  `c3140e31-4544-4214-8277-a7c4d7a2357a` and exposed the expected native
  ARM64 compiler with SHA-256
  `10481ac9cc2555bdae0dbc341f0839fc65fc7ff536877d9884707f22d6e430bf`;
- therefore no extension implementation, Windows BUILD overlay, public index,
  tool map, repository name, or ABI-specific repository namespace changed;
- workflow YAML parsing, helper execution against a fresh temporary module,
  `git diff --check`, and buildifier passed locally. Matching-Windows compiler
  execution, action selection, compile/link/archive behavior, and test
  execution remain pending because the workflow commit has not been pushed or
  run.

Implementation shape:

- first try the existing `windows-amd64` and `windows-arm64` minimal repository
  names and Windows BUILD overlay unchanged. The compiler executable's own MSVC
  ABI does not by itself require a second target-toolchain namespace;
- select the exact Step 10 archive and hash in an isolated local proof. Confirm
  that configured compile/link tools resolve from that archive rather than a
  source-built or older cached seed;
- add one MSVC consumer entry for each matching Windows runner architecture,
  analogous to the existing MinGW compilation-toolchain entry. Use the MSVC
  platform, EULA repo-env gates, local execution platform, and representative
  compile/link/test targets already owned by the Windows MSVC surface;
- retain the MinGW entry and prove it still selects the GNU/MinGW target
  configuration while using the same version-neutral compiler repository as
  appropriate;
- inspect the selected `llvm.exe` imports before claiming the prebuilt is a
  portable Windows construction tool. Do not rely silently on an ambient
  VCRuntime DLL or redistribute Microsoft runtime payloads in the archive;
- while the archive remains unpublished, build it as an ephemeral prerequisite
  in each matching Windows consumer cell and register it through an exact
  generated local index. Do not keep a separate package-only CI family whose
  result is never consumed;
- after publication is separately authorized and completed, replace the local
  proof with the real release URL/SHA index entry and rerun both consumer rows.

Representative consumer commands after registration:

```sh
bazel build \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --extra_execution_platforms=@platforms//host:host \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  --spawn_strategy=local \
  //:windows_msvc_libcxx_behavior_md \
  //:windows_msvc_dll_behavior

bazel build \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --extra_execution_platforms=@platforms//host:host \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  --spawn_strategy=local \
  //:windows_msvc_libcxx_behavior_md \
  //:windows_msvc_dll_behavior
```

Success criteria:

- x86-64 and ARM64 Windows consumers select the intended new prebuilt archive,
  the MSVC `cc_toolchain`, clang-cl compilation, llvm-ar, and lld-link;
- matching Windows runners build and execute representative MSVC behavior with
  no source-built LLVM fallback or ambient compiler/SDK discovery;
- the existing Windows MinGW row remains present and green with its GNU target
  platform, runtime, and argument dialect unchanged;
- CI names the MinGW and MSVC rows distinctly and records the selected release
  key/archive hash so cache reuse cannot hide incorrect registration;
- no release publication, index update, or Microsoft payload redistribution is
  performed without the separate authorization stated above.

**Potentially mergeable finish line:** The produced Stage 3 compiler archives
are consumable through a proved local registration path and both MinGW and MSVC
Windows compilation rows pass. A committed public index entry is a separate
delivery action if publication has not yet been authorized.

Risks/stop conditions:

- stop if registration would replace the existing MinGW compiler route rather
  than adding an MSVC consumer row;
- stop if native execution depends on an undeclared VCRuntime installation or
  requires adding redistributable Microsoft payloads to the archive;
- do not create ABI-specific repository names until an exact selection or
  runtime-closure conflict proves the existing version-neutral repositories
  cannot represent both consumer target dialects.

Upstream llvm-project patch expected: **no**.

## Step 12 — Verify supported LLVM source lines with Stage 3 package builds

**Codex-agent-ready goal:** Add CI build jobs, not test targets, that build and
package the full ThinLTO/FDO Stage 3 graph for both Windows MSVC target
architectures on the existing Linux RBE path. Keep version-selection edits
ephemeral.

Likely owned files:

- `.github/workflows/ci.yaml`;
- existing version-selection shell in CI if factored without a new persistent
  Python tool;
- no e2e/BUILD, test source, README, release workflow, or publication file.

Required matrix:

| LLVM source | Linux RBE -> x64 MSVC | Linux RBE -> ARM64 MSVC |
|---|---:|---:|
| 21.1.8 | full Stage 3 + package | full Stage 3 + package |
| 22.1.8 | full Stage 3 + package | full Stage 3 + package |
| 23.1.0-rc1 | full Stage 3 + package | full Stage 3 + package |

Jobs may share remote-cache results, but every cell invokes the canonical
Step 10 package build. `--nobuild`, a Stage 1 fallback, a consumer smoke target,
or analysis-only success is insufficient.

Use the repository's existing ephemeral `LLVM_VERSION` replacement pattern in
CI with `--lockfile_mode=off`. Do not commit a selected non-default version.
For each matrix cell, record:

- cquery evidence for MSVC platform and Stage 3 package input;
- aquery evidence for ThinLTO Stage 2/3, MSVC workloads, profile merge and
  application, and exec/target platforms;
- target triple/machine in compile/link/backend response files;
- merged profile size and `llvm-profdata show` summary;
- package SHA-256, manifest, PE machine/import/debug metadata, and deterministic
  archive/member properties.

Success criteria:

- every claimed matrix cell builds the full Stage 3 LLVM archive;
- x64/ARM64 artifacts, ThinLTO backends, and configured triples agree with
  their target labels;
- generated tools/profile merger run on matching Linux exec platforms; no
  target PE executes during construction;
- version-specific patches apply cleanly and generated Clang resource paths use
  the correct LLVM major;
- no cell uses the deleted temporary config or a Stage 1 package override;
- the working tree is clean after each ephemeral version cell.

**Potentially mergeable finish line:** CI enforces the final Stage 3 product
contract across every advertised LLVM source line and architecture without
altering publication/release workflow behavior.

Risks/stop conditions:

- classify timeouts/resource limits separately from compiler correctness, but
  do not replace a full-build cell with `--nobuild` or Stage 1;
- split source-line-specific semantic fixes into their owning backport step;
- do not modify `.github/workflows/llvm-prebuilt.sh` or publish artifacts until
  a separate owner decision defines release naming and migration.

Upstream llvm-project patch expected: **no new patch**; this validates Step 3,
any traced upstream fixes from Step 4, and the optimization graph.

## Upstreaming strategy and downstream-coupling review

Every LLVM overlay change follows this sequence:

Until the owner separately authorizes an upstream submission, “upstreaming”
below means preparing the patch, review description, and verification evidence
only. Numbered upstreaming items 4 and 6 activate only after that approval.

1. Reproduce against the matching unmodified LLVM tag and current LLVM main.
2. Implement against `utils/bazel/llvm-project-overlay`, using upstream
   platform/compiler settings and already-accepted Bazel dependencies only.
3. Demonstrate the owning target on Windows clang-cl plus unchanged Linux,
   macOS, and Windows GNU/MSVC configurations as relevant.
4. After explicit owner approval, submit a focused LLVM review with
   source/CMake behavior as the reference; do not mention hermetic paths as
   design inputs.
5. Backport the same patch into the smallest applicable 21.x, 22.x, and x.x
   patch files and list them in `extensions/llvm.bzl`.
6. Record the upstream review/commit in patch metadata. Remove each backport
   when the corresponding supported source archive includes it.

Explicit ownership summary:

| Concern | Owner | Upstream patch? |
|---|---|---:|
| Temporary Stage 1 package selection/config and its removal | hermetic-llvm | no |
| Explicit MSVC target/package labels and compatibility | hermetic-llvm | no |
| C++17 default and dialect-aware release-policy features | hermetic-llvm toolchain | no |
| Curated COM headers/library | hermetic-llvm Windows SDK/compiler-support closure | no |
| ARM64 LLVM native defines/triple | llvm-project Bazel overlay | yes |
| clang-cl/COFF ThinLTO executable action protocol | hermetic-llvm toolchain; source-built clang-cl/lld-link contract | no additional patch |
| Minimized clang-cl/COFF ThinLTO index inputs | hermetic-llvm feature selection over the existing Clang/lld/rules_cc protocol | no patch expected; classify a reproduced defect before changing an upstream owner |
| Linux Stage 2 instrumentation under existing `host_profile` | existing generic bootstrap/toolchain | no change expected |
| MSVC FDO profile application | hermetic-llvm toolchain | no |
| MSVC workload/profile aggregate and merge action | hermetic-llvm bootstrap rules | no |
| Stage 3 package input and proven Windows output-name blocker | hermetic-llvm release rule | no |
| Prebuilt archive registration and Windows consumer row | hermetic-llvm minimal-prebuilt extension/toolchain/CI | no |
| a newly discovered source/select bug | determine from failing owner before edit | maybe |

Rejected coupling:

- a downstream `-U_MSC_VER`, fake `comdef.h`, post-link triple rewrite, full
  Visual Studio include/lib path, repository-specific upstream config setting,
  or a global C++17 change outside the MSVC default that mirrors the existing
  generic toolchain default;
- adding MSVC workloads to the existing generic FDO aggregate, replacing the
  generic ThinLTO feature, or weakening unrelated Layer 1 validation;
- promoting package labels to Stage 2/3 before the direct corresponding graph
  has built and its actions/artifacts have been inspected;
- adding targeted `srcs` exclusions without tracing the upstream CMake/source
  semantics they preserve.

## Final supported/unsupported matrix

Current evidence state. Do not advertise a pending row as supported; after all
gates pass, the two Step 11 pending cells graduate to supported:

| Surface | x86-64 MSVC | ARM64 MSVC | Notes |
|---|---:|---:|---|
| `windows_msvc_llvm_release` direct target | supported | supported | Requires matching `--platforms` and EULA repo env. |
| platform-transition package label | supported | supported | Exact labels named in Objective. |
| Stage 1 source build, opt, `/MD`, static libc++ | supported | supported | Independently proved checkpoint; clang-cl + llvm-ar + driver-selected lld-link. |
| Stage 2 ThinLTO + instrumentation | supported | supported | Linux exec-platform compiler tools; MSVC target workloads. |
| Stage 3 ThinLTO + FDO application | supported | supported | Final package input under `--config=release`. |
| Matching-Windows prebuilt compiler consumer | pending native CI | pending native CI | Step 11 implementation exists locally; the matching-runner cells have not run. |
| Cross-build on Linux x86-64 RBE | supported | supported | All three listed LLVM lines after matrix passes. |
| Linux ARM64 FDO executor actions | supported | supported | Required where selected by the existing Stage 3 executor/profile graph. |
| Native matching Windows source bootstrap | unclaimed | unclaimed | Only completed prebuilt compiler execution is tested on Windows. |
| macOS construction host | unclaimed | unclaimed | May be added later with a full package build. |
| Release compiler CRT | `/MT` | `/MT` | `--config=release` requests static MSVC CRT semantics; ordinary consumers retain `/MD`. |
| Debug/PDB package | unsupported | unsupported | Opt EXE only; no orphan PDB/import library. |
| Shared LLVM/shared libc++ | unsupported | unsupported | Static libc++ only. |
| ThinLTO | supported | supported | Minimized `.indexing.o` summaries for indexing; complete bitcode `.obj` inputs for backends; COFF index/backend artifacts required. |
| Bootstrap FDO instrumentation/profile/application | supported | supported | MSVC-only workloads/aggregate; no target PE execution. |
| General user `//config:profile` | unsupported | unsupported | Internal bootstrap FDO does not silently graduate this separate public surface. |
| Sanitizers/coverage/other Layer 1 rejected features | unsupported | unsupported | Existing stable analysis errors remain. |
| Microsoft STL | unsupported | unsupported | Narrow approved ABI/COM helpers are not STL selection. |

## Verification matrix and evidence bundle

Every implementation handoff records exact commands, invocation URLs/IDs,
target/exec platforms, result, and remaining unknowns. Required evidence:

| Gate | x64 target | ARM64 target | Inspection |
|---|---:|---:|---|
| Stage 1 full build | required | required | compiled action count; first/last actions; no warning suppression |
| ThinLTO Stage 1 proof | required | required | bitcode, index, backend, `.obj`, final PE |
| Stage 2 instrumentation | required | required | Linux tool execution, clang-cl workload, nonempty `.profraw` |
| Profile merge | required | required | declared Linux llvm-profdata, profile contents/counts |
| Direct Stage 3 build | required | required | ThinLTO plus declared profile application and final PE |
| Minimized ThinLTO indexing | required | required | dual compile outputs; minimized-only index inputs; complete-bitcode backend inputs; suffix mapping and size comparison |
| Stage 3 package full build | required | required | cquery output path and archive SHA-256 |
| Prebuilt compiler consumer | required | required | matching Windows runner, selected archive hash/tool path, build and execution |
| Compile params | required | required | triple, `/std:c++17`, includes, flags, target/exec separation |
| Archive params/artifacts | required | required | llvm-ar `rcsD`, `.obj`/`.lib`, member machine/order |
| Final link params | required | required | clang-cl/lld-link, response file, directories, `/MACHINE`, outputs |
| PE inspection | AMD64 | ARM64, not ARM64EC | imports, debug directory, host-path absence |
| Archive manifest/extraction | required | required | real `.exe`, aliases, headers, ignorelists, fixed metadata |
| Remaining negative boundaries | required | required | general profile, sanitizers, coverage, and other unsupported features still reject |
| Existing generic Windows graph | required | required | remains GNU/MinGW with original Stage 3/profile topology |

No new test target is needed. Existing repository checks/buildifier may run as
regression checks, but they cannot replace the LLVM build and artifact/action
inspection above.

## Known unknowns to resolve during implementation

- configuration ownership for the existing shared `common:release`
  `--extra_execution_platforms` setting. Step 1 correctly keeps remote settings
  out of the new temporary product config, but moving the pre-existing shared
  setting into `common:remote` would change standalone `--config=release` and
  standalone `--config=remote` behavior. Preserve current behavior in this plan
  unless the owner explicitly requests a separate config-ownership change with
  before/after executor-resolution coverage;
- any additional LLVM 21/23 overlay delta encountered by the full optimized
  Stage 3 source matrix; Step 4 proved patch application but built LLVM 22.1.8;
- whether the hosted zstd workload needs an additional declared Windows
  system-library input while remaining uninstrumented target code;
- profile coverage/hash differences between the instrumented Linux compiler
  and profile-applied Windows compiler for platform-conditional LLVM code;
- whether LLVM 23.1.0-rc1 retains the minimized-index behavior proved on LLVM
  21.1.8 and the default LLVM 22.1.8 line; Step 9.1 did not rebuild that
  compatibility line;
- whether matching x86-64 and ARM64 Windows runners execute the registered
  static-CRT compilers and complete the representative `/MD`, `/MT`, and DLL
  consumer tests exactly as the local action graph predicts. Archive imports
  and repository registration are proved; native execution awaits the
  unpushed Step 11 CI cells.

These are not claimed defects. Convert an item into an implementation change
only after an exact failing action/artifact identifies its owner.

## Cleanup and delivery gates

- Keep EULA values in repo/CI environment flags only; never commit credentials,
  downloaded Microsoft payloads, extracted SDKs, response files, or licenses.
- Use `mktemp -d` for extraction/independent output bases; move temporary
  directories to Trash after evidence capture.
- Remove `/tmp/windows-msvc-prebuilt-*` action dumps when the implementation
  report has recorded stable facts.
- Leave no LLVM-version selection, generated lockfile, Bazel output symlink,
  release archive, or CI scratch edit in the Git diff.
- Run buildifier on changed Starlark/BUILD files and inspect the final diff for
  unrelated Layer 1/user changes.
- Each implementation agent commits only its owned step on its isolated branch
  and reports branch, full SHA, absolute worktree, commands/results, upstream
  review/backport status, and unknowns.
- Before integration, self-review for: Stage 3 regression, downstream-only LLVM
  coupling, target/exec inversion, full MSVC input exposure, Microsoft-STL
  contamination, preemptive file-action cleanup, unclaimed PDB/import outputs,
  premature feature graduation, temporary Step 1 debt, and any wording that
  implies native Windows construction or another unverified execution host.

## Completion boundary

Completion means: both explicit MSVC archives use the canonical release config
and the full ThinLTO/FDO Stage 3 topology, with minimized summaries used only
for indexing and complete bitcode retained for backends; all supported
source/version cells pass; matching-Windows consumer rows select and execute
the completed prebuilt compiler while the MinGW row remains unchanged;
action/profile/PE/archive evidence is recorded; generic release products retain
their existing topology and effective semantics; unrelated Layer 1 features
remain rejected; and all temporary Step 1 config, Stage 1 package override,
and unused `llvm_binary` parameterization have been removed. Native Windows
source self-hosting, Microsoft tool executables, public release upload, and
release workflow cutover remain outside this plan.
