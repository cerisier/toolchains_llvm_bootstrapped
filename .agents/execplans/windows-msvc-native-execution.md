# Windows MSVC native execution completion plan

Status: in progress. This plan is the canonical specification for Step 13 of
`windows-msvc-prebuilt-llvm.md` and is a hard prerequisite to merging any
Windows MSVC implementation from that sequence or publishing its toolchain.

Date: 2026-08-25 (Asia/Tokyo)

## Progress

- [x] Batch 1: focused compatibility tests committed as `e1c665bd` on
  `cerisier/windows-msvc-prebuilt-llvm-step4`. Six focused tests pass uncached
  in BuildBuddy invocation `93ae6e2f-72ae-45e1-9c79-7240cb622728`.
- [x] Batch 2: capability-based rename committed as `fe65ac46`; focused tests
  pass in invocation `770c6c8f-8ce7-4b31-afb6-fd9efac1b73b`.
- [x] Batch 3: portable hosted-C ports implemented locally. All six focused
  tests pass locally on macOS ARM64 in invocation
  `698fefda-e25a-46e3-960f-53b446e93d8d` and on Linux ARM64 RBE in invocation
  `8abf0f70-e199-4456-8ee1-5d3703c74675`. Linux action inspection in invocation
  `6d2e61c1-6993-4e48-9fc1-c7c1c45cc4eb` finds no helper C++ source, libc++,
  libc++abi, C++ header, or auto-link input. Local old/new differentials match
  VFS bytes, copied trees, and real AMD64 COFF DEF output. All three production
  helpers cross-compile without execution for MinGW x86-64 and ARM64 in
  invocations `0bb85ae6-3c57-44e4-8d9e-cccebecbb8e9` and
  `de6ecbbf-81d8-4216-9d4e-12c4991e1687`, and for MSVC x86-64 and ARM64 in
  invocations `de3ff1a0-de72-4e26-95f0-6a1428a42a1b` and
  `73be3532-fe49-4c50-b69b-770f9c13e950`. PE inspection finds AMD64 and native
  ARM64 outputs for both Windows ABIs. The first MSVC x86-64 link correctly
  exposed that the hosted-C runtime composition still requested
  `libc++.lib` (`c2e065d4-c84b-4d4c-a6b7-8b185e93c823`); the owning MSVC
  `default_libs` group now retains declared SDK/CRT roots while omitting only
  the C++ default library at `runtimes_stage1_hosted`. Post-fix link action
  inspections are `5117c617-4b93-44ea-aec7-b0e612137bbc` and
  `42b91d9e-827f-4076-9228-05e1804992b9`. Human review approved the batch.
- [ ] Batch 4: construction/complete MSVC tool-map split.
- [ ] Batch 5: execution-filesystem SDK representation.
- [ ] Batch 6: native consumer/ThinLTO and Linux RBE regression proof.

## Objective

Remove the C++ runtime cycle from the small execution tools used to construct
the Windows MSVC toolchain, represent SDK case handling as an execution-
filesystem concern, and prove that the published LLVM toolchain can compile,
archive, ThinLTO-optimize, link, and run representative Windows programs on
matching native Windows executors.

The finished graph must preserve two already-proved production contracts:

- Windows MSVC release archives continue to be produced by the existing Linux
  RBE Stage 1 -> instrumented Stage 2 -> merged profile -> ThinLTO/FDO Stage 3
  graph;
- Linux RBE remains the supported producer of bootstrap FDO profiles. This
  plan does not add native-Windows profile generation, merge, application, or
  full Stage 3 construction.

Native Windows support in this plan means toolchain construction plus ordinary
and ThinLTO consumer actions. It does not mean rebuilding the complete LLVM
release pipeline on one Windows machine.

## Starting facts

- `tools/windows_case`, `tools/windows_case_vfs`,
  `tools/windows_case_copy`, and `tools/msvc_def_parser` are currently C++
  programs built through `cc_runtime_complete_binary`.
