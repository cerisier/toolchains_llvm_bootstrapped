# Windows MSVC prebuilt LLVM execution plan

Status: proposed; implementation is not authorized. Stop after review until the
owner explicitly marks implementation start.

Date: 2026-08-20 (Asia/Tokyo)

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

This plan is the only file changed by the planning task. It does not authorize
implementation, README edits, new tests/e2e targets, release publication, a PR,
or `gh stack` operations.

## Objective and non-goals

The supported path will package a non-FDO, non-ThinLTO Stage 1 LLVM built from
source by the Stage 0 prebuilt seed. It will expose two explicit platform-
transitioned labels:

- `//prebuilt/llvm:for_windows_x86_64_msvc`
- `//prebuilt/llvm:for_windows_aarch64_msvc`

The directly configurable product label will be
`//prebuilt/llvm:windows_msvc_llvm_release`. The existing
`//prebuilt/llvm:windows_llvm_release` and `for_windows_amd64`/
`for_windows_arm64` remain the GNU/MinGW products and keep their current Stage
3 behavior.

Non-goals for this layer:

- ThinLTO, FDO instrumentation, FDO workload generation, or FDO application;
- Stage 2 or Stage 3 MSVC toolchain enablement;
- pretending that `--config=release` is supported unchanged for MSVC;
- Microsoft STL headers or Microsoft STL as the selected standard library;
- shared libc++, shared LLVM, DLL packaging, debug-CRT packaging, sanitizer or
  coverage enablement;
- new test/e2e targets or files; LLVM compilation and artifact/action
  inspection are the acceptance surface;
- README/release-note changes, artifact publication, EULA redistribution, new
  CI secrets, or a prebuilt-release workflow cutover;
- macOS as a claimed full-LLVM construction host in this layer.

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

They intentionally fail on the baseline for the reasons below. After Step 1,
the canonical acceptance commands become:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  //prebuilt/llvm:for_windows_x86_64_msvc

bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  //prebuilt/llvm:for_windows_aarch64_msvc
```

Direct target diagnostics use the same config plus `--platforms=<MSVC
platform>` and `//prebuilt/llvm:windows_msvc_llvm_release`.

## Demonstrated baseline failure ledger

Facts below were reproduced without tracked implementation edits. Temporary
action-query output was written only under `/tmp` and removed after evidence
capture.

