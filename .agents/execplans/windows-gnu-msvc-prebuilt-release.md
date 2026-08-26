# Windows GNU/MSVC LLVM prebuilt release and rollout plan

Status: proposed. This plan defines how to split draft PR #711 into sequential,
truthful integration boundaries, publish both GNU/MinGW-built and MSVC-built
Windows LLVM compiler archives, and then enable the MSVC-built archives as the
default Windows execution toolchain without removing the GNU-built archives.

Date: 2026-08-26 (Asia/Tokyo)

This plan succeeds `windows-msvc-prebuilt-llvm.md` for merge, release, public
index, and execution-toolchain rollout. It does not replace that plan's
source-bootstrap, ThinLTO, FDO, archive, or artifact evidence. Native Windows
execution details remain owned by `windows-msvc-native-execution.md`.

## Progress

- [x] Reconcile the predecessor plan status with final PR #711 CI run
  `32878927638` at `e017919577791226553b4377f9acd399b2ea6bee`, including the
  completed native x86-64 and ARM64 Batch 6 evidence. The predecessor and
  canonical native-execution plans now record the combined branch as proved
  while keeping delivery governed by this successor plan.
- [ ] PR 1: extract and merge truthful Windows MSVC target support.
- [ ] PR 2: extract and merge the dual GNU/MSVC Windows prebuilt producer.
- [ ] Release: publish one new immutable LLVM prebuilt release containing both
  Windows compiler-runtime families for both CPUs.
- [ ] PR 3: add public archive selection, make MSVC the default Windows
  execution compiler, preserve GNU opt-in, and merge native execution proof.
- [ ] Remove superseded development-only CI and temporary local-registration
  plumbing after the public index path proves the same behavior.

No checkbox authorizes a push, PR mutation, merge, release, index update, or
publication by itself. Each action requires the owner's normal explicit
authorization.

## Objective

Deliver Windows MSVC support in three sequential implementation PRs plus one
release operation:

1. compile **to** the Windows MSVC ABI from explicitly supported execution
   hosts;
2. build and package both GNU/MinGW-built and MSVC-built Windows LLVM compiler
   archives;
3. publish both archive families without selecting the new MSVC family yet;
4. make the published MSVC-built archive the default Windows execution
   compiler while retaining an explicit GNU-built fallback.

The final release contains four Windows compiler archives:

| Execution compiler build ABI | x86-64 asset key | ARM64 asset key |
|---|---|---|
| Existing GNU/MinGW build | `windows-amd64` | `windows-arm64` |
| New MSVC build | `windows-amd64-msvc` | `windows-arm64-msvc` |

These are separate archives. Do not combine the GNU-built and MSVC-built
payloads into one archive: both provide the same `bin/llvm.exe` multicall
binary and aliases, so a combined layout would collide and obscure which
runtime ABI the execution tools use.

## Starting state and demonstrated evidence

Draft hermetic-llvm PR #711 currently combines target support, source
bootstrap, optimized package production, unpublished archive registration,
and native execution in 105 commits and 105 changed files. Its final CI run
`32878927638` passed all 42 jobs at
`e017919577791226553b4377f9acd399b2ea6bee`.

That combined state demonstrates:

- Windows x86-64 and ARM64 MSVC targets compile, archive, link, and execute
  with clang-cl, llvm-ar, lld-link, static libc++, UCRT, and the selected MSVC
  CRT mode;
- full Linux-RBE-backed ThinLTO/FDO Stage 3 packages build for both MSVC target
  CPUs under `--config=release`;
- the resulting release compilers use `/MT`, are self-contained with respect
  to the MSVC redistributable, and inspect as AMD64 or native ARM64 rather than
  ARM64EC;
- matching native Windows runners consume the unpublished MSVC-built archives
  and pass `/MD`, DLL, ThinLTO, and `/MT` behavior tests;