- On a Windows execution platform, those tools therefore request the complete
  C++ runtime graph that they help construct or consume. The case tool can
  request the SDK view it is meant to generate, and the DEF parser can request
  the tool map that contains the parser itself.
- The VFS overlay and case-folded copies exist so a case-sensitive execution
  filesystem can consume case-insensitive Microsoft include and library
  layouts. They are not Windows target semantics and are useful independently
  of Windows as an execution OS.
- DEF parsing is a COFF/DLL action capability, not an MSVC compiler-personality
  capability. The implementation is currently named after MSVC even though
  its input/output contract is COFF object files and module-definition data.
- `cc_tool_map` eagerly configures all labels in its `tools` attribute. Target
  features do not prune that dependency set. Disabling
  `windows_export_all_symbols` on the DEF parser target therefore cannot break
  the parser -> selected toolchain -> tool map -> parser edge.
- Ordinary parser compilation does not enable
  `windows_export_all_symbols` today. Adding its negative feature would merely
  restate current action intent; it would not change tool-map analysis.
- `cc_runtime_stage1_hosted_binary` already models portable hosted-C build
  tools using compiler primitives plus target C headers/runtime. No new
  Windows-specific runtime stage is required.
- Source-backed clang-cl/lld-link COFF ThinLTO and the Linux RBE Stage 3
  ThinLTO/FDO product are already proved for Windows x86-64 and ARM64 targets.

Before implementation, refresh these facts with `cquery`, `aquery`, and
materialized response files on the exact implementation base. Record the
configured cycle or complete-runtime dependency rather than inferring it from
source labels.

## Ownership model and invariants

Keep these axes separate:

- target OS and ABI decide Windows/COFF/MSVC target semantics;
- compiler personality decides clang versus clang-cl action grammar;
- CRT and C++ runtime selection decide `/MD` versus `/MT` and libc++ inputs;
- execution platform decides executable suffixes and filesystem case behavior;
- product configuration decides that release LLVM is built with ThinLTO and
  bootstrap FDO on Linux RBE.

The following invariants are mandatory:

1. Small construction helpers are portable C and do not depend on libc++,
   libc++abi, C++ headers, C++ auto-link metadata, or a complete C++ runtime.
2. Helper names describe their reusable behavior, not the first target that
   consumed them.
3. Case normalization is selected from the execution filesystem. A target-OS
   select must not stand in for that fact.
4. The MSVC construction tool map omits `generate_def_file`. The complete map
   adds exactly the constructed COFF DEF parser.
5. No marker feature, new build setting, or silent export suppression is used
   to escape the tool-map cycle.
6. Native Windows ThinLTO uses clang-cl, llvm-ar, and lld-link from the
   registered LLVM toolchain. It does not use ambient Visual Studio/SDK paths
   or Microsoft compiler/linker binaries.
7. The Linux RBE bootstrap FDO workload/profile topology, including
   `_LLVM_FDO_EXECUTORS`, remains unchanged.
8. Existing MinGW, Linux, macOS, Linux-to-Windows, static-libc++, CRT, SDK
   allowlist, and Clang resource-header behavior remain unchanged.

## Scope and non-goals

In scope:

- focused tests for the case-insensitive filesystem helpers and COFF DEF
  parser;
- generic package, target, namespace, and mnemonic names for those tools;
- portable-C implementations built with the existing hosted-C constructor;
- minimal construction/complete MSVC tool-map factoring;
- direct validated Microsoft SDK payload use on supported case-insensitive
  Windows executors, while case-sensitive executors retain normalization;
- native x86-64 and ARM64 Windows consumer proof, including ThinLTO.

Out of scope:

- native-Windows bootstrap FDO profile generation, merge, or application;
- a full native-Windows Stage 2 or Stage 3 LLVM release build;
- changing the existing Linux RBE production matrix or
  `_LLVM_FDO_EXECUTORS`;
