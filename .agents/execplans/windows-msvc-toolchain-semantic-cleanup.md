# Windows MSVC toolchain semantic cleanup plan

Status: active; Batch 1 complete, remaining batches await owner selection.

Date: 2026-08-24 (Asia/Tokyo)

Baseline: `8bd4e2ebd6a20fadcc73375f6c4a334925c8462b` on
`cerisier/windows-msvc-prebuilt-llvm-step4`, the current draft PR #711 line.

## Objective

Preserve the proved Windows x86-64 and ARM64 MSVC target toolchains while
restoring the repository's semantic toolchain architecture after the initial
functional implementation. The final graph should express stable concepts
once, select target OS and ABI at named boundaries, and vary only concrete
Clang versus clang-cl spellings where required.

This is a cleanup and regression-correction phase, not a new capability phase.
It does not authorize prebuilt publication, release-index changes, MSVC host
toolchain support, Microsoft STL, dynamic libc++, debug CRT, sanitizers,
header-parsing graduation, or new CI lanes.

## How successor agents use this plan

- `[x]` means the current baseline already resolves the review item or the
  review established that no implementation is required. Do not redo it.
- `[ ]` means implementation or an explicit owner decision remains.
- Work only on an owner-approved batch. Do not opportunistically start the
  following batch.
- Before editing, reproduce the relevant current action or configured target.
  After editing, compare the same evidence. A label building is not enough
  when the item concerns action order, selected tools, or rendered flags.
- Update the checkbox and append concise evidence only after the intended
  behavior is proved.
- Commit cohesive batches, not individual review comments. Do not amend or
  squash existing PR commits.
- Keep heavy remote builds out of per-item loops. Use the lightweight batch
  gates below, then run the final source-build/consumer matrix once after all
  action-affecting batches selected for this PR are complete.

## Governing invariants

1. `toolchain/README.md` remains the architecture contract:
   canonical argument groups have stable meanings; implementation packages
   contain concrete spellings; root toolchain assembly owns platform/ABI
   selection and contains no raw flags.
2. Compiler driver dialect, target OS, target ABI, C++ standard library, CRT,
   and execution platform are independent axes even when today's supported
   configurations make some combinations coincide.
3. Windows MSVC target actions continue to execute hermetically on declared
   execution platforms with clang-cl, llvm-ar, and clang-cl's declared sibling
   lld-link. No ambient Visual Studio/SDK discovery is introduced.
4. Static libc++ and retail `/MD` default plus `/MT` opt-in remain unchanged.
   Microsoft STL, dynamic libc++, and debug CRT remain unsupported.
5. Existing MinGW/GNU and non-Windows rendered actions remain semantically
   unchanged except for intentional label/package relocation.
6. Unsupported MSVC features remain explicit failures. Empty semantic groups
   must mean “not applicable under the supported contract,” not “forgotten.”
7. Generic action sets and ordering must never be narrowed to the clang-cl
   subset.

## Review-item ledger

The IDs below follow the 2026-08-24 PR review recap and retain the original
order so later agents can map plan state back to PR #711.

### Runtime and LLVM overlay findings

- [x] **R01 — Remove the standalone `stage0_files` workaround.**
  `cc_runtime_stage0_copy_file` now owns both the Stage 0 transition and the
  exact `clang_rt.builtins.lib` rename. Do not restore a generic post-copy
  transition wrapper.

- [x] **R02 — Explain why other platforms never needed `stage0_files`.**
  Their artifact-producing runtime rules already own the transition. The
  baseline now follows the same producer-owned model for the MSVC copy.

- [x] **R03 — Preserve MinGW libc++ warning suppressions.**
  Commit `f2be1dc0` gives clang-cl and MinGW explicit spellings and preserves
  the previous broad-Windows behavior. The changed runtime selects were
  audited for the same exact loss pattern.

- [ ] **R04 — Name the libc++/VCRuntime ABI-header contract precisely.**
  Keep the empty libc++abi-header route only for the supported
  libc++ + Windows MSVC ABI + VCRuntime tuple. Rename or comment the selector
  so it does not imply that every future MSVC C++ library gets ABI headers
  elsewhere. Do not add libc++abi headers to the current route.

- [ ] **R05 — Clarify the static libc++ Stage 0 graph.**
  Preserve the ASan-inheriting default Stage 0 archive and the non-ASan Stage 0
  archive used by MSVC. Rename targets/comments to expose that distinction and
  document that the final copy exists only for the exact `libc++.lib` COFF
  auto-link name. Do not change the runtime stage.

