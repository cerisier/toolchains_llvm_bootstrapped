# Windows MSVC Layer 1 goal record

Status: implementation and local verification complete; delivery active.

Date: 2026-08-19 (Asia/Tokyo)

## Activation

- Objective: complete the first usable Windows MSVC-ABI product slice with
  clang-cl, deterministic llvm-ar, direct lld-link, Windows SDK/UCRT/VCRuntime,
  compiler-rt builtins, and libc++ for x86-64 and ARM64.
- Parent branch: `cerisier/windows-msvc-phase0`.
- Parent commit: `c41669b31ae825d3519c80fad818311aecd94f6d`.
- Parent base: `origin/main` at
  `53fe78a34c96b736eb0033f6ade601d8352dc93c`.
- Task branch: `cerisier/windows-msvc-libcxx`.
- Worktree:
  `/Users/corentinkerisit/code/github.com/hermeticbuild/hermetic-llvm-msvc-libcxx`.
- Product-stack trunk: current `main`; Phase 0 is not a product layer. Adopt
  this existing branch with `gh stack init --base main
  cerisier/windows-msvc-libcxx` after the task-owned commits are complete.

## Scope and invariant

Owned invariant: an MSVC+libc++ target has one coherent ABI, CRT, STL, target
architecture, tool identity, dependency protocol, response-file protocol, and
artifact contract through every compile, archive, link, runtime transition,
and declared output.

In scope:

- public `windows_x86_64_msvc` and `windows_aarch64_msvc` platforms;
- prebuilt, staged, and source-built clang-cl/llvm-ar/lld-link tools;
- explicit ordered Windows SDK, UCRT, and VCRuntime inputs;
- retail `/MD` default and retail `/MT` opt-in, with static winning;
- clang-cl `.d` dependencies and independent UTF-8 response files;
- deterministic llvm-ar `rcsD` and link-time `/WHOLEARCHIVE:`;
- direct lld-link executables, DLLs, `.if.lib` import libraries, and PDBs;
- exact MSVC compiler-rt builtins resource artifact;
- Microsoft-ABI libc++ with static `libc++.lib` and absent dynamic artifacts,
  as amended after Phase 0;
- stable unsupported-combination analysis errors;
- risk-driven goldens, action assertions, artifact assertions, behavior tests,
  source-built checks, native Windows execution, and MinGW regressions.

Non-goals:

- Microsoft STL as the selected standard library; the exact CRT-selected
  upstream Microsoft C++ runtime ABI helper provider is permitted;
- sanitizer enablement;
- llvm-lib personality;
- app-local VC redistributables;
- rules_foreign_cc, resources/MASM, and unowned instrumentation;
- README changes, Microsoft payload redistribution, or persistent Python.

## Baseline reproduction

From `e2e/rules_cc` on the unmodified Layer 1 branch:

```sh
bazel build --config=remote //:main
```

Passed with 1,187 actions; BuildBuddy invocation
`2ed23617-03f0-4af2-a194-a8c512d75f4d`.

```sh
bazel aquery --config=remote --include_param_files //:main \
  --output=jsonproto \
  --output_file=/tmp/windows-msvc-layer1-baseline-aquery.json
```

Passed; invocation `7dae5c52-d977-45c1-b688-cb8559810438`; 20,597 bytes;
SHA-256 `f1d80086981097d55c792ef3b0e48fe8cededf6dfbfa66849f78da789a211ed4`.

## Positive scenarios

- x86-64 and ARM64 C/C++ compile, generated source, and linkstamp actions use
  clang-cl forms, the selected target triple, SDK inputs, `/MD` or `/MT`, and
  no GNU/MinGW-only argument or input.
- Compiler, archive, and linker response files independently handle long,
  spaced, non-ASCII, and host-legal colon-bearing paths using UTF-8.
- Static libraries contain ordered AMD64/ARM64 COFF members with deterministic
  timestamps; alwayslink affects only final lld-link argv.
- Executables and DLLs use direct lld-link, declared outputs, deterministic
  flags, expected machine/subsystem/import/export tables, and coherent CRT.
- DLL actions declare `<name>.if.lib`, pass that path to `/IMPLIB:`, and consumers
  link it; debug links declare and reference the matching sibling PDB.