- enabling public consumer FDO, sanitizers, modules, shared libc++, Microsoft
  STL, or any other currently unsupported feature;
- LLVM source changes, rules_cc upstream work, release publication, or a new
  package format;
- broad Unicode/path-policy changes hidden inside the C ports.

## Acceptance criteria

Step 13 is complete only when all of the following are demonstrated:

- every helper builds as C through `cc_runtime_stage1_hosted_binary` with no
  configured libc++/libc++abi or complete-C++-runtime dependency;
- existing and newly added focused tests cover the helper contracts and pass
  before and after the C ports, with differential evidence where practical;
- the construction tool map does not contain `generate_def_file` and does not
  configure the parser; the complete map contains exactly one parser mapping;
- a representative DLL/export action uses the complete map and invokes the
  parser successfully;
- case-sensitive Linux execution retains declared VFS/copy actions, while
  matching Windows execution consumes only the validated raw SDK payload and
  contains no case-normalization helper/action;
- representative native Windows `/MD`, release `/MT`, static archive, DLL plus
  import library, and executable builds succeed for x86-64 and ARM64;
- a representative `--features=thin_lto` Windows consumer succeeds for both
  architectures, its matching-architecture executable runs, and action
  inspection proves the clang-cl/COFF ThinLTO protocol;
- the existing Linux RBE Windows MSVC Stage 3 ThinLTO/FDO release build remains
  successful without FDO graph changes;
- focused MinGW and generic action comparisons show no semantic change.

Do not require a native single-machine FDO loop or a native full LLVM Stage 3
build to close this plan.

## Implementation order

Use one owner at a time. Group focused tests and defer heavyweight proof until
the graph is complete.

### Batch 1 — Freeze helper behavior with focused tests

Add tests against the current implementations before changing language or
package names.

Case-insensitive helpers:

- retain the existing VFS and copy behavior tests;
- add stable output ordering independent of directory creation order;
- cover nested and empty directories, lowercase-preferred aliases, ambiguous
  case collisions, transformed symlinks, and the existing unsupported-entry
  policy;
- cover path separator normalization and JSON/YAML escaping for the VFS
  output;
- assert copied file content, lowercase basename behavior, and repeatability;
- add CLI failures for missing, malformed, and unknown arguments.

COFF DEF parser:

- add direct unit/golden coverage instead of relying only on a generated-DLL
  integration action;
- construct small in-memory or checked-in documented fixtures for normal COFF
  and bigobj inputs, avoiding a dependency on the parser's selected toolchain;
- cover x86 underscore handling, ARM, ARMNT, AMD64, native ARM64, ARM64EC,
  data symbols, stable sorting, existing `.def` content, and response-file
  input lists;
- retain current exclusions such as explicitly exported symbols and deleting
  destructors where the existing implementation defines them;
- cover malformed/truncated objects and malformed response files with exact
  nonzero/error behavior;
- retain one black-box DLL/import-library test through rules_cc.

These tests define compatibility. Do not expand the helper policy during the
ports.

### Batch 2 — Give the helpers capability-based names

Rename without semantic change:

- `tools/windows_case` -> `tools/case_insensitive_filesystem`;
- `tools/windows_case_vfs` -> `tools/case_insensitive_vfs`;
- `tools/windows_case_copy` -> `tools/case_insensitive_copy`;
- `tools/msvc_def_parser` -> `tools/coff_def_parser`.

Rename corresponding libraries, tests, C/C++ namespaces or prefixes, private
tool labels, and action mnemonics. Prefer `CaseInsensitiveVFS`,
`CaseInsensitiveCopy`, and `CoffDefParser` over Windows/MSVC names.

Before deciding on aliases, query all label consumers. Do not preserve aliases
for unpublished private labels with no external consumer. Keep the public
rules `case_insensitive_vfs_overlay` and `case_insensitive_copy_directory`
unless their contracts require a separate reviewed change.

Run only the focused helper tests after this mechanical batch.