- [x] **R06 — Retain `exec_test` for Linux-linking artifact inspection.**
  `llvm-readelf` is an execution-platform tool while inspected outputs remain
  target data. The earlier `sh_test` only worked when target and exec
  configurations coincided.

### Shared argument and feature semantics

- [ ] **R07 — Make module behavior an explicit unsupported MSVC boundary.**
  Keep generic module flags unchanged. Do not pass raw GNU flags to clang-cl or
  claim module/header-parsing support. Represent the empty MSVC implementation
  explicitly, and ensure requests for layering/module parsing fail or remain
  disabled coherently until R43 is separately graduated.

- [ ] **R08 — Isolate and re-prove link-time `-no-canonical-prefixes`.**
  Move it out of the linker-choice group into a named staged-linker discovery
  semantic. Compare source-built clang-cl link actions with and without it. If
  sibling `lld-link` remains selected hermetically, remove it; otherwise retain
  it with action evidence explaining the Bazel symlink/InstalledDir contract.

- [x] **R09 — Consolidate builtin-path canonicalization args.**
  After agreeing on one logical action set, use one semantic `cc_args` target
  with selected Clang/clang-cl spellings instead of two targets plus a list.

- [x] **R10 — Consolidate deterministic compile args.**
  Use one semantic target, preferably one select per independently meaningful
  flag. Preserve redacted builtin macros and compilation-directory behavior.

- [ ] **R11 — Replace generic `extra_args` with compiler-resource semantics.**
  Rename the constructor input to its actual role and compose the selected
  compiler builtin-resource include argument into the named include-search
  graph. Preserve the order libc++ headers, compiler resource headers, then
  VC/UCRT headers.

- [x] **R12 — Restore the full generic C++ action set.**
  Generic C++17 defaults must use the existing `cpp_compile_actions` coverage.
  Bind an explicit clang-cl subset only where MSVC actions are unsupported; do
  not narrow ObjC++, modules, LTO backend, or other generic C++ actions.

- [x] **R13 — Model stack protection explicitly.**
  Preserve generic `-fstack-protector`. Prefer an explicit proven `/GS` MSVC
  mapping over relying silently on the clang-cl default. Do not use the GNU
  spelling in CL mode.

- [x] **R14 — Decompose default compile policy by semantic.**
  Give warnings, diagnostic color, and frame-pointer preservation individual
  dialect mappings/comments. Prefer clang passthrough when preserving Clang's
  exact warning policy; do not approximate `-Wall` blindly with an unrelated
  MSVC warning level or leave one blanket empty MSVC branch.

- [ ] **R15 — Rebuild legacy replacements as an ordered common spine.**
  Classify every generic replacement as shared, dialect-replaced,
  target-inapplicable, or explicitly unsupported. Preserve common ordering,
  especially user flags before compiler input/output and the linker parameter
  protocol. Do not maintain an independent approximate MSVC ordering.

- [ ] **R16 — Split compiler-dialect features from Windows/MSVC ABI features.**
  Move CL spelling, response, dependency, `/D`, `/I`, `/Fo`, and `/clang:`
  behavior into a clang-cl adapter layer. Keep COFF artifacts, `/MACHINE`, DLL,
  DEF/import library, PDB, CRT, SDK closure, and ABI validation in a
  Windows/MSVC target layer. Keep only genuinely combined forwarding in a
  small named bridge.

- [x] **R17 — Validation reminder has no actionable request yet.**
  Do not infer work from the placeholder PR comment. Reopen this item only when
  the owner supplies the missing validation question.

- [ ] **R18 — Revisit the release frame-pointer request only at the final
  policy checkpoint.** Keep the current release-only feature for now; moving
  omission into generic `opt` would change ordinary optimized consumers. In
  Batch 6, compare an explicit product-policy build setting/transition against
  the temporary marker feature and obtain owner approval before changing it.

- [x] **R19 — Split debug flags by meaning.**
  Model no optimization, debug information, and `_DEBUG` separately. Map
  `-O0` to `/Od` and `-g` to `/Z7`; keep `_DEBUG` absent while only retail
  `/MD` and `/MT` are supported.