- libc++ `/MD` and `/MT`, under both ordinary static and dynamic dependency
  modes, expose only `libc++.lib` without libc++abi, libunwind, or MinGW.
  They explicitly consume only `msvcprt.lib`/compatible MSVCP for
  `/MD` or `libcpmt.lib` for `/MT` from the Microsoft-STL binary runtime, and
  no Microsoft STL headers or other standard-library closure.
- Representative exceptions, RTTI, allocation, iostream/locale, filesystem,
  threads/synchronization/atomics, libraries, executables, DLLs, DEF flows, and
  C/Win32 cross-DLL boundaries build for both architectures and run natively on
  matching Windows hosts.
- LLVM 21.1.8, default 22.1.8, and 23.1.0-rc1 source-built representatives have
  correct machines, directives, imports/exports, arguments, runtime behavior,
  and line-specific libc++ site headers.
- Existing MinGW UCRT and legacy-MSVCRT actions/artifacts remain unchanged.

## Negative scenarios

- MSVC ABI with legacy `msvcrt`, libstdc++, Microsoft STL before Layer 2, debug
  CRT, dynamic libc++ artifacts, mixed STL closure, or missing CRT selection
  fails analysis with stable text.
- Explicit start/end-lib, ThinLTO, unsupported assembly/preprocess variants,
  ObjC/ObjC++, modules, fission, GNU strip, unsupported profile/coverage,
  sanitizers, and fully-static generic modes never succeed as ignored no-ops.
- MSVC actions reject GNU dependency/link/archive forms, PIC claims, ELF
  runtime-search flags, orphan import libraries, undeclared PDBs, target/exec
  architecture leaks, and MinGW/Microsoft-STL contamination outside the
  approved Microsoft C++ runtime ABI helper provider.

## Stable test interfaces

- `//toolchain/features/msvc:all_tests`
- `//tools:msvc_tool_probe_test`
- `//tools:msvc_action_assert_test`
- `//tools:msvc_artifact_assert_test`
- `//e2e/rules_cc:windows_msvc_libcxx_matrix`
- `//e2e/rules_cc:windows_msvc_resource_directory_matrix`
- `//e2e/rules_cc:windows_msvc_invalid_matrix`
- `//e2e/rules_cc:windows_mingw_regression_matrix`

The Phase 0 Go tools own direct-tool, JSON aquery, and artifact verification.
Tests prefer externally visible analysis results, action graphs, output files,
binary structure, and runtime behavior over private implementation details.

## Execution matrix

- Exec hosts: Linux x86-64/ARM64, macOS x86-64/ARM64, Windows x86-64/ARM64.
- Targets: Windows x86-64 MSVC and Windows ARM64 MSVC.
- Runtime cells: `/MD` and `/MT`, each with ordinary static and dynamic
  dependency linking, always using static libc++.
- Toolchain origins: prebuilt and source-built LLVM 21/default/23 representative.

## Allowed areas

Implementation may touch module/extension setup, platform/constraint routing,
tool packaging and maps, MSVC action/features, runtime transitions, compiler-rt
builtins, libc++, named tests, CI, and this goal record. README files remain
untouched. Any copied upstream code must record exact provenance.

## Review and delivery gate

1. Focused Bazel test command from `PLAN.md` passes.
2. Full existing suites and `e2e/rules_cc //:main` pass.
3. Action graphs and emitted COFF/PE/archive/PDB artifacts are inspected, not
   only built.
4. Native six-host CI and matching Windows runtime cells pass.
5. No README or persistent Python changes; no Microsoft payload publication.
6. Structured autoreview has no accepted/actionable findings.
7. Task-owned commits are pushed and `gh stack submit --auto` creates a draft
   Layer 1 PR; all its checks are green.

## Stop conditions

Stop for a new redistribution/EULA decision, new CI secret, new public API
decision, missing core tool on a claimed host, unrepresentable declared output,
SDK case failure, contradictory CRT directive, runtime-transition loss,
MinGW/Microsoft-STL contamination outside the approved Microsoft C++ runtime
ABI helper provider, or existing-toolchain regression.

## Closeout evidence

Decision update, 2026-08-18: Layer 0's PDB contract follows existing rules_cc
Windows behavior. rules_cc declares the sibling PDB but exposes no PDB-path
toolchain variable; direct lld-link receives `/DEBUG` and derives the matching
name from `/OUT`. Layer 1 verifies the declared output, PDB structure, and PE
CodeView reference without inventing or guessing `/PDB:`.

