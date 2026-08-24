# Windows MSVC toolchain semantic cleanup plan

Status: active; Batches 1 and 2 and the approved target-semantic portion and
post-review leaf cleanup of Batch 3 are implemented and proved. R11/R42 remain
open by owner decision; remaining batches await owner selection.

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

## Tracking model

- This plan is the detailed implementation checklist. Keep cross-package work
  here instead of adding speculative `TODO` comments at individual call sites.
- GitHub issue #156, “Support Native MSVC ABI targets,” is the natural umbrella
  issue for the target-toolchain, prebuilt-publication, and future host-toolchain
  milestones. Issue #24 remains the broader Windows-support umbrella.
- Issue #714 already tracks the RTTI/exceptions build-setting design that
  overlaps the deferred Batch 6 policy checkpoint. Do not create a duplicate
  issue for R18, R41, or R49.

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
   contain concrete spellings and named semantic overrides; root toolchain
   assembly owns complete rules_cc argument ordering and selects between full
   generic and Windows compositions. Windows semantic implementations may
   select their subordinate ABI, CRT, SDK, and runtime variants, but do not
   own a complete toolchain argument list. Root assembly contains no raw flags.
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

- [x] **R07 — Make module behavior an explicit unsupported MSVC boundary.**
  Keep generic module flags unchanged. Do not pass raw GNU flags to clang-cl or
  claim module/header-parsing support. Represent the empty MSVC implementation
  explicitly, and ensure requests for layering/module parsing fail or remain
  disabled coherently until R43 is separately graduated.

- [x] **R08 — Isolate and re-prove link-time `-no-canonical-prefixes`.**
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
  Owner decision: defer this item; the proposed
  `compiler_resource_include_args` constructor interface was not satisfactory.

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

- [x] **R15 — Rebuild legacy replacements as an ordered common spine.**
  Classify every generic replacement as shared, dialect-replaced,
  target-inapplicable, or explicitly unsupported. Preserve common ordering,
  especially user flags before compiler input/output and the linker parameter
  protocol. Do not maintain an independent approximate MSVC ordering.

- [x] **R16 — Split compiler-dialect features from Windows/MSVC ABI features.**
  Move CL spelling, response, dependency, `/D`, `/I`, `/Fo`, and `/clang:`
  behavior into a clang-cl adapter layer. Keep PE/COFF artifact naming,
  `/MACHINE`, import-library and PDB contracts, CRT, SDK closure, and ABI
  validation in a Windows/MSVC target layer. Express shared, strip, DEF,
  runtime-search, and SONAME through their canonical feature semantics; only
  their concrete clang-cl-to-lld-link rendering belongs to the compiler/linker
  bridge.

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

- [x] **R27 — Replace the asymmetric Windows hosted-C aggregate.**
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

### Target/platform semantic hierarchy

For R30-R37, the public `toolchain_args` target selects the target OS once
between complete generic and Windows compositions. The complete Windows list
has the same ordered semantic positions as the generic list, but references
Windows, clang-cl, COFF, MSVC ABI, CRT, or SDK overrides where required.
`toolchain/args/windows` owns only named Windows semantic implementations and
their local variant selection; it does not own the complete rules_cc argument
list. Concrete `windows/mingw` and `windows/msvc` leaves contain flags,
actions, inputs, and data without choosing between platform variants.
Compiler-personality implementations remain separate and are composed
explicitly at the supported route boundary.

- [x] **R30 — Windows default link flags.**
  Select MSVC SDK/CRT link defaults versus the existing MinGW implementation
  behind one Windows semantic target.

- [x] **R31 — Windows default startfiles.**
  Select an intentional empty MSVC implementation versus the existing MinGW
  CRT search/startfile behavior.

- [x] **R32 — Windows default libraries.**
  Select the MSVC driver/COFF-default-library model versus existing MinGW
  explicit defaults without enumerating MSVC platform labels in the canonical
  group.

- [x] **R33 — Windows C++ library search paths.**
  Select the exact MSVC libc++ directory for the supported tuple versus the
  existing MinGW behavior.