- [x] **R20 — Split optimization flags by meaning.**
  Separate optimization level, `NDEBUG`, debug-info removal, fortification,
  function/data sections, and inline elimination. Each select must state an
  equivalent MSVC spelling or an intentional absence.

- [x] **R21 — Keep the exact clang-cl builtin-resource include allowlist.**
  Clang-cl passes only `builtin_resource_include_dir` through `/imsvc`; the
  unused parent resource root must not be allowlisted. Link-time target
  `-resource-dir` is a different input.

### Runtime toolchain argument assembly

- [x] **R22 — Use the same logical runtime source-action set across dialects.**
  Separate action ownership from spelling. Start with the existing generic
  runtime action set, then document any individually unsupported clang-cl
  action rather than replacing the whole set with `source_compile_actions`.

- [x] **R23 — Consolidate optimized runtime args.**
  Use one semantic target per policy (`NDEBUG`, optimization level) with
  selected driver spelling; remove parallel clang/clang-cl wrappers.

- [x] **R24 — Consolidate debug runtime args.**
  Use individual semantic targets for optimization, debug info, and `_DEBUG`,
  retaining the retail-CRT reason for omitting `_DEBUG` on MSVC.

- [x] **R25 — Remove the redundant debug runtime selection list.**
  Once R22 and R24 are complete, delete the outer list whose only purpose was
  selecting between mechanically parallel dialect targets.

- [ ] **R26 — Document why MSVC `hermetic_link_flags` is empty.**
  Preserve upstream libc++ CMake behavior: `-nostdlib++` is added only when
  not MSVC, and `_LIBCPP_BUILDING_LIBRARY` suppresses self-auto-linking.
  Record that `/NODEFAULTLIB` is stronger and forbidden; do not invent a
  nonempty clang-cl equivalent.

- [ ] **R27 — Replace the asymmetric Windows hosted-C aggregate.**
  Compose symmetric named Windows semantics for headers, SDK/runtime inputs,
  and target defaults. Do not select between one MinGW header leaf and the
  complete MSVC toolchain aggregate under one name.

- [ ] **R28 — Make the runtime resource-directory stage matrix explicit.**
  Preserve the proved topology—MSVC static libc++ is Stage 0 and complete
  consumers use the target resource directory; generic Stage 1 links higher
  Unix runtime layers. Replace catch-all/default staging with explicit named
  stages and verify which branches are reachable through the unified
  toolchain.

- [ ] **R29 — Name complete-runtime exec helpers by their real boundary.**
  Preserve the complete Linux exec-runtime transition for `msvc_def_parser`
  and case tools, but expose a purpose-named exec-helper wrapper or explicit
  documentation. State that these helpers must not enter construction of the
  execution platform's own runtimes.

### Root target semantics

For R30-R37, keep all platform selection in `toolchain/BUILD.bazel` as required
by the README. Introduce named `windows_<semantic>` `cc_args_list` targets that
select MSVC versus MinGW implementations; canonical targets then select the OS
once. Implementation packages continue to contain no platform selects.

- [ ] **R30 — Windows default link flags.**
  Select MSVC SDK/CRT link defaults versus the existing MinGW implementation
  behind one Windows semantic target.

- [ ] **R31 — Windows default startfiles.**
  Select an intentional empty MSVC implementation versus the existing MinGW
  CRT search/startfile behavior.

- [ ] **R32 — Windows default libraries.**
  Select the MSVC driver/COFF-default-library model versus existing MinGW
  explicit defaults without enumerating MSVC platform labels in the canonical
  group.

- [ ] **R33 — Windows C++ library search paths.**
  Select the exact MSVC libc++ directory for the supported tuple versus the
  existing MinGW behavior.

- [ ] **R34 — Windows sysroot.**
  Select an intentional empty MSVC spelling versus the current MinGW empty-
  sysroot implementation.

- [ ] **R35 — Windows hermetic compile flags.**
  Select clang-cl's no-system/no-builtin include spelling versus generic
  Clang/MinGW spelling.

- [ ] **R36 — Windows standard-library driver selection.**
  Select an intentional empty MSVC implementation versus MinGW's generic
  `-stdlib=libc++` behavior.

- [ ] **R37 — Windows unwind-library driver selection.**
  Select an intentional empty MSVC implementation versus the existing MinGW
  `--unwindlib` behavior.

### Feature-set and toolchain-constructor semantics