| ID | Probe | Result and owner |
|---|---|---|
| B0 | `bazel query --config=remote '//prebuilt/llvm:*' --output=label_kind` | Passed; invocation `9f4b46a2-9b7f-4285-ad4d-3fb667415c69`. Confirmed both release targets and only generic platform wrappers. |
| B1 | MSVC cquery without EULA opt-in | Repository fetch stopped on the Visual Studio runtime EULA; invocation `d5c0e948-f0bb-426a-80e5-4db6e59f1272`. This is a mandatory caller/CI prerequisite, not a product bug. |
| B2 | Direct x64 release with only `--config=remote` | Stage 3 expanded the complete FDO workload matrix and failed C++ toolchain resolution; invocation `10a00462-725e-48be-af13-12439d9c23e0`. Later cqueries selected `none_wasm32` and other workloads. The particular workload is incidental; the owner is the unconditional Stage 3 dependency and the command also lacks `--config=release`'s extra toolchains. |
| B3 | Direct x64 release with `--config=remote --config=release` | Analysis failed with the intentional Layer 1 message `MSVC ABI Layer 1 does not support feature(s): thin_lto`; invocation `b34b7bd8-2aef-47d1-be8b-64d4f61a2a02`. This is the correct advertised boundary. |
| B4 | Same release plus `--features=-thin_lto` | Stage 3 still expanded FDO and failed because the selected toolchain had no enabled `llvm-profdata` action; invocation `e9ba8690-b383-4067-842b-41f6bcdf3911`, after 459,269 configured targets. Disabling the command-line feature cannot turn Stage 3 into a non-FDO build. |
| B5 | `//toolchain/bootstrap/stage1:llvm`, x64 | Analysis succeeded through 93,874 configured targets/6,966 actions. LLVM `Support`/`Demangle` compilation failed because `std::is_integral_v` and `std::optional` were unavailable; no `/std:c++17` was present. Invocation `c38b1e76-b378-4fed-9997-a430ef41f77d`. |
| B6 | Stage 1, ARM64 | Same missing-standard failure at `std::optional`; invocation `a618ddc3-2514-46f2-bd4d-157462d19150`. |
| B7 | Stage 1 x64 plus `--cxxopt=/std:c++17` | Compilation advanced to `@llvm-project//llvm:WindowsDriver` and failed at `MSVCPaths.cpp:43`, missing `comdef.h`; invocation `77667245-d3ba-4373-8d67-d54d28398ce9`. |
| B8 | Stage 1 ARM64 plus `--cxxopt=/std:c++17` | Same `comdef.h` failure; invocation `77b4f926-e4f6-44dd-a210-5a0f2147f094`. |
| B9 | Stage 1 x64 with release flags, ThinLTO disabled, and C++17 | Reached 6,607 scheduled actions and the same `comdef.h` failure, but clang-cl warned that raw `-fno-exceptions`, `-fno-rtti`, and `-fomit-frame-pointer` from `.bazelrc` were ignored. Invocation `1ad641f5-5ef3-4280-8db7-87f5467dc941`. The generic release config is not a valid clang-cl optimization config. |
| B10 | Materialized LLVM `Analysis` compile params | 125 observed actions carried raw `-ftrapping-math`; clang-cl reported it ignored. Owner: LLVM upstream `utils/bazel/llvm-project-overlay/llvm/BUILD.bazel`, `Analysis.copts`. This pattern exists in 21.1.8, 22.1.8, 23.1.0-rc1, and current upstream main. |
| B11 | ARM64 materialized compile params | Target triple was `aarch64-pc-windows-msvc`, but `LLVM_NATIVE_ARCH` was `X86` and host/default triples were `x86_64-pc-win32`. Owner: LLVM upstream `utils/bazel/llvm-project-overlay/llvm/config.bzl`; all three supported source lines and upstream main select every Windows CPU as x86-64. |
| B12 | Configured genrule inventory | Only `@llvm-project//clang-tools-extra/clangd:gen_features_inc` and `@llvm-project//clang-tools-extra/clang-tidy:confusables_inc` remained. Both executed `/bin/bash` with `PATH=/bin:/usr/bin:/usr/local/bin`; invocation `b7c8a2a5-cc2c-4097-84f7-fce939c9040b`. No configured `py_binary` or `sh_binary` remained; invocation `dee12f40-a419-425e-8c9d-33b5deb53868`. |
| B13 | `TdGenerate` aquery | Windows target-generated files were produced by `clang-tblgen`/`llvm-min-tblgen` under `rbe_linux_aarch64-opt-exec`; invocation `f263f805-4b7a-44c8-bcd8-e941a8371a60`. `mlir/tblgen.bzl` declares its executable with `cfg = "exec"`. This boundary is correct and must not regress. |
| B14 | Whole Stage 1 action inventory | 6,503 `CppCompile`, 841 `CppArchive`, 352 `TdGenerate`, 278 `CppLink`, 218 `DefParser`, 70 `CopyToDirectory`, 14 `CopyFile`, and declared Windows case actions, among others; invocation `282e9af9-296d-4a9d-9e81-d17c70ae9c10`. The only configured shell actions are B12. |
| B15 | Archive aquery | Target archives use exec-host `llvm-ar`, Windows `.lib` names, and deterministic `rcsD`; invocation `39efcf0e-df70-4c95-9c47-72de5b94cfd0`. Action generation succeeded; archive execution remains unproven because compilation stops earlier. |
| B16 | Final-link aquery | The planned x64 action launches exec-host clang-cl, targets x64 MSVC, selects sibling lld-link, declares SDK/UCRT/VCRuntime/libc++ resource and library directories, emits `/MACHINE:X64`, `/Brepro`, `/INCREMENTAL:NO`, `/lldignoreenv`, deterministic PDB path controls, `/SUBSYSTEM:CONSOLE`, `.lib` dependencies, and `/WHOLEARCHIVE`; invocation `bfde2c52-ed47-4c22-b72e-87b3cc64d6f3`. It does not execute because B7 fails. Link success remains unproven. |
| B17 | Packaging source inspection | `prebuilt/llvm/llvm_release.bzl` hardcodes Stage 3, maps an extensionless bootstrap output to `bin/llvm.exe`, and concatenates two generated mtree manifests with `native.genrule(cmd = "cat $(SRCS) > $(@)")`. This is a declared source fact: the product path has a host-shell/PATH dependency even after LLVM compiles. |
| B18 | COM closure inspection | The pinned payload contains `comdef.h`, `comdefsp.h`, `comip.h`, `comutil.h`, `new.h`, and x64/ARM64 `comsuppw.lib`; Layer 1's curated trees expose none of them. `comdef.h` auto-links retail Unicode `comsuppw.lib`, `user32.lib`, `ole32.lib`, and `oleaut32.lib`. The ARM64 `comsuppw.lib` is a vendor fat archive with both ARM64EC and ARM64 members; target-member selection is not yet proven. |