- [x] **R34 — Windows sysroot.**
  Select an intentional empty MSVC spelling versus the current MinGW empty-
  sysroot implementation.

- [x] **R35 — Windows hermetic compile flags.**
  Select clang-cl's no-system/no-builtin include spelling versus generic
  Clang/MinGW spelling.

- [x] **R36 — Windows standard-library driver selection.**
  Select an intentional empty MSVC implementation versus MinGW's generic
  `-stdlib=libc++` behavior.

- [x] **R37 — Windows unwind-library driver selection.**
  Select an intentional empty MSVC implementation versus the existing MinGW
  `--unwindlib` behavior.

### Feature-set and toolchain-constructor semantics

- [x] **R38 — Make MSVC known features exhaustive by classification.**
  Compose shared supported features, clang-cl/MSVC replacements, and explicit
  unsupported sentinels. Account for parsing, layering, external includes,
  runtime search, coverage, sanitizers, and ThinLTO rather than relying on a
  hand-written list that merely analyzes for current tests.

- [x] **R39 — Keep enabled features as explicit ordered dialect/ABI lists.**
  The owner explicitly preferred duplication over an early shared feature-set
  abstraction. Keep the generic and MSVC lists independently readable, while
  composing the clang-cl response protocol separately from DEF, CRT, link
  defaults, and ABI validation. Record intentional omissions such as PIC and
  module maps.

- [x] **R40 — Keep runtime enabled features explicitly ordered.**
  Preserve the intentional absence of ordinary opt/dbg features where runtime
  rules own optimization. Duplicate the short runtime list explicitly rather
  than hiding stage differences behind a premature shared abstraction.

- [ ] **R41 — Rename or replace `llvm_release_features` at Batch 6.**
  If the marker mechanism remains temporarily, rename the set to reflect that
  it only registers known feature names. If Batch 6 replaces the mechanism,
  remove the set only after proving both generic and clang-cl release actions.

- [ ] **R42 — Move SDK compile inputs into semantic include groups.**
  Remove the raw ABI select appended in `cc_toolchain`. Compose SDK case
  overlay and VC/UCRT includes through the named Windows/MSVC include-search
  implementation while preserving the established search order.
  Owner decision: defer with R11; keep the current raw SDK append until the
  resource/include boundary has a satisfactory design.

- [x] **R43 — Keep header parsing explicitly temporary and unsupported.**
  Do not flip `supports_header_parsing` in this cleanup. Replace the unexplained
  boolean with a named target/decision boundary and state the future positive
  proof required: dialect-correct parse-only action plus coherent module-map
  and layering behavior.

- [x] **R44 — Keep the current explicit artifact-pattern selection.**
  Artifact providers are not `cc_args`. Owner decision: the current
  constructor-local selection is sufficiently clear and low risk; no
  relocation is required in this cleanup. Keep `.obj`/`.lib` for MSVC, current
  Windows executable behavior for MinGW, and macOS patterns unchanged.

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

Status: implementation complete on 2026-08-24 in commits `9cb67778` and
`708e5da8`; consolidated proof complete on the same branch and date.

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
  `git diff --check` passed.
- The final artifact matrix passed for x86-64 and ARM64 as invocation
  `15388ca8-9d27-4926-a6c3-8915fef7e0a1`, covering `/MD`, `/MT`, static
  libc++, ThinLTO, archives, PE/COFF, PDB, DLL/DEF/import libraries, and
  alwayslink behavior.
- Representative generic builds remained successful: Linux `//:main` as
  invocation `616198d6-f9ad-4f7c-98cb-93205b4df5b5`, and MinGW
  `//:windows_test` plus `//:windows_unicode_test` as invocation
  `e10d0a0a-6e04-4f3e-ba2f-e71d3747e4c1`.