- [ ] **R38 — Make MSVC known features exhaustive by classification.**
  Compose shared supported features, clang-cl/MSVC replacements, and explicit
  unsupported sentinels. Account for parsing, layering, external includes,
  runtime search, coverage, sanitizers, and ThinLTO rather than relying on a
  hand-written list that merely analyzes for current tests.

- [ ] **R39 — Compose enabled features from a shared ordered baseline.**
  Add explicit target/dialect deltas for MSVC response files, DEF, CRT, link
  defaults, and validation. Record intentional omissions such as PIC/module
  maps instead of duplicating the generic list.

- [ ] **R40 — Compose runtime enabled features from the same baseline.**
  Preserve the intentional absence of ordinary opt/dbg features where runtime
  rules own optimization. Express all other MSVC differences as named deltas.

- [ ] **R41 — Rename or replace `llvm_release_features` at Batch 6.**
  If the marker mechanism remains temporarily, rename the set to reflect that
  it only registers known feature names. If Batch 6 replaces the mechanism,
  remove the set only after proving both generic and clang-cl release actions.

- [ ] **R42 — Move SDK compile inputs into semantic include groups.**
  Remove the raw ABI select appended in `cc_toolchain`. Compose SDK case
  overlay and VC/UCRT includes through the named Windows/MSVC include-search
  implementation while preserving the established search order.

- [ ] **R43 — Keep header parsing explicitly temporary and unsupported.**
  Do not flip `supports_header_parsing` in this cleanup. Replace the unexplained
  boolean with a named target/decision boundary and state the future positive
  proof required: dialect-correct parse-only action plus coherent module-map
  and layering behavior.

- [ ] **R44 — Move artifact patterns behind target artifact semantics.**
  Artifact providers are not `cc_args`, so use a dedicated package/helper that
  returns the target-selected pattern list. Keep `.obj`/`.lib` for MSVC,
  current Windows executable behavior for MinGW, and macOS patterns unchanged.

### Reusable filesystem rules and MSVC payload ownership

- [ ] **R45 — Move the case-insensitive VFS rule to generic filesystem rules.**
  Keep the concrete VC/UCRT/SDK overlay target with MSVC runtime/sysroot data.

- [ ] **R46 — Move the case-folding directory copy rule to generic filesystem
  rules.** Keep only concrete Windows SDK library-copy targets in the MSVC
  payload package.

- [ ] **R47 — Split the top-level `windows` package by responsibility.**
  Move pinned Microsoft payload validation, curated VCRuntime/COM headers,
  runtime libraries, and concrete overlay/copy targets to
  `runtimes/msvc` or `runtimes/windows/msvc`. Keep argument spellings under
  toolchain args and reusable rules under generic filesystem utilities.

- [ ] **R48 — Move generic `DirectoryInfo` adapters.**
  Relocate the generic tree-artifact adapter and suffix-validation rule to the
  directory/provider utility package. Keep Microsoft-specific expected path
  assertions at their MSVC payload call sites.

### Deferred release-policy checkpoint

- [ ] **R49 — Separate release product policy from linkage mode and CRT
  semantics.** Preserve `/MT` release selection as the real
  `-dynamic_link_msvcrt` + `static_link_msvcrt` feature choice and preserve
  ordinary consumer `/MD`. Document that `--dynamic_mode=off` is independent.
  In Batch 6, decide where LLVM release-only no-exception/no-RTTI/frame-pointer
  policy should live without changing generic release products.

## Cohesive implementation batches

### Batch 1 — Restore shared argument semantics

Items: R09, R10, R12-R14, R19-R20, R22-R25.

Status: complete on 2026-08-24 in commits `9cb67778` and the immediately
following runtime/test/plan commit.

Evidence:

- Baseline actions `64f44faa-af70-4dc6-af49-66534dc1e77e`,
  `2ceece09-1fb4-4118-8af0-dd480c3c060f`, and
  `315a0aad-8009-4fd5-b4a8-eb0cfa99429f` showed unconditional `/Z7`, no
  explicit `/GS`, and no mapped default warning/frame-pointer policy.
- The focused MSVC action suite passed with default/opt/dbg and runtime
  assertions; the representative complete compile/archive/link consumer build
  passed without compiler warnings as invocation
  `b1e1ded8-d031-4d10-af0c-16f66e01c0ec`.