Decision update, 2026-08-18: the owner approved a static-only Windows MSVC
libc++ contract. Both ordinary static and dynamic dependency modes compile
with `_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS` and explicitly link
`libc++.lib`; Layer 1 exposes no `c++.dll` or `c++.lib`. `/MD` and `/MT`
remain independent retail CRT selections.

Implementation evidence:

- After the static-only amendment, all `/MD`/`/MT` by ordinary static/dynamic
  dependency cells built for x86-64 and ARM64 in invocation
  `928775c8-e29c-49a6-bd52-4866fa5a2e01`. The required focused suite passed
  all 19 targets remotely in `eb245178-3571-4e7e-a4f3-0d01d519e8cd`, and the
  matching host-local macOS ARM64 run passed all 19 in
  `aec281ce-38ca-418d-b724-dfdd297ef1b8`.
- The final default x86-64, `/MT`, `dbg`, ARM64, and transitioned runtime
  optimization action specifications passed the Phase 0 Go verifier in
  `2633a4a0-b0d8-4a51-854e-8d467d8a6ca1`,
  `64ce797c-05e5-497b-8002-ee8e56472f23`,
  `5638cc54-ca5b-4928-9e06-eaeaabadc98b`,
  `f9bbc29f-ba4c-4bde-9441-359145d497dc`, and
  `a08e1fc7-11dc-45b3-aa64-5b61ba996169`. The runtime probes deliberately
  invert caller `compilation_mode`; their guarded C sources prove optimized
  runtimes receive `NDEBUG` plus optimization while debug runtimes receive
  neither, and `_DEBUG` is absent in both. Their build passed in
  `d136ef3d-00a8-4827-9327-0d335de25218`.
- The post-amendment `//:main` build passed in
  `d833aabe-75ee-454e-a7e6-ca2e6cfccffe`.

- The exact focused matrix from `PLAN.md` passed all 16 named tests under
  remote execution from a macOS ARM64 client with 6,824 processes: BuildBuddy
  invocation `5284e756-d55d-4df6-abb6-243000e47c96`. The broader focused
  matrix including the portable DEF parser passed all 17 tests in
  `6e16ed25-a1ab-4376-bbc1-502a28d52a69`.
- `//:main` passed with 1,187 actions: invocation
  `303bd38d-49c8-4b64-a390-480a082c088d`.
- Phase 0's Go action verifier accepted the x86-64 `/MD`, x86-64 `/MT`, ARM64
  `/MD`, and x86-64 `dbg` action graphs: invocations
  `a4f7e8ea-7c05-425d-8bf0-caa7561c7d9c`,
  `47cd71c9-efa6-40d0-9a86-33adb6bac32f`,
  `233ade7e-8fb2-4e5b-b15c-67f9a20921a8`, and
  `b17470e7-2bd4-4465-a879-63f440856fc5`.
- Source-built LLVM 21.1.8, 22.1.8, and 23.1.0-rc1 produced and passed the
  representative x86-64 MSVC libc++/assembly/resource artifacts: invocations
  `ab139d61-e97a-4deb-9498-d3a355539fd3`,
  `d3fcefb8-734a-418b-ba9b-3a70ac05699b`, and
  `b7851782-1bb0-4c73-8263-7c287eeda45a`. Default LLVM 22 ARM64 libc++ and
  assembly also passed in `87f45a4a-5dc4-47d7-a980-29feda35e1bb`.
- An EULA-free ordinary `e2e/rules_cc //...` run passed 28 tests and skipped 22
  manual/platform-incompatible tests. Its only failure was the existing
  macOS ARM64 `//:xray_output_test`, whose binary ran but emitted no XRay log;
  XRay/sanitizer instrumentation is outside Layer 1. Invocation:
  `71197c9d-ae74-4372-96c0-20cf62b61090`.
- The tightened declared-PDB/PE-CodeView association tests passed for both
  target architectures: invocation
  `3df58c33-a470-4257-9d8c-3b6f4940b6a7`.