- The complete release prebuilt targets for both MSVC architectures passed as
  invocation `3407be8c-51e2-443b-9832-895c4488a113` (112,081 actions). The
  downloaded archives have SHA-256 values
  `89e98cc6926a341da472ec54762775e22afd32908b9c455ceef4f95e02627da0`
  for x86-64 and
  `ed2b29275eb9164ac728d7f028844d82894637506f3ae1fc8e185311e8ed5afe`
  for ARM64. Extracted `bin/llvm.exe` reports
  `IMAGE_FILE_MACHINE_AMD64` and `IMAGE_FILE_MACHINE_ARM64`, respectively;
  the ARM64 binary is not ARM64EC. The four representative driver names in
  each archive have identical hashes, proving the intended multicall payload.
- A full generic `//...` test request cannot be reproduced faithfully from a
  Darwin host with Linux targets because several tests are intentionally
  local-only: invocations `a093a78e-4325-4a6e-ac7d-c95efeb73cd5` and
  `9f9b264d-a407-4f7b-a94b-430f5e08e14b` failed only by trying to execute the
  opposite host format, while forcing `TestRunner` remote was rejected in
  `1b423980-56b8-4718-a262-5f49f1b7f399`. Keep the ordinary `//...` run on
  its existing Linux CI hosts; this is an environment boundary, not a product
  regression.

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

Status: implementation and grouped proof complete on 2026-08-24.

Owner decisions:

- keep the globally requested `layering_check` as an explicit temporary no-op
  instead of failing while dialect-correct support is planned next;
- introduce `//toolchain/features/clang_cl`, with a README recording the proved
  explicit compiler-personality assembly boundary while deliberately leaving
  the final upstream rules_cc package shape undecided;
- keep generic and clang-cl/MSVC known, enabled, runtime, and legacy orderings
  explicitly duplicated instead of creating shared feature-set abstractions.

Post-review semantic correction:

- commits `20e05026` and `c851093f` split compiler-personality defaults from
  Windows SDK, CRT, libc++, and PE/COFF policy, then move linker behavior under
  canonical legacy/clang-cl feature ownership;
- toolchain assembly chooses explicit generic or clang-cl implementations. A
  feature used to construct the current toolchain must not select on
  `@rules_cc//cc/compiler`, because that setting depends on the toolchain being
  constructed;
- the generic and clang-cl legacy feature sets remain intentionally duplicated
  and ordered. No shared-list abstraction or feature-set flattening was added;
- the unreleased `msvc` adapter aliases were removed. There is no compatibility
  contract to preserve before this PR is released.

Evidence:

- Baseline x86-64 and ARM64 action captures passed as invocations
  `7b192c17-ed21-465f-aa10-932dbfdfe15b` and
  `f5f3ec73-7144-4837-9765-0d9eedbe6032`. Baseline MinGW and Linux captures
  were `4ab0673b-acf9-4e7d-8cbe-6bdaba4e3e77` and
  `4370c90e-0820-4422-a2cf-00768e5a39a5`.
- R08 removed only the raw link-time `-no-canonical-prefixes`. Source-backed
  focused consumers built for x86-64 and ARM64 as invocations
  `107c88ce-714a-4413-bfd6-3d14ae7f3fdc` and
  `d5cc0225-f07f-4cb1-a4fa-82704340236b`; their actions retain declared
  Stage 1 `clang-cl`, its sibling `lld-link`, and `/clang:-fuse-ld=lld`.
  Compile-time `/clang:-no-canonical-prefixes` remains unchanged.
- `//toolchain/features/clang_cl` now owns CL compile/input/output, dependency,
  include/define, response-file, DEF rendering, link-forwarding, and ThinLTO
  protocol. `//toolchain/features/msvc` retains ABI validation, CRT, llvm-ar
  COFF archives, `/MACHINE`, import-library/PDB contracts, and deterministic
  link policy. Canonical legacy features own shared, strip, runtime-search, and
  SONAME semantics.
- The two explicit legacy lists follow the same logical slot order. New focused
  assertions prove user compile flags precede compiler input/output and user
  link flags precede `/Fe`; these assertions fail against the previous MSVC
  ordering and pass after the change.