- the existing MinGW, Linux, macOS, source-version analysis, public docs, and
  Bazel test lanes remain green.

The current published LLVM release has only the existing unsuffixed Windows
assets:

- `llvm-toolchain-minimal-<version>-windows-amd64.tar.zst`;
- `llvm-toolchain-minimal-<version>-windows-arm64.tar.zst`.

The current module extension maps those keys to the version-neutral
repositories `llvm-toolchain-minimal-windows-amd64` and
`llvm-toolchain-minimal-windows-arm64`. The release script packages
`windows_llvm_release` for those assets. The public index has no compiler-build
ABI axis yet.

## Terminology and ownership axes

Keep these concerns independent throughout the split:

- **target OS/ABI**: the produced program is Windows PE/COFF using either the
  GNU/MinGW ABI or the native MSVC ABI;
- **target CRT/C++ runtime**: MinGW runtime versus UCRT/VCRuntime, `/MD` versus
  `/MT`, and the selected C++ standard library;
- **compiler personality**: Clang GNU-driver grammar versus clang-cl grammar;
- **execution OS/CPU**: where clang, clang-cl, llvm-ar, and lld-link run;
- **execution compiler build ABI**: whether the Windows `llvm.exe` binary was
  itself linked as a GNU/MinGW or MSVC release product;
- **product configuration**: source bootstrap, ThinLTO, FDO, and release CRT
  policy used to construct an official compiler archive.

The execution compiler build ABI does not determine the target ABI. Both
Windows compiler archive families must remain capable of producing MinGW and
MSVC target programs. Do not duplicate target platforms, target toolchain
semantics, SDK definitions, or compiler-personality packages merely because
two execution compiler archives exist.

The Microsoft SDK and VCRuntime payloads remain separately declared,
EULA-gated dependencies. They are not copied into either minimal LLVM archive.
The existing `prebuilts-extras` GNU runtime archives remain target-runtime
inputs and are not renamed or treated as compiler archives by this plan.

## Architectural decisions

1. **Preserve existing GNU asset names.** Existing
   `windows-amd64`/`windows-arm64` release URLs remain valid and retain their
   GNU/MinGW-built meaning. Do not silently replace historical assets or
   require downstream URL migration.
2. **Add explicit MSVC asset names.** New immutable release assets use
   `windows-amd64-msvc` and `windows-arm64-msvc`.
3. **Select one Windows execution compiler family per module graph.** Both
   families implement the same Windows execution OS/CPU capability. Do not
   register indistinguishable `cc_toolchain` instances with identical
   constraints and rely on ambiguous toolchain resolution.
4. **Keep version-neutral repository names.** The selected family continues to
   populate `llvm-toolchain-minimal-windows-amd64` and
   `llvm-toolchain-minimal-windows-arm64`, avoiding a repository-name cascade
   through tool maps and BUILD overlays.
5. **Add an explicit module-extension policy axis.** The extension exposes a
   validated `windows_exec_abi` choice with `gnu` and `msvc` values. Root
   module intent overrides the default. Unknown values fail during extension
   evaluation with a specific error.
6. **Cut over deliberately.** Before PR 3, the default remains the existing
   GNU archive. PR 3 changes the default to `msvc` only after published URLs,
   hashes, native execution, MinGW-target regression, and GNU fallback are all
   proved. `windows_exec_abi = "gnu"` remains supported.
7. **No simultaneous dual registration initially.** A downstream graph that
   genuinely needs both compiler build ABIs at once is outside the first
   rollout. Add distinct repositories and an execution constraint only after
   a real consumer demonstrates that requirement.
8. **Sequential PRs, not an unmerged stack.** PR 2 starts from merged PR 1;
   the release starts from merged PR 2; PR 3 starts from merged PR 2 plus the
   immutable published artifact metadata. Each intermediate main-branch state
   must be truthful and independently green.