- A two-token `-Xclang` per-file override failed in invocation
  `72c0552e-f0cd-4146-81b7-9e2d6ca89413` because clang-cl's response parser
  detached its value. The single-token
  `-Xclang=-Wno-thread-safety-analysis` form is accepted by both Clang drivers
  and remains ordered after the MSVC default warning policy.
- MinGW and Linux opt action comparisons passed as invocations
  `397ae9f8-eb0d-4232-b1c0-b00d4f0c9932` and
  `5237d415-f159-4e79-a072-a85eb1e5075a`; generic ThinLTO backend invocation
  `79b86a93-1235-4c69-83d3-70d16a442a1e` again contains `-std=c++17`.
- The unsupported-configuration analysis suite, buildifier, and
  `git diff --check` passed. No full LLVM rebuild was run for this batch, per
  the consolidated verification policy below.

Purpose: fix the demonstrated generic C++ action regression and normalize the
repeated `cc_args` shape before changing package hierarchy. Work per semantic
flag/action, but deliver as one or two cohesive commits—not one commit per
checkbox.

Lightweight gate:

- `buildifier -mode=check` on touched BUILD/Starlark files;
- focused Windows MSVC action/analysis scripts;
- one representative x86-64 MSVC consumer artifact build;
- one representative MinGW and Linux aquery comparison proving their rendered
  action sets/flags did not narrow.

### Batch 2 — Normalize dialect and feature protocol

Items: R07-R08, R15-R16, R38-R40, R43.

Purpose: split clang-cl protocol from Windows/MSVC ABI ownership, restore
ordered legacy-feature composition, and make supported/unsupported feature
sets auditable. Keep header parsing unsupported.

Lightweight gate:

- focused feature/action/negative-boundary tests once for the batch;
- materialized representative compile, archive, and link parameter files for
  x86-64 and ARM64 MSVC;
- action comparison for one MinGW and one Linux target;
- a focused with/without experiment for R08, not a full Stage 3 rebuild.

### Batch 3 — Restore target semantic hierarchy

Items: R11, R27, R30-R37, R42, R44.

Purpose: make canonical targets select Windows once, move ABI routing behind
named Windows semantics, and remove raw SDK/artifact specialization from the
toolchain constructor.

Lightweight gate:

- cquery the selected semantic targets for MSVC x86-64, MSVC ARM64, MinGW, and
  Linux;
- build one ordinary MSVC consumer and one DLL/import-library consumer;
- inspect one compile and one final-link action for include/library ordering;
- compare representative MinGW/Linux rendered arguments before and after.

### Batch 4 — Clarify runtime and overlay ownership

Items: R04-R05, R26, R28-R29.

Purpose: make already-correct ABI/runtime-stage behavior legible without
changing LLVM source semantics or supported runtime contents. Most changes
should be names/comments/semantic aliases; stop if a proposed rename changes a
public label rather than retaining an alias.

Lightweight gate:

- build the MSVC compiler-rt builtins and static libc++ artifacts for both
  target CPUs;
- inspect archive names and runtime transitions once;
- build one generic libc++/libc++abi runtime representative to prove its graph
  remains unchanged.

### Batch 5 — Split generic filesystem rules from MSVC payloads

Items: R45-R48.

Purpose: perform label/package relocation after the semantic consumers are
stable. Use aliases only where public labels must remain compatible. Do not
change Microsoft payload contents, pinned paths, case policy, or EULA gates.

Lightweight gate:

- build the SDK VFS overlay and case-folded library directories for both target
  CPUs on one Linux exec platform;
- inspect tool `cfg = "exec"`, declared inputs, and output tree/overlay content;
- run buildifier and affected Starlark/unit tests.

### Batch 6 — Release-policy design checkpoint

Items: R18, R41, R49.

Purpose: run only after Batches 1-5 and only with a fresh owner decision.
Compare the temporary repository feature markers with an explicit LLVM product
policy build setting/transition. Preserve release-only scope, ordinary
consumer behavior, dialect-correct flags, static MSVC CRT release selection,
and generic release products. Do not fold frame-pointer omission into every
`-c opt` build.

No implementation begins until the owner chooses the replacement model.

## Verification strategy

### Baseline capture before the first approved batch

Capture compact cquery/aquery evidence for:

- Windows x86-64 MSVC `/MD`;
- Windows x86-64 MSVC `/MT`;
- Windows ARM64 MSVC `/MD`;
- one Windows MinGW target;
- one Linux target;
- runtime stages `stage0`, `stage1`, `stage1_hosted`, and `complete` where the
  changed semantic is reachable.