- Materialized x86-64 and ARM64 compile/link/archive response files are ASCII,
  carry the correct target triples, `/MACHINE:X64` or `/MACHINE:ARM64`, `/Fe`,
  `/WHOLEARCHIVE`, `.obj`/`.lib`, and deterministic `llvm-ar rcsD`. No GNU
  `-Wl,`, `-o`, ambient SDK path, or host-CPU target token appears.
- The focused Windows MSVC action and negative-boundary suites pass. A
  `layering_check` request renders no GNU module flags; an explicit
  `parse_headers` request fails with the Layer 1 unsupported-feature message.
- A complete focused clang-cl/COFF ThinLTO consumer built as invocation
  `6f233181-571c-415f-a41b-c1a0608bdb77`. ARM64 ThinLTO action inspection as
  invocation `65491f4f-cf7d-4012-9a79-1331a99db58f` shows source-backed
  `clang-cl`/`lld-link`, ARM64 target and machine, COFF index/backend protocol,
  and no GNU linker/output/language tokens.
- Post-change MinGW and Linux actions from invocations
  `b2496c39-1180-4cfb-a7cb-45a3dc0354e2` and
  `23ddbfe3-99b9-414c-9fdc-430fc3d65b17` are byte-for-byte identical to their
  baseline captures.
- The full focused Windows artifact matrix passed for both CPUs as invocation
  `e856563b-2597-4702-8f09-e72b48c3b09a`, without disabling the globally
  requested `layering_check`. It covered `/MD`, `/MT`, ThinLTO, static
  archives, PE/COFF machine types, PDB, DLL/DEF/import libraries, and
  alwayslink behavior.
- The first attempt to select clang-cl spellings through
  `@rules_cc//cc/compiler:clang-cl` failed with a current-toolchain dependency
  cycle in invocation `05091cd8-6c47-4f3c-9fcf-888f0e2a95ac`. Explicit
  compiler-personality implementations at toolchain assembly remove that
  cycle without marker features.
- Final x86-64 MSVC, ARM64 MSVC, MinGW x86-64, and Linux x86-64 action captures
  from invocations `c6306e43-38e3-4cf6-9bb9-1d369f872210`,
  `8e3ab994-46b0-4e94-af73-59cde371ae92`,
  `cfaa5525-4cce-4ded-bf05-2852fe948fe8`, and
  `de817042-d3e5-47a1-940d-1be8e9f1b956` are byte-for-byte identical to the
  saved pre-correction captures.
- The final action suite passed with the globally requested `layering_check`.
  The final negative suite also passed; its explicit `parse_headers` boundary
  was invocation `23af7870-b007-4eb8-90b7-823ed19baf66`.
- The post-correction focused action and negative-analysis scripts both passed.
  The artifact matrix passed for x86-64 and ARM64 as invocation
  `05e62972-2138-4279-bfca-1a2c04907207`; repository buildifier passed as
  invocation `6f39c2fa-c556-4cf2-9a8f-dcd6249ea541`.
- Existing warnings from the test target applying `/std:c++20` to its C and
  assembly sources remain visible; the baseline action already contained the
  same target-local option and Batch 2 does not change that test policy.

Lightweight gate:

- focused feature/action/negative-boundary tests once for the batch;
- materialized representative compile, archive, and link parameter files for
  x86-64 and ARM64 MSVC;
- action comparison for one MinGW and one Linux target;
- a focused with/without experiment for R08, not a full Stage 3 rebuild.

### Batch 3 — Restore target semantic hierarchy

Items: R27, R30-R37, R44 complete; R11 and R42 deferred.

Purpose: make the public toolchain target select Windows once between complete
generic and Windows compositions, while keeping each concrete override behind
a named Windows semantic. The owner retained the current
compiler-resource/SDK constructor boundary and artifact-pattern selection for
now.

Lightweight gate:

- cquery the selected semantic targets for MSVC x86-64, MSVC ARM64, MinGW, and
  Linux;