The exact Starlark tag-class spelling may change during review, but its public
semantics must remain one explicit GNU/MSVC execution-archive choice. Do not
smuggle this choice through target ABI constraints, compiler personality,
`--platforms`, or an ambient environment variable.

## Dependency order

```text
PR 1: Windows MSVC target support
  - target ABI/runtime/compiler semantics
  - no new release artifact or public index selection
  - native Windows -> MSVC target route withheld until PR 3
                    |
                    v
PR 2: dual Windows prebuilt producer
  - existing GNU packages unchanged
  - new MSVC Stage 3 packages
  - release workflow emits both families
  - public index still selects existing GNU family
                    |
                    v
Release operation
  - immutable GNU + MSVC assets for both CPUs
  - SHA256.txt + provenance attestation
  - no public index cutover
                    |
                    v
PR 3: Windows execution-toolchain selection and cutover
  - index contains both families
  - explicit windows_exec_abi selector
  - MSVC becomes default; GNU remains opt-in
  - native Windows x64/ARM64 consumer and ThinLTO proof
```

## PR 1 — Add truthful Windows MSVC target support

### Contract

PR 1 makes the MSVC ABI a supported **target**. It must not depend on an
unpublished MSVC-built compiler archive and must not imply that every currently
declared Windows execution platform can already construct the MSVC target
graph.

### Include

- MSVC ABI, CRT, UCRT, and platform constraints for x86-64 and ARM64;
- clang-cl compiler-personality action grammar and COFF/lld-link protocol;
- target-aware VC/UCRT inputs, static libc++, COM support, default libraries,
  deterministic archives, artifact suffixes, DLL/import-library behavior, and
  `/MD`/`/MT` selection;
- the approved toolchain semantic cleanup needed to keep OS, target ABI,
  runtime, and compiler personality separate;
- upstream-quality LLVM overlay fixes required by target-library semantics,
  with already-merged upstream patches referenced and remaining downstream
  patches isolated by owner;
- existing negative boundaries for unsupported modules, sanitizers, coverage,
  Microsoft STL, shared libc++, public FDO, and other ungraduated features.

### Exclude

- Stage 1/2/3 prebuilt construction and package labels that are not required by
  the target toolchain itself;
- release script, release workflow, public prebuilt index, SHA, or URL edits;
- switching the Windows execution compiler archive;
- native Windows full consumer claims owned by PR 3.

### Truthful execution boundary

The current toolchain generator enumerates Windows execution platforms. A
split PR must not accidentally register a known-broken Windows-exec-to-MSVC
target route. Until PR 3 lands, explicitly limit MSVC target toolchain
registration to the execution hosts proved by PR 1, while preserving all
existing MinGW toolchains on Windows.

Prefer a named supported-exec set or capability predicate over a scattered
one-off condition. PR 3 expands that set after portable construction helpers,
execution-filesystem SDK selection, and native proof land. Do not claim native
support merely because the archive executable starts on Windows.

### Required proof

- full representative x86-64 and ARM64 MSVC target builds on the supported
  Linux RBE execution platforms;
- compile/archive/link action inspection for clang-cl, llvm-ar `rcsD`,
  lld-link, triples, `/MACHINE`, `.obj`/`.lib`, libc++ and SDK/runtime inputs;
- PE machine and import inspection for both target CPUs;
- existing MinGW target action and runtime tests unchanged;
- Linux/macOS/generic argument comparisons proportional to touched semantics;
- action/analysis tests, buildifier, public Starlark docs, Gazelle diff, and
  the normal repository CI matrix;
- a negative query proving the withheld native Windows MSVC route is not
  accidentally selectable before PR 3.

### Merge gate

PR 1 is mergeable only when it is independently green and its target/exec
matrix is truthful without any unpublished archive or later PR.

## PR 2 — Produce both GNU- and MSVC-built Windows prebuilts

### Contract

PR 2 adds the source-bootstrap and release-product machinery needed to produce
official MSVC-built compiler archives while preserving the existing GNU-built
Windows compiler archives byte-for-byte or with only independently justified
release changes.