The generated external `vars.bzl` sets `CMAKE_CXX_STANDARD = "17"`, and LLVM's
own `utils/bazel/.bazelrc` supplies `/std:c++17` in its Windows config. The
overlay explicitly says general compiler flags belong in a toolchain or
`.bazelrc`, not `llvm_copts`. Therefore C++17 is a hermetic-llvm invocation/
toolchain ownership issue; it is not an upstream target-local patch.

The attempt to suppress `_MSC_VER` only for `MSVCPaths.cpp` caused UCRT macro
failures (`9b7bd60e-464e-4e48-8239-e3437f9896a1`) and is rejected. The source
uses COM Setup Configuration intentionally for MSVC-environment discovery.

## Architectural invariants

1. **Truthful optimization stage.** MSVC packages consume Stage 1 only. No
   Stage 2/3 dependency, `thin_lto` action, FDO profile, profile workload, or
   `llvm-profdata` merge may appear. Existing non-MSVC Stage 3 products remain
   unchanged.
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
8. **Portable file actions.** Generated files and archive manifests use
   declared Bazel actions/tools, fixed metadata, and explicit inputs. No raw
   `genrule`, `/bin/bash`, `cat`, `echo`, Python, or ambient PATH in the
   configured product closure.
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

## Dependency graph and assignment order

```text
Step 1: Stage-1 MSVC release route/config
  +--> Step 2: curated COM compiler-support closure
  +--> Step 3: upstream ARM64/config + clang-cl flag patch
  +--> Step 4: upstream generated-file actions
              (Steps 2-4 can proceed independently once Step 1 exposes probes)
                    |
                    v
          Step 5: build-to-completion owner loop
                    |
                    v
          Step 6: portable packaging + artifact contract
                    |
                    v
          Step 7: line/exec-host matrix and CI build jobs
                    |
                    v
          STOP: report non-LTO/non-FDO support only
```

Each implementation step belongs on an isolated branch/worktree based on the
then-current accepted predecessor. Do not create a stack or submit a PR until
the owner separately approves that delivery workflow.

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
  outside the product config, so the same product config remains valid for a
  native Windows exec host;
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

Risks/stop conditions:

- stop if the only available design disables ThinLTO/FDO globally or changes
  non-MSVC Stage 3;
- stop if target-dialect config flags leak into exec-configured Linux tools or
  if source generators on a native Windows exec host lack their exec
  toolchain's required C++ standard;
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

## Step 3 — Fix upstream Windows architecture and clang-cl flag semantics

**Codex-agent-ready goal:** Make the LLVM Bazel overlay generate correct
ARM64 native configuration and compiler-dialect flags without changing other
platform semantics.

Likely upstream files/targets:

- `llvm-project/utils/bazel/llvm-project-overlay/llvm/BUILD.bazel`:
  Windows CPU/compiler config settings and target `Analysis`;
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
  other CPUs remain byte-for-byte semantically unchanged;
- `Analysis` retains trapping-math intent with `/clang:-ftrapping-math` for
  clang-cl and a source-equivalent MSVC spelling or explicitly reviewed
  omission for `msvc-cl`; GNU Clang/GCC retain `-ftrapping-math`.

Keep two independent upstream commit/review units inside this assignable step:

1. ARM64 Windows CPU/compiler settings, native defines, initializer names,
   and triples in `config.bzl` plus only the config settings they require.
2. `Analysis` trapping-math compiler-dialect selection in `llvm/BUILD.bazel`.