- build one ordinary MSVC consumer and one DLL/import-library consumer;
- inspect one compile and one final-link action for include/library ordering;
- compare representative MinGW/Linux rendered arguments before and after.

Completed approved implementation:

- commit `ecba116b` establishes the physical package taxonomy: concrete
  flags/actions/data live under `toolchain/args/windows/mingw` and
  `toolchain/args/windows/msvc`; the former MinGW-only meaning of
  `toolchain/args/windows` and top-level sibling `toolchain/args/msvc` package
  no longer exist;
- commit `f693a066` corrects the remaining aggregation ownership. The public
  `//toolchain:toolchain_args` now selects complete
  `generic_toolchain_args` or `windows_toolchain_args` compositions by target
  OS. The staged runtime toolchain follows the same full-composition model;
- the Windows lists mirror the generic ordered semantic positions explicitly
  and replace only the applicable compiler-personality, object-format, ABI,
  CRT, SDK, and C++ runtime entries. Windows arguments no longer arrive as a
  late delta through `platform_specific_args` or
  `staged_platform_specific_args`;
- `toolchain/args/windows` retains named semantic overrides and their local
  MinGW/MSVC/CRT selection, but its complete `toolchain_args`,
  `hosted_c_toolchain_args`, and `runtime_toolchain_args` aggregates are
  removed. Complete rules_cc group ordering belongs only to `toolchain` and
  `toolchain/runtimes`;
- MinGW CRT library selection and native MSVC static-versus-dynamic CRT search
  path selection remain in the named Windows semantic implementations.
  Concrete leaf packages contain no OS/ABI/CRT-family routing; the remaining
  MSVC leaf select is only the existing runtime-build-stage condition for
  libc++ headers;
- reusable clang-cl defaults remain in `toolchain/args` and are composed
  explicitly with the native MSVC-ABI target implementation at the supported
  Windows route boundary. No reusable clang-cl action protocol moved into a
  Windows package;
- runtime-stage differences are expressed at their individual semantic slots
  inside the complete runtime Windows composition. Hosted-C excludes C++
  runtime policy and retains the established MinGW header behavior;
- the `compiler_resource_include_args` experiment was fully reverted by owner
  decision. The existing `extra_args` constructor input and raw post-resource
  MSVC SDK append remain unchanged except for the concrete leaf's relocated
  label; R11 and R42 stay open;
- R44 required no implementation by owner decision. The existing explicit
  artifact-pattern selection remains unchanged. The removed unpublished
  argument labels had no consumers outside this repository, so no aliases were
  added.

Post-review semantic correction:

- commit `6211fb89` removes the invented `msvc_target_compile_args` and maps
  every retained default to an existing semantic position: target
  compatibility in `target_flags`, `/Brepro` and deterministic CodeView in
  `deterministic_compile_flags`, `/DNOMINMAX` in SDK compile arguments, and
  clang-cl banner/exception/RTTI defaults in the existing compiler-personality
  legacy feature. Only `/bigobj` keeps a precise Windows COFF semantic target;
- `_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS` is no longer a global toolchain
  define on every source compile. The generated libc++ `__config_site` now
  encodes it for the supported configuration-wide static-libc++ Windows MSVC
  route, matching upstream libc++'s static Windows configuration behavior.
  The existing local define used while compiling libc++ itself is retained;
- selecting the generated definition with the runtime-internal
  `:windows_static` condition was rejected by proof: public headers are
  configured in the consumer configuration, outside the runtime linkmode
  transition. Invocation `4c46350e-594d-48af-ad03-ea531a905131` therefore
  failed the new public-header assertion. Selecting the exact supported
  `:windows_msvc` tuple makes the configuration-wide static-libc++ contract
  explicit without coupling it to ordinary consumer `/MD` versus `/MT`;
- this correction does not complete R05. The remaining Stage 0 target naming,
  ASan distinction, and final COFF auto-link copy documentation stay in Batch
  4. R11/R42 remain deferred, and R44 remains an implementation no-op.

Evidence:

- baseline MSVC compile action `aa285157-224b-4293-bb50-c97921339285`
  contained the required compatibility, clang-cl default, deterministic COFF,
  large-object, and SDK flags plus a global
  `/D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS`; baseline generated-config
  invocation `bdcd250b-d783-4821-a7be-503d343d5bc7` did not define the libc++
  setting;
- corrected MSVC action invocation
  `a3ca047d-0304-4f2a-a32a-87e0a66bdc4a` retains every required flag while
  removing the global libc++ define. Generated-config and support-library
  invocation `3b7a012b-3ae0-48a7-8b41-58e61cd0eb67` produces a config site
  containing `_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS` and proves ordinary
  public-header consumers observe it;
- ordinary libc++ and DLL/import-library consumers built for x86-64 as
  invocation `3e3ab940-fe90-4fc5-a0d9-2f349f0192d5` and ARM64 as
  `ea0b399b-9e66-462d-ab57-954a506ebc23`;
- the focused Windows MSVC action suite passed from invocation
  `8c4939d2-cf09-4c1a-be1e-57ce7facfd8e` through
  `65d6cea7-2313-4771-80ab-247a0c263299`. The negative suite preserved all
  five expected failures as invocations
  `e7c78f9d-df1e-4350-8675-9d3d55c322d9`,
  `98610d1d-c5cc-49cc-8e9a-a7a9684b17de`,
  `e659259f-6cc8-4f6c-91cb-c9c6176086b7`,
  `32367cba-70f0-4d52-98ba-c8fbb7f7a199`, and
  `00e68814-fa8d-4543-8109-1799635cee18`;
- MinGW and Linux action captures from invocations
  `352c4f10-83b1-4ab1-98fd-5e5861ee8a5b` and
  `5385bbe4-d99d-4802-a662-ea1d7b540dbe` are byte-for-byte identical to their
  pre-correction captures, with SHA-256 values
  `dce1aac81511fb528fa725dd25a38ec19ab12f5940fe494ff2bf6fefc3abe388`
  and `c3075d0eb95ea6dec2f33653231cf533804931d470e7517c9dd83e7561875cdc`.
  Their representative builds passed as invocations
  `a6ea5ad3-b5a4-43b4-a868-75845fcae913` and
  `a95529b3-3e13-4b7d-9abe-86c303168ebb`;
- repository buildifier passed as invocation
  `6274e2cf-2c4a-47ed-888b-f278eec7399c`; `git diff --check` also passed. No
  Stage 3 rebuild was needed because the changed ownership is directly proved
  by the focused x86-64/ARM64 consumers and generated actions, while generic
  rendered actions are identical.

- final configured-graph queries prove x86-64 MSVC, ARM64 MSVC, and MinGW all
  select `//toolchain:windows_toolchain_args` as invocations
  `cda9ea1d-ad21-43a1-87c1-c477f8dfbdda`,
  `0758cfd5-b484-4bb5-924c-8d6731d67649`, and
  `edfc734e-abb2-4d88-959f-aa50153ac2a4`; Linux selects
  `//toolchain:generic_toolchain_args` as
  `df0f6d8c-9f71-4e90-bc23-037ab943850b`. The ARM64 staged-runtime query
  selects `//toolchain/runtimes:windows_toolchain_args` as
  `a9b14ae9-a787-44e9-8b77-05c5310bdee3`;
- immediately before commit `f693a066`, representative MSVC, MinGW, and Linux
  compile/link actions were captured as invocations
  `728ec25b-0f4c-447b-9650-9838cff730a6`,
  `3accf383-fe76-4878-aa69-533374043c6f`, and
  `b7aaf491-9225-4e96-a054-04c6aa969c10`. Post-change captures
  `f6800ce9-0147-4a1c-8589-9aa61d3a417c`,
  `e9ef648a-5da7-419c-99c2-a8ea01bfd8ed`, and
  `60eea284-ad77-4a11-bbb7-e82957699caf` are byte-for-byte identical, with
  SHA-256 values `ecbf4bd9c8107aa4fe475e31bfe54bdaeaa39bd55ae640e329e522bee80de680`,
  `dce1aac81511fb528fa725dd25a38ec19ab12f5940fe494ff2bf6fefc3abe388`,
  and `c3075d0eb95ea6dec2f33653231cf533804931d470e7517c9dd83e7561875cdc`;