### Include

- the proved Stage 1 -> instrumented Stage 2 -> merged profile -> ThinLTO/FDO
  Stage 3 MSVC product topology;
- minimized ThinLTO summaries for indexing and complete bitcode objects for
  backends;
- x86-64 and ARM64 MSVC Stage 3 package labels;
- static `/MT` release-compiler policy while ordinary target consumers retain
  `/MD` by default;
- deterministic archives, manifests, multicall aliases, builtin headers,
  ignorelists, and PE/import/debug inspection;
- the existing GNU `windows_llvm_release` products unchanged;
- release-script changes that explicitly build and locate all four Windows
  package labels rather than relying on `//prebuilt/llvm:all` to include
  manual MSVC labels;
- two additional release outputs:
  `llvm-toolchain-minimal-<version>-windows-amd64-msvc.tar.zst` and
  `llvm-toolchain-minimal-<version>-windows-arm64-msvc.tar.zst`.

### Exclude

- public index entries for the new MSVC assets;
- changing the module-extension default or selected Windows repositories;
- native Windows execution-toolchain registration;
- release publication itself.

### Required proof

- one Linux-RBE-backed release build produces the existing Linux, macOS, GNU
  Windows, and both new MSVC Windows archives;
- GNU Windows package cquery/aquery and manifests remain semantically
  unchanged;
- MSVC x86-64 and ARM64 packages contain the expected layout, real
  `llvm.exe`, aliases, builtin headers, fixed metadata, and no unexpected
  `.dll`, `.lib`, `.pdb`, host path, or Microsoft payload;
- GNU compiler executables retain their expected machine/import behavior;
- MSVC compiler executables are AMD64/native ARM64, not ARM64EC, select `/MT`,
  and do not import `MSVCP*` or `VCRUNTIME*` redistributable DLLs;
- SHA256 generation and attestation subject globs cover all archive families;
- a release dry-run artifact bundle contains eight minimal compiler archives:
  two Linux, two macOS, two GNU Windows, and two MSVC Windows;
- PR 1 target support remains green with the still-selected GNU execution
  archives.

### Merge gate

PR 2 is mergeable when the dual producer is green but the published index is
unchanged. Merging it must not alter what any existing consumer downloads.

## Release operation — Publish both Windows families

### Preconditions

- PR 1 and PR 2 are merged;
- the exact release branch is based on merged PR 2;
- the branch name and `LLVM_VERSION` satisfy the existing
  `llvm-<version>-<suffix>` release contract;
- no asset with the planned names already exists at the new immutable tag;
- the default LLVM source line's four Windows archives have passed PR 2 proof.

### Operation

Run the existing `LLVM Prebuilt Release` workflow from a new release branch.
Do not overwrite an existing release or mutate historical GNU assets. The
release must publish:

- the existing Linux and macOS archives;
- GNU `windows-amd64` and `windows-arm64` archives;
- MSVC `windows-amd64-msvc` and `windows-arm64-msvc` archives;
- one `SHA256.txt` covering every archive;
- the normalized provenance attestation bundle covering every archive and the
  checksum manifest.

### Required proof

- workflow and every build/package/attestation/upload step succeed;
- GitHub release assets exactly match the expected filenames and count;
- downloaded archive hashes match `SHA256.txt`;
- attestation verification covers each of the four Windows assets;
- selective extraction repeats machine/import/layout checks for both CPUs and
  both compiler-build ABIs;
- the public prebuilt index remains unchanged and normal consumers still
  resolve the preceding selected release until PR 3.

Publishing the assets is not the execution-toolchain cutover.

## PR 3 — Select and prove the MSVC-built Windows execution toolchain

### Contract

PR 3 makes the already-published MSVC-built archives the default Windows
execution compiler. It preserves the published GNU-built archives as an
explicit fallback and proves that target ABI remains independent of execution
compiler build ABI.