Save only filtered action text and materialized parameter files needed for
comparison. Preserve remote-download minimality; use
`--remote_download_regex` or selective BuildBuddy CAS downloads for inspected
artifacts rather than `--remote_download_all`.

### Per-batch checks

Do not run the full Stage 3 or repository CI matrix after each checkbox.

For each approved batch:

1. run buildifier and `git diff --check`;
2. run the smallest existing action/analysis or filesystem tests touching the
   changed layer;
3. build one representative MSVC consumer;
4. compare the previously captured representative generic action when the
   batch can affect shared semantics.

Escalate to a full source build early only if the focused action shows a
compiler/linker/runtime protocol change that cannot be validated on a small
consumer.

### Final consolidated proof

Run once after all action-affecting approved batches are complete:

1. focused `windows_msvc_action_test.sh` and
   `windows_msvc_analysis_test.sh` behavior;
2. `//e2e/rules_cc:windows_msvc_artifacts_matrix`, covering x86-64 and ARM64,
   `/MD` and `/MT`, libc++, archives, PE/COFF, PDB, DLL/DEF/import-library, and
   alwayslink behavior;
3. the ordinary `//e2e/rules_cc:main` build/use surface;
4. complete source-backed Windows x86-64 and ARM64 MSVC LLVM build/package
   inputs already used by the draft PR, once, with remote cache and minimal
   output download;
5. representative MinGW and Linux/macOS builds plus before/after filtered
   action comparison;
6. native Windows execution through the existing CI consumer lane once the
   local/remote graph is final—no temporary per-item lanes.

All MSVC commands that fetch Microsoft payloads use both existing EULA repo
environment flags:

```text
--repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
--repo_env=BAZEL_WINDOWS_SDK_EULA=1
```

Use `--config=remote` for remote proofs. Record exact commands, invocation IDs,
selected target/exec platforms, and intentional action differences.

## Final acceptance criteria

- Windows x86-64 and ARM64 MSVC consumers compile, archive, link, and produce
  the same valid PE/COFF machine types and runtime behavior as the baseline.
- `/MD` remains the ordinary consumer default; release `/MT` remains selected
  only through the explicit CRT features.
- Static libc++ remains the only C++ standard library on the MSVC route;
  VCRuntime ABI headers and the narrow CRT-selected Microsoft C++ helper remain
  declared without exposing Microsoft STL.
- Generic C++ actions regain their complete action coverage and established
  ordering.
- Compiler dialect and Windows/MSVC ABI packages are distinct and composed.
- Canonical argument groups select Windows once and contain no raw platform
  flags; Windows targets own the MinGW/MSVC branch.
- Known/enabled feature sets classify all shared, replaced, inapplicable, and
  unsupported behavior.
- Header parsing/modules remain explicitly unsupported, not silently enabled.
- MinGW/GNU, Linux, and macOS rendered behavior is unchanged except for
  harmless label/package relocation proved by action comparison.
- Filesystem helper rules are generic; Microsoft payload contents and EULA
  boundaries remain in the MSVC runtime/sysroot package.
- No ambient SDK/compiler/runtime input, target/exec inversion, public release,
  host-toolchain registration, or new permanent CI lane is introduced.

## Stop conditions

Stop and request owner direction before:

- changing LLVM source semantics or importing a new LLVM/rules_cc patch;
- enabling header parsing, modules, sanitizers, dynamic libc++, debug CRT, or
  Microsoft STL;
- changing a public label without a compatibility alias;
- changing generic release semantics or ordinary consumer CRT defaults;
- removing link-time `-no-canonical-prefixes` without proving sibling
  lld-link selection for source-backed tools;
- introducing `/NODEFAULTLIB`, explicit ambient SDK paths, or a broader
  Microsoft payload closure;
- adding, removing, or restructuring CI lanes rather than using the existing
  final consumer lane;
- starting prebuilt publication, release-index changes, or MSVC host toolchain
  work.

## Recommended starting point

Batch 1 is complete. Continue with **Batch 2 — Normalize dialect and feature
protocol** after owner approval.

The shared argument/action spine is now correct, so the next owning boundary is
the clang-cl action protocol and supported-feature classification. Completing
that before target hierarchy or package moves avoids carrying the current
parallel legacy-replacement and known/enabled feature structure into those
relocations.