- the focused Windows action suite passed from first invocation
  `97ea9652-01b8-4f4e-b6fa-8bdd9624a4df` through final invocation
  `e018313a-4c7e-4d65-80ea-66cc0db38100`. The negative boundary suite passed
  all five expected failures as invocations
  `1a545a81-a571-4fd8-be54-ca12e6af832c`,
  `e31ce8ba-85fc-4d9c-bab2-4b704ce7bf19`,
  `e385fb7d-5c77-4cdd-b942-474d39f5ee22`,
  `08618ec0-2827-48b1-991d-3dd7a676f369`, and
  `46fe85e1-1703-4d48-8617-b07732c3ada2`;
- ordinary and DLL/import-library consumers built after the final correction
  for x86-64 MSVC as invocation
  `c5591a2d-31be-4092-8b09-7b918e3a45a4` and ARM64 MSVC as
  `87ca5e9d-b43b-471c-9922-be63266bc13e`. Representative MinGW and Linux builds
  passed as `211d2a82-e344-4d45-b667-409037c35ef5` and
  `96c291b4-e773-47b0-81ab-a0a563cd4494`. No Stage 3 rebuild was needed because
  the representative rendered actions are byte-for-byte identical;
- repository buildifier passed as invocation
  `4dd779f7-1aae-46d5-b26c-ff6591cb7800`; `git diff --check` also passed;

- Pre-correction semantic cqueries were invocations
  `6cd30cbb-7151-4549-8141-0aa6a0fc6dd9` (x86-64 MSVC),
  `70036af0-5506-4ced-bc61-7d7e0a6c7fa1` (ARM64 MSVC),
  `23c76e00-daeb-470d-9307-28544458499a` (MinGW), and
  `36b6917b-5470-44c4-b19b-9dc950ac0a47` (Linux). Corrected cqueries passed as
  `e8f3badb-a9a2-4486-ae57-df25028e3b4e`,
  `121c2e0a-234e-47e6-8d3e-b2427f606535`,
  `34e8af95-1053-4613-a4a8-5e418bc3b63e`, and
  `6e1d8c61-5ea0-4948-9a91-acb222a9eb70`. The configured Windows graph now
  reads root canonical target -> Windows semantic target -> selected concrete
  MinGW/MSVC leaf;
- expanded representative MSVC, MinGW, and Linux compile/link action captures
  from pre-correction invocations `6cf48fbb-7059-4657-a02a-c1dfbfd8c5cd`,
  `d627d395-5239-4bc3-a1d4-8379f50fc0e3`, and
  `f6553304-fdc5-43e6-b2ca-ecce0d6fd9f4` are byte-for-byte identical to
  corrected invocations `5599e097-fea3-426b-8123-9b933d5eaa16`,
  `a697daf0-6d15-4a74-a063-c2b5a5616267`, and
  `4d50a82b-a0e7-40ae-b070-9be6c7830b7b`. Their SHA-256 values remain
  `5bf5372a8774440414a14ddb0c198fa87b5ad6982035871b2787f0575f8b38bc`,
  `dce1aac81511fb528fa725dd25a38ec19ab12f5940fe494ff2bf6fefc3abe388`,
  and `c3075d0eb95ea6dec2f33653231cf533804931d470e7517c9dd83e7561875cdc`.
  MSVC retains libc++ headers, Clang resource headers, then VC/UCRT headers;
- ordinary and DLL/import-library consumers built for x86-64 MSVC as
  invocation `f6560b2f-8af1-4283-b001-17eb5e155567` and ARM64 MSVC as
  `dbbbefe1-6147-4308-900b-d5d0012d2191`;