### Include

- public index entries for `windows-amd64-msvc` and
  `windows-arm64-msvc` using the immutable release URLs and SHA-256 values;
- a validated module-extension `windows_exec_abi` policy with `gnu` and
  `msvc` values;
- selection of the appropriate release key while retaining the existing
  version-neutral repository names and Windows BUILD overlay;
- `msvc` as the default only in this cutover PR; explicit `gnu` opt-in remains
  supported;
- expansion of the MSVC target supported-exec set to native Windows x86-64
  and ARM64;
- portable hosted-C construction helpers, construction/complete COFF tool
  maps, and execution-filesystem-aware SDK representation from
  `windows-msvc-native-execution.md`;
- native Windows consumer/action proof using the published archives, replacing
  temporary `file://` registration and workflow-artifact plumbing;
- existing native MinGW target rows, now proving that the default MSVC-built
  execution compiler still produces and executes MinGW programs correctly.

### CI shape

Do not create a permanent duplicate full matrix for every execution-archive
and target-ABI cross-product.

| Windows execution archive | MinGW target | MSVC target |
|---|---|---|
| Default MSVC-built archive | Existing native behavior suite | Full `/MD`, DLL, ThinLTO, `/MT` suite |
| Explicit GNU-built fallback | Focused native smoke | Focused native smoke |

For each Windows CPU, one primary native row should:

1. select the published default MSVC-built compiler archive;
2. inspect and execute its clang-cl personality;
3. build/run representative MSVC `/MD`, DLL, ThinLTO, and `/MT` targets;
4. build/run the existing MinGW target behavior with the same compiler
   archive;
5. inspect target tools, triples, machine types, response files, SDK/runtime
   closure, and absence of source-built or ambient fallback.

Within the same architecture job, a focused second module/output base may set
`windows_exec_abi = "gnu"` and prove repository selection plus one MinGW-target
smoke and one MSVC-target smoke. This closes the execution-compiler/target-ABI
cross-product without another heavy CI lane. Keep the two existing CPU lanes
and remove superseded development-only producer/host-analysis duplicates after
the public path passes.

### Required proof

- the public index selects exact published URLs/hashes, not CI artifacts or
  local files;
- default x86-64 and ARM64 Windows repositories contain the MSVC-built
  compiler with the expected PE machine and no undeclared redistributable DLL
  dependency;
- native MSVC target compile/archive/link/ThinLTO actions use clang-cl,
  llvm-ar, and lld-link from those repositories;
- `/MD`, DLL, ThinLTO, and `/MT` binaries execute successfully on matching
  Windows runners;
- MinGW targets compile and execute under the default MSVC-built compiler;
- explicit GNU execution-archive selection resolves the published GNU asset
  and passes focused MinGW- and MSVC-target smokes;
- no toolchain ambiguity exists and repository names remain stable;
- Linux RBE Stage 3 ThinLTO/FDO construction is unchanged;
- all repository CI is green with no temporary registration helper or
  unpublished archive transfer remaining on the consumer path.

### Merge gate

PR 3 is the public execution-toolchain cutover. It may merge only after the
release assets are immutable and all default/fallback plus MinGW/MSVC target
combinations required above pass.

## LLVM source-version scope

Do not infer support for an unbuilt release line from analysis-only or focused
consumer success.

For the first rollout, the exact published LLVM version must build all four
Windows compiler archives. The current complete default-line evidence is LLVM
22.1.8. Existing LLVM 21 direct Stage 3 and LLVM 23 analysis/source-consumer
evidence remain useful compatibility signals but do not equal a published
dual-family package build.

The six-cell full-package matrix proposed as Step 12 of
`windows-msvc-prebuilt-llvm.md` is not required to merge PR 1. Before claiming
that LLVM 21, 22, and 23 all have production dual-family Windows prebuilts,
run the full package workflow for each claimed release line and both target
CPUs. A release line becomes supported when its own immutable release run and
archive inspection pass; do not advertise future lines preemptively.