### Batch 3 — Port the helpers to portable C

Port the renamed case-insensitive filesystem helpers and COFF DEF parser to C.
Preserve CLI, output bytes, ordering, errors, collision policy, response-file
handling, COFF classification, and copyright notices. Correct the parser's
provenance to upstream Bazel's current parser revision
`56d21d61f551e5a48f56771c1748ed05751f58aa`; the currently cited
`df9cf21c8bf643f374790b0c2bc75686293b7024` is a repository-local portability
commit and is not present in upstream Bazel.

One approved semantic correction is part of the parser port. Bazel intends to
exclude the managed short symbols `__t2m`, `__m2mep`, and `__mep`, but its
fixed-width short-name construction retains trailing NUL bytes and defeats the
comparisons. Batch 1 records `__t2m` as the fail-before result. The C port must
use the bounded real short-name length, exclude all three, and flip/add the
corresponding regression expectations.

Build each binary with `cc_runtime_stage1_hosted_binary`. Its configured graph
may contain compiler primitives, target C headers, and target CRT inputs; it
must not contain the C++ runtime, C++ headers, or C++ auto-link inputs.

Where practical, compare old and new executable output over the Batch 1 corpus
before deleting the C++ sources. Any path, locale, Unicode, or symbol
classification mismatch is a stop condition requiring an explicit decision.

Run all focused helper/parser tests once after the ports, not a full Stage 3
build per helper.

### Batch 4 — Split construction and complete MSVC tool maps

Make the smallest graph change in both installed/prebuilt and source-backed
toolchain declarations:

```text
MSVC_CONSTRUCTION_TOOLS
  = existing required compile/archive/link tools
  - generate_def_file

MSVC_COMPLETE_TOOLS
  = MSVC_CONSTRUCTION_TOOLS
  + { generate_def_file: //tools/coff_def_parser }
  + existing complete-only validation inputs
```

Use the construction map for hosted construction tools, including the parser.
Use the complete map for ordinary consumer and runtime actions.

Do not attempt to solve this by disabling a feature on the parser target. A
feature affects the actions requested for that target; it does not remove an
eager label from `cc_tool_map.tools`. The parser already does not request the
export-all-symbols feature during its ordinary executable link.

The map declaration change should otherwise remain small: factor the existing
dictionary, remove one mapping from the construction variant, and add it back
to the complete variant. An accidental DLL/export action under the
construction map must fail for lack of the action tool rather than silently
omit exports.

Graph tests must prove:

- the construction map has no `generate_def_file` label;
- the complete map has exactly the COFF parser mapping;
- the configured parser target has no self-edge;
- a representative complete-toolchain DLL action invokes the parser.

### Batch 5 — Select SDK case handling from the execution filesystem

Keep case normalization for supported case-sensitive execution platforms.
For supported matching Windows executors, use the same validated, curated raw
VC/UCRT/SDK payload directories directly and omit VFS/copy actions.

Use the toolchain instance's declared execution OS/filesystem capability. Do
not select this behavior from the Windows target platform. If OS alone cannot
truthfully express the supported filesystem contract, stop and introduce one
explicit execution-platform capability rather than infer it from target ABI.

Preserve:

- Layer 1 validation and current Microsoft header/library allowlists;
- libc++ headers -> Clang resource headers -> VC/UCRT header ordering for C++
  consumers;
- Clang resource headers -> VC/UCRT ordering for hosted-C helpers;
- SDK/runtime library ordering and absence of ambient paths;
- the normalized Linux RBE view and stable helper outputs.

Focused aquery/cquery proof is sufficient for this batch. Do not run full
Stage 3 until all graph changes are complete.

### Batch 6 — Prove native consumers and ThinLTO

Reuse the existing native Windows consumer lanes. Do not add a separate FDO
lane.

For matching Windows x86-64 and ARM64 executors:

1. register the exact unpublished MSVC prebuilt archive used by the existing
   consumer proof;