- the focused Windows MSVC action and negative-analysis scripts passed. The
  representative MinGW and Linux builds passed as invocations
  `6515cca0-5fb3-4a2a-a35a-f1dec07b2cbb` and
  `9797abf1-cc98-420b-a9ee-c72785b238b4`. Existing target-local `/std:c++20`
  warnings remain unchanged. No Stage 3 rebuild was needed because every
  representative rendered action remained identical.

Post-review compiler-personality and leaf naming completion:

- [x] Commit `b9d1bea2` places reusable clang-cl hermetic-include and C++
  runtime library-search spellings beside their generic Clang counterparts.
  `/clang:-nobuiltininc` now stays with explicit clang-cl resource-header
  injection because it exists to enforce libc++ -> resource -> VC/UCRT order,
  not to define generic hermetic compilation;
- [x] The remaining clang-cl C++ runtime header-search implementation moves
  out of the MSVC ABI leaf as
  `clang_cl_cxxstdlib_headers_include_search_paths`. Prebuilt and source-built
  `compile_resource_dir_msvc` targets and their selector helper are renamed for
  their actual clang-cl personality ownership;
- [x] Directly affected MSVC leaf labels now use their semantic names:
  deterministic COFF-object/CodeView flags and COM-support, dynamic/static
  CRT, and SDK library search paths. Flags, actions, data, selection, and
  ordering are unchanged;
- [x] No compatibility aliases are added. Repository-wide label search proves
  all renamed labels are internal to this unpublished implementation.

Evidence:

- Item 5's focused Windows action suite passed from invocation
  `b06c69b2-8453-45bf-88af-66af333ecc63` through
  `63d500a3-4294-4e05-b79d-ba9f58e61d71`. Linux ThinLTO action query
  `9c52cb8e-c09a-4a2f-88f6-8b08b7e95cc9` keeps `-nostdlibinc` and the
  declared resource headers on source compilation and omits header-search
  flags from the backend;
- pre-rename x86-64 MSVC compile/link captures were invocations
  `810a1cd3-321f-4944-adaa-1f9f9f0ef302` and
  `8acd63cb-2ee5-4d22-b6cd-c25cd622c177`. Post-rename captures
  `7518046d-0e41-4deb-b682-13e8cbdf522e` and
  `930e5d48-b14c-42ba-a26c-0c9d2d8b793e` are byte-for-byte identical, with
  SHA-256 values `28778084e1d7abc78113af19c9cb3673c0c4acd1155ad5ea207605a5739c6e37`
  and `001c8669175fade2aedca4162dcf409e9f5a261a1b877377b1562d6726e2c944`;
- ARM64 action query `0ef833c3-5473-4828-98b9-3478528c7f90` resolves the
  renamed resource target and retains the native target triple, `.obj`
  output, libc++ -> resource -> VC/UCRT include order, and declared SDK
  inputs;
- the grouped Windows MSVC action suite passed from invocation
  `37c955eb-90bc-4647-8ef6-d2834a94b3db` through
  `cdd0e33c-a62b-487d-aba3-5123224c1504`. Buildifier and
  `git diff --check` passed. No Stage 3 rebuild was needed because the complete
  representative commands are byte-identical and both target CPUs resolve
  the renamed graph.

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
- The public toolchain argument target selects Windows once between complete
  generic and Windows compositions and contains no raw platform flags; named
  Windows semantic targets own their MinGW/MSVC variants.
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

Batches 1 and 2 and the approved target-semantic portion of Batch 3 are
complete. R11/R42 are explicitly deferred. Continue with **Batch 4 — Clarify
runtime and overlay ownership** only after owner approval.

The shared argument policy, clang-cl action protocol, and Windows target
semantics now have distinct owning layers. Compiler-resource/SDK include
ownership remains intentionally unchanged. The next approved owning boundary
would be the already-correct runtime/overlay topology: clarify the
libc++/VCRuntime ABI-header contract, static libc++ Stage 0 naming, empty MSVC
hermetic-link semantics, and complete-runtime exec-helper boundary without
changing their behavior.