Each unit must build and backport independently; do not combine them merely
because the same full-LLVM invocation discovers both.

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
- clang-cl reports no ignored `-ftrapping-math` or other raw unsupported flag;
- final native Windows execution of `llvm.exe --version` and
  `clang-cl.exe --print-target-triple` agrees with the packaged machine and
  target;
- generic MinGW and non-Windows configured definitions remain correct.

Risks/stop conditions:

- stop if a single Windows CPU select would silently assign an MSVC triple to
  MinGW; model compiler/ABI distinctions in upstream-generic terms;
- stop if a backport embeds `@llvm` repository-specific labels, custom ABI
  constraints, or hermetic-llvm paths;
- do not use string substitution in generated files after compilation.

Upstream llvm-project patch expected: **yes, as two focused reviews** matching
the two commit units above. For the architecture review, explain the Bazel
target-platform bug and compare to the CMake/native target result. For the flag
review, preserve trapping-math semantics across compiler dialects. Run the
relevant upstream Linux/macOS/Windows clang/clang-cl configurations for each.
Submit only after the owner separately authorizes upstream publication. Carry
clean, independently applicable release-line backports only until a source
release contains each patch.

## Step 4 — Replace remaining upstream shell generators

**Codex-agent-ready goal:** Remove the two configured shell genrules from the
LLVM driver closure while preserving exact generated contents and exec-
configured tools.

Likely upstream files/targets:

- `utils/bazel/llvm-project-overlay/clang-tools-extra/clangd/BUILD.bazel`,
  `gen_features_inc`: replace echo/redirection with `write_file`, preserving
  line order and final newline;
- `utils/bazel/llvm-project-overlay/clang-tools-extra/clang-tidy/BUILD.bazel`,
  `confusables_inc`: replace the shell wrapper with `run_binary`, keeping
  `confusable_table_builder` in exec configuration and declaring input/output
  execpaths;
- matching temporary release-line patches and `extensions/llvm.bzl` entries.

Also re-run the configured closure inventory after every source line. Existing
21/22 `windows_link_and_genrule.patch` changes demonstrate the preferred
upstream style, but do not silently append unrelated new fixes to that broad
historical patch; keep new upstream reviews/backports focused.

Build/action commands:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //toolchain/bootstrap/stage1:llvm

bazel cquery --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  'kind("(genrule|py_binary|sh_binary)", deps(//toolchain/bootstrap/stage1:llvm))' \
  --output=label

bazel aquery --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  'mnemonic("TdGenerate|RunBinary|FileWrite", deps(//toolchain/bootstrap/stage1:llvm))' \
  --output=text --include_artifacts=true \
  --output_file=/tmp/windows-msvc-prebuilt-generators.txt