## Failure classification and stop conditions

Classify every failure before editing:

- target toolchain semantics or compiler personality;
- target CRT/C++ runtime or declared SDK input;
- source bootstrap, ThinLTO, FDO, or LLVM overlay;
- package/archive/release workflow;
- module-extension index or execution-archive selection;
- native execution helper/tool-map/SDK representation;
- remote infrastructure or resource exhaustion.

Stop for owner review before:

- changing historical release assets or removing the existing GNU archives;
- combining GNU and MSVC compilers into one colliding archive layout;
- making compiler build ABI a target ABI or compiler-personality constraint;
- adding simultaneous identical toolchains and accepting ambiguous resolution;
- changing public repository names without a proved consumer conflict;
- copying Microsoft SDK/VCRuntime payloads into release archives;
- changing generic Linux/macOS/MinGW release topology or effective semantics;
- broadening LLVM source semantics, public consumer FDO, shared libc++,
  Microsoft STL, sanitizers, modules, or other unsupported features;
- replacing Linux-RBE-backed bootstrap FDO with native Windows construction;
- publishing, updating the public index, changing a PR state, or merging
  without separate authorization.

## Delivery and cleanup

- Treat PR #711 as the proved source inventory, not as a mergeable unit.
- Create each PR from its merged predecessor; do not squash unrelated owners
  into one commit and do not preserve obsolete workaround commits merely to
  retain chronology.
- Keep source/overlay, target semantics, producer/release, and public selection
  commits separately reviewable.
- Record exact CI run IDs, BuildBuddy invocation IDs, release tag, asset URLs,
  archive hashes, PE/import evidence, and intentional differences.
- Remove generated local indexes, release scratch directories, downloaded
  archives, response files, and ephemeral LLVM-version edits before commit.
- Do not commit EULA acceptance values, Microsoft payloads, credentials, or
  ambient Visual Studio/SDK paths.
- Update predecessor plan progress and close only the checkboxes proved by the
  extracted PR/release state, not by the current combined branch alone.

## Known unknowns

- Whether the module-extension selector should be a dedicated tag class or an
  attribute on a broader configuration tag. The semantic contract is fixed;
  choose the smallest public API during PR 3 review.
- Whether any downstream consumer needs both Windows execution compiler ABIs
  simultaneously in one module graph. No current evidence requires it.
- Whether the first dual-family release should be a new revision of LLVM
  22.1.8 or the next LLVM source release. Decide before creating the release
  branch; never overwrite `llvm-22.1.8-1`.
- Which deferred semantic-cleanup items remain prerequisites for PR 1 versus
  explicitly documented follow-ups. R11/R42 and the release-policy naming
  checkpoint are not silently completed by this rollout.
- Whether the explicit GNU fallback requires a permanent runtime test on both
  CPUs after one transition release. Begin with the focused same-lane proof;
  retain heavier coverage only if it catches a distinct supported risk.

## Completion boundary

This rollout is complete when:

- the target-support PR is merged and truthfully compiles to the MSVC ABI from
  every execution host it advertises;
- the producer PR is merged and the release workflow builds both GNU and MSVC
  Windows compiler archives for x86-64 and ARM64;
- one immutable release publishes all four Windows assets with checksums and
  provenance;
- the execution-toolchain PR is merged, MSVC is the default Windows compiler
  archive, GNU remains explicitly selectable, and both target ABIs work;
- matching Windows x86-64 and ARM64 native consumer/ThinLTO checks and the
  entire repository CI are green;
- no local archive, temporary index, development-only CI lane, or unpublished
  selection path remains.

Native Windows Stage 2/3 release construction and FDO profile generation,
Microsoft compiler executables, Microsoft STL, shared libc++, and unrelated
feature graduation remain outside this rollout.