2. build and run the existing ordinary `/MD` executable;
3. build and run a release `/MT` executable;
4. build a static archive and a DLL with generated DEF/import library, then
   run a matching executable that consumes each relevant output;
5. build a small representative program with `--features=thin_lto`, run the
   matching-architecture executable, and inspect its full action graph.

ThinLTO evidence must show:

- `clang-cl.exe` compile actions emit target bitcode objects;
- the declared `lld-link.exe` performs COFF ThinLTO indexing/final linking;
- backend actions use the correct target triple and `.obj` outputs;
- static archives use declared `llvm-ar.exe` and deterministic `rcsD` ordering;
- final links use `/MACHINE`, `/OUT` or the proved driver equivalent,
  `/WHOLEARCHIVE` where requested, `.lib` inputs, and declared SDK/CRT paths;
- parameter files use the established Windows protocol and encoding;
- no Linux executable, ambient Visual Studio path, host CPU, GNU-only linker
  token, or ignored required option leaks into native actions;
- x86-64 output is AMD64 PE/COFF and ARM64 output is native ARM64, not ARM64EC.

Then run the existing Linux RBE Windows MSVC Stage 3 release/archive proof once
for both target architectures. Its ThinLTO/FDO profile actions and
`_LLVM_FDO_EXECUTORS` must be unchanged. This is a regression gate, not a
native FDO implementation task.

Run focused MinGW and representative generic action tests in proportion to the
actual changed labels. Avoid adding permanent development-only CI lanes; fold
the final native ThinLTO check into the existing Windows MSVC consumer matrix.

## Failure classification and stop conditions

Classify every failure before editing:

- helper implementation or compatibility contract;
- toolchain graph/tool-map ownership;
- execution-filesystem SDK representation;
- clang-cl/COFF ThinLTO action protocol;
- declared compiler/SDK/CRT input;
- rules_cc limitation;
- remote/native runner infrastructure or resource exhaustion.

Fix one owning layer and repeat the identical reproduction. Stop before:

- changing helper output or error semantics without owner approval;
- changing LLVM source semantics or opening an LLVM/rules_cc upstream PR;
- weakening SDK validation, using ambient Visual Studio/SDK paths, or exposing
  Microsoft STL;
- silently suppressing DEF generation or export behavior;
- redesigning product FDO or adding native FDO work;
- changing MinGW or another platform to accommodate an MSVC-only defect;
- publishing, registering publicly, merging, or starting post-publication
  cleanup.

If rules_cc cannot express the minimal construction/complete map or native
ThinLTO protocol, first prove the smallest downstream correction end to end.
Prepare upstream work only after separate authorization.

## Commit and delivery boundaries

Prefer these reviewable commits, combining only when a rename and port cannot
be reviewed meaningfully apart:

1. add focused compatibility tests;
2. rename helpers generically;
3. port case-insensitive helpers to hosted C;
4. port the COFF DEF parser and split construction/complete tool maps;
5. select SDK representation from execution filesystem behavior;
6. add the native ThinLTO consumer proof and final documentation/CI cleanup.

Do not run the heavyweight native and Linux RBE proofs after every commit.
Run focused tests per owning batch, then run the complete acceptance matrix
once after the graph is coherent.

Every handoff records the branch, absolute checkout, commit SHAs, exact Bazel
commands, invocation IDs, configured exec/target platforms, inspected action
and artifact evidence, intentional differences, and all remaining unknowns.
Separate demonstrated facts from inference.

## Completion gate

This plan is complete when portable hosted-C helpers and the two-level MSVC
tool map remove the construction cycles, case handling follows the execution
filesystem, matching native Windows consumers pass ordinary and ThinLTO
compile/archive/link/run proof for both architectures, and the existing Linux
RBE ThinLTO/FDO release graph remains unchanged and green.

Until then, no Windows MSVC implementation from the parent plan may merge and
no Windows MSVC prebuilt toolchain may be published.