```

Success criteria:

- no configured `genrule`, `py_binary`, or `sh_binary` remains in the LLVM
  product closure;
- generated `Features.inc` and `Confusables.inc` are byte-equivalent to the
  baseline/source-of-truth output;
- the confusable builder and every TableGen executable are under an exec
  output tree whose OS/CPU matches the selected exec platform; generated
  outputs remain in the Windows target configuration;
- no action environment gains a host PATH or shell path.

Risks/stop conditions:

- stop if a replacement moves the generator into target configuration or runs
  a Windows target executable on Linux;
- preserve all feature values and source ordering; this is a file-action port,
  not a clangd feature decision.

Upstream llvm-project patch expected: **yes**. Prepare focused `utils/bazel`
reviews using only dependencies already accepted by LLVM's overlay; submit
only after the owner separately authorizes upstream publication. Backport
unchanged semantics to each supported line and retire backports after uptake.

## Step 5 — Drive both Stage 1 builds to completion, one traced owner at a time

**Codex-agent-ready goal:** After Steps 1-4, build the entire monolithic LLVM
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
  `-L`, `-l`, unsupported `-f*`, host absolute paths, target/exec CPU leaks,
  undeclared input paths, and mismatched `.o`/`.a` suffixes;
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
- no warnings say a required option was ignored;
- no undeclared host shell, Python, tool, or ambient Visual Studio/SDK path
  appears;
- no new downstream-only LLVM source workaround exists.

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

## Step 6 — Make packaging suffix-safe, shell-free, and inspect the archive

**Codex-agent-ready goal:** Package completed Stage 1 PE binaries with declared
portable actions, fixed metadata, preserved `.exe` naming, and the existing
minimal archive layout.

Likely owned files:

- `toolchain/bootstrap/bootstrap_binary.bzl` for configured executable suffix
  preservation if Step 1 did not already fix it;
- `prebuilt/mtree.bzl`;
- `prebuilt/llvm/llvm_release.bzl`;
- `prebuilt/llvm/BUILD.bazel`.

Implementation shape:

- derive the wrapper output suffix from the configured executable; never
  produce an extensionless Windows executable merely because the label is
  named `llvm`;
- retain `ctx.actions.symlink` where supported and the consumer accepts it. If
  native Windows proves that action unsupported, use the repository's declared
  copy-file action for this wrapper only, preserving `.exe`;
- remove the `cat` genrule by extending the Starlark `mtree` rule to flatten
  the declared builtin-header filegroup and binary labels into one manifest at
  analysis time. Apply explicit strip/package prefixes and fixed uid/gid/mode/
  mtime to every line; do not introduce a concatenation executable, shell, or
  Python;
- preserve real `bin/llvm.exe` plus the existing `.exe` multicall aliases.
  Inspect whether tar symlink entries are usable by supported Windows
  extraction; if not, make an explicit package-layout decision rather than
  silently following host filesystem behavior.

Build/artifact commands:

```sh
bazel build --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  //prebuilt/llvm:for_windows_x86_64_msvc \
  //prebuilt/llvm:for_windows_aarch64_msvc \
  --remote_download_toplevel

bazel cquery --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  'set(//prebuilt/llvm:for_windows_x86_64_msvc //prebuilt/llvm:for_windows_aarch64_msvc)' \
  --output=files

bazel aquery --config=remote --config=windows_msvc_prebuilt \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  'deps(//prebuilt/llvm:for_windows_x86_64_msvc)' \
  --output=text --include_artifacts=true \
  --output_file=/tmp/windows-msvc-prebuilt-x64-package-actions.txt
```

For each cquery-reported archive, extract to a fresh `mktemp -d` directory with
`bsdtar`, then inspect:

```sh
bsdtar -tvf <archive.tar.zst>
bsdtar -xf <archive.tar.zst> -C <temporary-directory>
llvm readobj --file-headers --coff-imports --coff-debug-directory \
  <temporary-directory>/bin/llvm.exe
```

Success criteria:

- cquery reports one `.tar.zst` per transition label in distinct platform
  output directories;
- no packaging `Genrule`, `/bin/bash`, `cat`, Python, or ambient PATH action;
- archive manifest paths, ownership, modes, mtimes, symlink targets, and order
  are deterministic; no absolute execroot path is stored;
- `bin/llvm.exe` machine matches its label. Aliases end in `.exe` and resolve to
  that file after extraction;
- Clang builtin headers and both ignorelists are present at the current layout;
- optimized EXE has no import-library output. A PDB is either absent with no
  CodeView/PDB requirement, or deliberately declared and packaged; never an
  orphaned reference;
- two builds on Linux x86-64 and Linux ARM64 produce identical archive SHA-256
  per target/source line after accounting for no intentional difference.

Risks/stop conditions:

- stop if changing the shared mtree rule alters existing archive layouts;
- stop if tar symlink semantics make the package unusable on claimed Windows
  hosts; record and obtain an explicit alias-layout decision;
- clean all extraction/output-base temporary directories with `trash` after
  recording hashes and action evidence.

Upstream llvm-project patch expected: **no**.

## Step 7 — Verify source lines and claimed execution hosts with LLVM builds

**Codex-agent-ready goal:** Add CI build jobs, not test targets, that compile
and package LLVM itself for the claimed matrix. Prove actions/artifacts in the
same jobs and keep version-selection edits ephemeral.

Likely owned files:

- `.github/workflows/ci.yaml`;
- existing version-selection shell in CI if factored without a new persistent
  Python tool;
- no e2e/BUILD, test source, README, release workflow, or publication file.

Required matrix:

| LLVM source | Linux x86-64 RBE -> x64 MSVC | Linux x86-64 RBE -> ARM64 MSVC | Linux ARM64 RBE -> x64 MSVC | Linux ARM64 RBE -> ARM64 MSVC | native Windows |
|---|---:|---:|---:|---:|---:|
| 21.1.8 | full Stage 1 + package | full Stage 1 + package | full Stage 1 + package | full Stage 1 + package | not claimed |
| 22.1.8 | full Stage 1 + package | full Stage 1 + package | full Stage 1 + package | full Stage 1 + package | matching x64 and ARM64 hosts |
| 23.1.0-rc1 | full Stage 1 + package | full Stage 1 + package | full Stage 1 + package | full Stage 1 + package | not claimed |

Jobs may share remote-cache results, but every cell invokes the package build;
`--nobuild`, a consumer smoke target, or analysis-only success is insufficient.
If cost requires reducing the matrix, reduce the claimed host/source support in
the final table rather than keeping an unexecuted claim. macOS full-LLVM hosts
remain unclaimed until an equivalent package build is added.

Use the repository's existing ephemeral `LLVM_VERSION` replacement pattern in
CI with `--lockfile_mode=off`. Do not commit a selected non-default version.
For each matrix cell, run the two canonical Step 1 package commands as
applicable and record:

- aquery execution platform for TableGen/config generators and llvm-ar;
- target triple/machine in compile/link response files;
- package SHA-256 and PE machine/import/debug metadata;
- archive member machine and deterministic archive mode;
- absence of Stage 2/3, ThinLTO/FDO, shell, Python, and host paths.

Native Windows default-line jobs build the matching package locally with:

```sh
bazel build --config=windows_msvc_prebuilt \
  --repository_cache= --repo_contents_cache= \
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1 \
  --extra_execution_platforms=@platforms//host:host \
  --spawn_strategy=local \
  //prebuilt/llvm:for_windows_x86_64_msvc