- Exec-config regression: the generic `exec_test` wrapper now overrides
  Bazel's target-matching implicit test execution group. Executable helpers are
  passed through its `tools` attribute while inspected outputs remain `data`.
  A forced uncached remote artifact/resource run passed in
  `c8f2cb81-b6bb-4231-924a-59e4e2ff0c84`; its 1 GiB execution log records both
  TestRunner actions and every LLVM inspection tool as Linux ARM64 remote
  executables. The complementary host-local macOS ARM64 run passed in
  `7def10c0-dc13-471d-bd8c-ad7666bd9638`. Six older root linux-linking tests
  were migrated from executable data to exec tools and all passed remotely in
  `b0a2baf4-6077-4f2a-ae64-0d1a0752c45b`. Production clang-cl, direct
  lld-link, DEF parser, SDK case-copy, and VFS actions independently ran on
  Linux ARM64 RBE in `c1a8422f-117a-464e-9c3a-bcd7a38f0746`; the checked-in
  action specification enforces that boundary.
- Final CRT isolation uses separate filtered `/MD` and `/MT` library trees,
  `/NODEFAULTLIB`, and an explicit closure including the UCRT-required
  `iso_stdio_wide_specifiers.lib`. The complete 10-cell x86-64/ARM64,
  `/MD`/`/MT`, ordinary static/dynamic dependency matrix rebuilt in
  `9e6d6769-39e5-42b3-893c-8c868ad88953`.
- Unsupported global `asan`, target-local `features = ["asan"]`, and the
  `//config:asan` build setting each failed during analysis in
  `d0f4e4a6-4cbf-4842-a6e5-1ac593ea3592`,
  `c690b0ef-182a-4209-817d-d33b47e5a1cf`, and
  `39211fe5-ec58-44a6-9ef7-d6a92f4e6933`. Disabling the historical wrapper
  feature names did not bypass the mandatory CRT/configuration arguments in
  positive invocation `f2187a54-6aa3-46d0-a211-44ae4b152b49`.
- The post-isolation focused suite passed all 19 targets on the local macOS
  ARM64 host while cross-compiling both Windows targets in
  `a851cf03-4d9a-4ca8-880b-3e58556f5856`. Phase 0's Go action verifier then
  accepted the final x86-64 `/MD`, ARM64 `/MD`, x86-64 `/MT`, x86-64 `dbg`,
  and transitioned runtime-optimization graphs in
  `d1d5fe2a-0c04-4435-91d0-30019fdfb631`,
  `e529703b-6c0e-40a0-8c72-d21b4fef4032`,
  `abe9884b-3dba-45f9-8aad-7c9142244ee3`,
  `cdf3bf77-0bb6-41f7-a8a7-c5b0b742a52a`, and
  `023a2cc5-61ba-41ff-9e18-cd5e41018765`.
- The final ordinary `e2e/rules_cc //:main` regression build passed in
  `2fda6ba4-126b-4ee3-9949-c95ae5a908c4`.
- Autoreview's response-file finding reproduced against Bazel 9: JSON aquery
  named virtual `.params` files without embedding their contents. The Phase 0
  Go verifier now hydrates only selected actions from files produced by
  `bazel build --materialize_param_files` and rejects unavailable/opaque
  content. Its unit suite passed in
  `ca043b95-200d-434a-a2bb-e40e4c38d298`; final materialized x86-64 `/MD`,
  ARM64 `/MD`, x86-64 `/MT`, x86-64 `dbg`, and runtime-transition graphs
  passed in `317764d6-6719-4ea3-a71a-ed34a3c62bb1`,
  `d7e09f35-c598-4b0d-aded-7ebe232cfbf2`,
  `ac3a94db-82c9-4075-ad4d-facfc96127c8`,
  `ef3364f2-c0ca-4cf0-b382-f310ca1cdc12`, and
  `1aa5cb3a-65d3-4914-8042-8b4d9c1362db`.
- All stable Windows SDK/MSVC directory targets validate their resolved paths
  against the Phase 0-pinned versions, including downstream root-module
  extension overrides. VFS generation follows transformed header-file
  symlinks but rejects directory symlinks; its focused Go test passed on Linux
  RBE in `7f704977-8f7e-4b41-8773-f3883bd7b062`. Debug artifact cells now
  require at least one declared PDB before validating its MSF structure and
  PE CodeView association. The final 19-target suite passed in
  `48af8070-5ec2-4016-93c4-2248d74d2a39`.