```

Use the ARM64 label on `windows-11-arm`. Extract with a Windows-capable bsdtar,
then run at minimum `bin/llvm.exe --version`, `bin/clang-cl.exe
--print-target-triple`, `bin/llvm-ar.exe --version`, and a representative
read-only command through another alias. These are inspections of the built
LLVM product, not new Bazel test targets.

Success criteria:

- every claimed matrix cell builds the full LLVM archive;
- x64/ARM64 artifacts and reported triples agree across exec architectures;
- generated host tools always match and run on the exec host; they never carry
  the Windows target machine in an executable action;
- native Windows extraction preserves or materializes usable aliases and runs
  the matching target binaries;
- version-specific patches apply cleanly and generated Clang resource paths use
  the correct LLVM major;
- the working tree is clean after each ephemeral version cell.

Risks/stop conditions:

- stop claiming a native host if file actions, suffixes, archive extraction,
  runner capacity, or a missing prebuilt exec tool prevents the full build;
- classify timeouts/resource limits separately from compiler correctness, but
  do not replace a full-build cell with `--nobuild`;
- do not modify `.github/workflows/llvm-prebuilt.sh` or publish artifacts until
  a separate owner decision defines release naming and migration.

Upstream llvm-project patch expected: **no new patch**; this validates and
upstreams Steps 3-4.

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
| Stage 1 package selection, target labels, release config | hermetic-llvm | no |
| C++17 invocation and dialect-correct release flags | hermetic-llvm config/toolchain | no |
| Curated COM headers/library | hermetic-llvm Windows SDK/compiler-support closure | no |
| ARM64 LLVM native defines/triple | llvm-project Bazel overlay | yes |
| `Analysis` trapping-math dialect | llvm-project Bazel overlay | yes |
| clangd/tidy generated-file actions | llvm-project Bazel overlay | yes |
| bootstrap output suffix and mtree/package actions | hermetic-llvm | no |
| a newly discovered source/select bug | determine from failing owner before edit | maybe |

Rejected coupling:

- a downstream `-U_MSC_VER`, fake `comdef.h`, post-link triple rewrite, full
  Visual Studio include/lib path, repository-specific upstream config setting,
  host shell, persistent Python generator, or global toolchain C++17 default;
- altering existing Stage 3 or falsely enabling unsupported optimization
  features to reuse the current release workflow;
- adding targeted `srcs` exclusions without tracing the upstream CMake/source
  semantics they preserve.

## Final supported/unsupported matrix

State to advertise only after all gates pass:

| Surface | x86-64 MSVC | ARM64 MSVC | Notes |
|---|---:|---:|---|
| `windows_msvc_llvm_release` direct target | supported | supported | Requires matching `--platforms` and EULA repo env. |
| platform-transition package label | supported | supported | Exact labels named in Objective. |
| Stage 1 source build, opt, `/MD`, static libc++ | supported | supported | clang-cl + llvm-ar + driver-selected lld-link. |
| Cross-build on Linux x86-64 RBE | supported | supported | All three listed LLVM lines after matrix passes. |
| Cross-build on Linux ARM64 RBE | supported | supported | All three listed LLVM lines after matrix passes. |
| Native matching Windows construction/execution | default LLVM line only | default LLVM line only | Claim only after Step 7 product execution. |
| macOS construction host | unclaimed | unclaimed | Layer 1 consumers work; full LLVM package not verified here. |
| `/MT` package variant | unsupported | unsupported | Layer 1 runtime route remains, but no package product is defined. |
| Debug/PDB package | unsupported | unsupported | Opt EXE only; no orphan PDB/import library. |
| Shared LLVM/shared libc++ | unsupported | unsupported | Static libc++ only. |
| ThinLTO | unsupported | unsupported | Layer 1 validation must continue to fail explicitly. |
| FDO instrumentation/profile/application | unsupported | unsupported | No Stage 2/3 path in these products. |
| Sanitizers/coverage/other Layer 1 rejected features | unsupported | unsupported | Existing stable analysis errors remain. |
| Microsoft STL | unsupported | unsupported | Narrow approved ABI/COM helpers are not STL selection. |

## Verification matrix and evidence bundle

Every implementation handoff records exact commands, invocation URLs/IDs,
target/exec platforms, result, and remaining unknowns. Required evidence:

| Gate | x64 target | ARM64 target | Inspection |
|---|---:|---:|---|
| Stage 1 full build | required | required | compiled action count; first/last actions; no warning suppression |
| Package full build | required | required | cquery output path and archive SHA-256 |
| Compile params | required | required | triple, `/std:c++17`, includes, flags, target/exec separation |
| Archive params/artifacts | required | required | llvm-ar `rcsD`, `.obj`/`.lib`, member machine/order |
| Final link params | required | required | clang-cl/lld-link, response file, directories, `/MACHINE`, outputs |
| PE inspection | AMD64 | ARM64, not ARM64EC | imports, debug directory, host-path absence |
| Archive manifest/extraction | required | required | real `.exe`, aliases, headers, ignorelists, fixed metadata |
| Negative feature boundary | required | required | explicit ThinLTO and profile/FDO rejection/no actions |
| Existing generic Windows graph | required | required | remains GNU/MinGW and Stage 3 |

No new test target is needed. Existing repository checks/buildifier may run as
regression checks, but they cannot replace the LLVM build and artifact/action
inspection above.

## Known unknowns to resolve during implementation

- the first compile/link failure after the curated COM closure;
- whether lld-link selects the pure ARM64 half of vendor `comsuppw.lib` and
  resolves its VCRuntime/libc++ ABI helper references coherently;
- every additional LLVM 21/23 overlay delta encountered after full compilation;
- whether native Windows can create/consume the bootstrap symlink and archive
  symlink entries without elevation or alias loss;
- final opt PE debug-directory/PDB behavior under the dedicated config;
- full LLVM build time/disk limits on native Windows ARM64 GitHub runners;
- whether an independently forced Linux x86-64 versus ARM64 exec build produces
  identical archive bytes or exposes metadata/tool-version differences.

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
  contamination, raw shell/Python, suffix loss, unclaimed PDB/import outputs,
  and any wording that implies ThinLTO/FDO support.

## Mandatory stop before ThinLTO/FDO

Completion of this plan means only: Stage-1-built, optimized, non-ThinLTO,
non-FDO MSVC LLVM archives for the verified matrix. Keep `thin_lto`, `profile`,
and all FDO paths unsupported and visibly rejected. Do not start Stage 2,
instrument workloads, merge profiles, apply profiles, alter the unsupported
feature list, or advertise optimized-bootstrap parity. Return to the owner with
the evidence bundle and wait for a separate explicit implementation plan and
start mark for ThinLTO/FDO.