- `buildifier` left every changed BUILD/Starlark file clean; Ruby parsed the CI
  workflow YAML; `git diff --check` passed. No README or persistent Python
  file changed and no Microsoft payload was redistributed.

The LLVM-line fixes are deliberate: LLVM 21 must not define
`LIBCXX_BUILDING_LIBCXXABI` on the VCRuntime route, and LLVM 23 needs the
narrow `ehdata*.h` VCRuntime metadata closure while loop-detect UBSan remains
behind the existing sanitizer feature.

Completed structured autoreviews found response-file, SDK-root validation, and
cross-host filesystem correctness defects; all accepted defects were fixed and
reverified. At the owner's direction, a final redundant review pass was stopped
after more than 20 minutes without a result; remaining test-hardening-only
suggestions are explicitly out of scope for closeout.

The approved one-layer stack is registered above `main` and draft PR #711 was
submitted with `gh stack submit --auto`. The first complete CI pass proved the
Layer 1 jobs on Linux x86-64, Linux ARM64, and macOS Intel. It also exposed two
cross-host infrastructure defects: macOS ARM64 exhausted host threads under the
repository-wide `--jobs=800` remote default, and native Windows uses manifest
runfiles rather than a symlink tree. The action-graph job now caps its own
remote fan-out at 100 jobs, matching the repository's established macOS memory
mitigation. The artifact verifiers now resolve transitioned outputs and host
tools through either runfiles representation, preserving native Windows
artifact inspection rather than skipping it. A representative four-target
artifact/resource/MinGW suite passed after that change in BuildBuddy invocation
`d82ca04f-4a07-4abd-96ff-6235062e2bcd`.

CI run `32157711579` then proved the complete Layer 1 job on Linux x86-64,
Linux ARM64, macOS Intel, and macOS ARM64. On native Windows ARM64, all 18
applicable host-local artifact and protocol tests passed in BuildBuddy
invocation `8992ed87-1b2c-4f90-8d81-01a077265c9b`; Windows x86-64 passed the
same phase. Native execution subsequently failed during analysis because
Bazel 9 requires the transitioned MSVC target platform to participate in
default test-toolchain resolution. The native CI command now registers the
host platform first for compiler/helper actions and the exact MSVC target
platform second for TestRunner actions. Local `--nobuild` analysis of the
ARM64 native matrix accepted that ordering in invocation
`cc8f8098-de0d-4215-950e-8cd8b1ed2929`. The unrelated MinGW POSIX structural
`sh_test` remains exercised on Linux and macOS but is marked incompatible with
native Windows, whose rules_shell launcher cannot execute that cross-target
test.

CI run `32159114719` proved the final Linux and macOS four-host set and advanced
native Windows ARM64 through execution. C smoke plus all eight libc++ and
`exception_ptr` `/MD`/`/MT` binaries ran successfully; only the three DLL
consumers exited with Windows `STATUS_DLL_NOT_FOUND`. The owning transition
test wrapper had relocated each executable below a label-specific directory
without relocating its declared `runtime_dynamic_libraries`. It now forwards
those output-group files beside the executable. ARM64 cqueries show the correct
EXE/DLL pairs for ordinary `__declspec(dllexport)`, explicit DEF, and generated
DEF flows in invocations `9ecf98d9-160b-42f2-aab3-60b69b5e1f1f`,
`736868ea-7609-45f7-ad67-78ae15fe1892`, and
`71ace41d-e43b-4a2b-8489-62a705c32532`.

CI run `32161040633` proved native Windows ARM64 execution after the DLL fix,
then exposed an exec-personality defect in the remote action-graph phase. Two
MSVC artifact-renaming rules had disabled Bazel Skylib's action-free symlink
path, causing the Windows client to select Git Bash and send its absolute
`C:\Program Files\Git\...\bash.exe` path to a Linux ARM64 worker. The
`clang_rt.builtins.lib` and `libc++.lib` naming targets now use declared
symlink actions, preserving their required output names without a host tool.
The resulting ARM64 aquery contains Linux ARM64 `Symlink` actions for both
targets and no absolute host executable in invocation
`12587f3d-d984-4c6c-837a-9b3d9899769f`; the four representative ARM64 outputs
then built remotely in `c814475f-62db-4c2d-920f-463c96506fd9`.

Pending final task-owned commit, stack resubmission, and green six-host CI.
