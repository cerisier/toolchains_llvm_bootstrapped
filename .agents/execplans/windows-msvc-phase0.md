# Windows MSVC Phase 0 decision ledger

Status: decisions frozen; native six-host closeout pending. No Layer 1 implementation.

Date: 2026-08-18 (Asia/Tokyo)

Base: `d2f5dd0f33aae9f52d34ba631540285b2d09b368` (`origin/main`, PR 709)

Branch: `cerisier/windows-msvc-phase0`

Worktree: `/Users/corentinkerisit/code/github.com/hermeticbuild/hermetic-llvm-msvc-phase0`

## Evidence vocabulary

- **Fact**: directly observed source, command, action graph, or artifact.
- **Inference**: conclusion from facts that has not itself been executed end to end.
- **Decision**: approved contract for an owning implementation layer.
- **Candidate**: a Layer 3 cell that may become public only after its named proof.
- **Reject**: a stable analysis error, never a silent no-op.

## Authority and scope

Fact: the owner approved the Section 9 stack plan, updating to current GitHub
`main`, prescribed branches/worktrees, commits, pushes, and draft stacked PRs.
The owner separately answered `I authorize everything` after the Phase 0
public-platform, EULA, redistribution, CI-environment, CRT, and unsupported-cell
decisions were enumerated. The owner also required that no Python introduced by
this work remain after transient testing.

Decision: that second response approves the enumerated Phase 0 semantics and
EULA use. It does not authorize publishing Microsoft payloads, adding secrets,
or editing README files. Phase 0 introduces only Go probe/assertion tools.

## Baseline and artifact evidence

### Existing default route

Command:

```sh
cd e2e/rules_cc
bazel build --config=remote //:main
```

Fact: passed; invocation `20944365-eb36-48b4-9d3b-3a12bee3231e`; 1,187
actions; output `bazel-bin/main`; elapsed 15.423 s.

Command:

```sh
bazel aquery --config=remote //:main --output=jsonproto \
  > /tmp/msvc-plan-baseline-aquery.json
```

Fact: passed; invocation `11e6601d-6dd8-4de9-8b59-92909a0001d3`;
19,692 bytes; SHA-256
`cdeba15e7ddf3d30b8c26150a5a023804ff4887eadf37ee897c216b0b89dad0c`.
This initial capture predated the later `--include_param_files` review fix.
The target default was macOS ARM64 while the action executed on Linux ARM64
RBE. The output was Mach-O ARM64.

### Existing explicit Windows GNU route

Command:

```sh
bazel build --config=remote \
  --platforms=@llvm//platforms:windows_x86_64 \
  //:main_default //:windows_explicit_def.dll //:comm_symbol_static_lib
```

Fact: build passed; invocation `6209ad8f-43c6-45f6-8322-61f10b827df6`;
2,291 actions. A chained follow-on `cquery` used invalid multi-target syntax and
returned 2. That syntax failure does not invalidate the preceding build.

Final response-file-aware command (the initial command omitted
`--include_param_files`):

```sh
bazel aquery --config=remote --include_param_files \
  --platforms=@llvm//platforms:windows_x86_64 \
  //:main_default --output=jsonproto \
  > /tmp/msvc-plan-baseline-windows-x86_64-aquery.json
```

Fact: the initial no-param-file capture passed at invocation
`0532fb44-f49a-46cb-a2ac-e63bbdb4a816` (21,190 bytes, SHA-256
`e5850c505187ca1ebc393dc77afb6b7cc822921c3841ffe9c12dbc132aa1ce99`).
The final response-file-aware capture passed at invocation
`0f166c3c-3ca9-4c68-b1b0-882e35b0397f` (22,121 bytes, SHA-256
`bdd0434227b7fe182a165443905a058bbc88989806566b5222dd92ea4201957d`).
`CppCompile` used Linux ARM64 `clang++`, target
`x86_64-w64-windows-gnu`, GNU arguments, MinGW inputs, and Linux ARM64 RBE.

Fact: `main_default.exe` was PE32+ x86-64 console, subsystem/minimum OS 6.0,
and imported UCRT API-set plus `KERNEL32`. The explicit-DEF DLL was PE32+ x64,
exported `add42`, and its archive members/symbols matched the targets. Existing
baseline timestamps were current rather than deterministic.

### Assertion tool against a real action graph

The first real run failed:

```text
parse ...aquery.json: json: cannot unmarshal number into Go struct field
artifact.artifacts.id of type string
```

Fact: Bazel emits numeric action-graph identifiers; the original unit fixture
used quoted identifiers. The implementation now accepts both forms and has a
regression test.

Command:

```sh
bazel test --config=remote \
  --extra_execution_platforms=@platforms//host:host \
  --spawn_strategy=local --strategy=TestRunner=local \
  //tools/msvc_action_assert:test
bazel run --config=remote \
  --extra_execution_platforms=@platforms//host:host \
  --spawn_strategy=local //tools/msvc_action_assert -- \
  -aquery /tmp/msvc-plan-baseline-windows-x86_64-with-params-aquery.json \
  -spec /tmp/msvc-plan-baseline-spec.json
```

Fact: test passed, invocation `31b36cd7-5f75-41d3-892e-3c5ecde26ff0`;
real graph assertion passed, invocation
`33b66d88-3e89-4805-89cf-5269bea5a681`. An intermediate implementation
incorrectly treated every `paramFiles[]` entry as a response file even when
the action did not reference it; Bazel also reports generated module maps in
that field. The final assertion model expands only entries referenced by an
`@execPath` argv item, requires exact referenced-response-file count/path, and
rejects unknown/empty specs. The baseline therefore expects zero response
files while still retaining its unrelated `main_default.cppmap` metadata.
The corrected response-file-aware real graph passed at invocation
`78a703ee-0dfa-4ef7-b839-4c88b7bb9f33`.

## SDK, CRT, case, and direct-link evidence

Source under test: windows_support `v0.2.0`, commit
`058cdbb` in `/Users/corentinkerisit/code/github.com/hermeticbuild/windows_support`.

Command:

```sh
cd e2e/smoke
BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 bazel build //:smoke_test
```

Fact: passed on normal macOS APFS; invocation
`d01aee54-fd73-421a-892d-58679ae9da53`; elapsed 149.624 s.

Command, repeated on a temporary case-sensitive APFS volume:

```sh
BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1 \
  bazel --output_user_root=/tmp/msvc-case.V52d3w/mount/bazel-root \
  build //:smoke_test
```

Fact: passed; invocation `8adffd10-98c0-493d-a9a6-1cce1441035c`;
elapsed 66.244 s. A prior run was intentionally interrupted during the owner
pause; invocation `2aa596f9...` is not counted as a failure. The temporary disk
was detached after evidence collection (`"disk8" ejected`).

Facts on the case-sensitive repository:

- `DriverSpecs.h`, `SpecStrings.h`, and `Ole2.h` aliases resolved lowercase
  upstream spellings.
- `kernel32.lib` resolved upstream `kernel32.Lib`.
- exposed SDK roots were base, x64, and ARM64; exposed MSVC roots were include
  and per-architecture lib only.
- representative Windows/VCRuntime/UCRT/shared/UM/WinRT headers compiled for
  x86-64 and ARM64.
- both architecture objects had stable SHA-256 output and zero COFF
  timestamps.
- quiet reruns with `/clang:-Wno-everything` emitted no output.
- warnings-on runs emitted `-Wnonportable-include-path`: aliases make lookup
  work but do not rewrite the physical target spelling seen by diagnostics.

One early shell loop omitted `/Tc-`; its per-row text misleadingly said PASS
although clang-cl failed, and the command returned 1. The corrected probe used
real source files and explicit language selection. Only corrected results are
used for support decisions.

Facts from corrected CRT probes on x86-64 and ARM64:

- `/MD` emitted `/DEFAULTLIB:msvcrt.lib` and `/DEFAULTLIB:oldnames.lib`.
- `/MT` emitted `/DEFAULTLIB:libcmt.lib` and `/DEFAULTLIB:oldnames.lib`.
- a `malloc` link with only those directives failed unresolved; UCRT and
  VCRuntime are explicit closure inputs.
- `/MD /nodefaultlib` closure:
  `msvcrt.lib vcruntime.lib ucrt.lib kernel32.lib`; imports included
  `VCRUNTIME140.dll` and UCRT API-set.
- `/MT /nodefaultlib` closure:
  `libcmt.lib libvcruntime.lib libucrt.lib kernel32.lib`; only `KERNEL32`
  remained dynamically imported.
- all four architecture/CRT links repeated byte-identically under `/Brepro`.

Fact: direct clang-cl/lld-link DLL probes for both architectures generated a
DLL, `.if.lib`, and PDB; exported `add42`; import-library symbols were present;
PDB magic was `Microsoft C/C++ MSF 7.00`.

## Direct tool protocol evidence

Fact: local direct tools were clang-cl, llvm-ar, and lld-link 22.1.8.
clang-cl reported `arm64-pc-windows-msvc` by default on the ARM64 host.

Go test/probe results:

| Host route | Invocation | Result |
|---|---|---|
| Linux x86-64 RBE | `4beb4e02-dcab-4279-ab68-32256ed4a716` | probe passed |
| macOS ARM64 local | `99582444-f783-4c41-90a2-051384a4c2d8` | probe passed |
| macOS x86-64 local/Rosetta | `ed2a0c6d-d561-4ee3-8afe-2002aafbc1a4` | all three tools passed |
| macOS ARM64 artifact rerun | `26076e27-4b7c-499b-b441-955c50a293b3` | passed |
| Linux x86-64 RBE, final external-module targets | `42e7042f-ef47-4e26-96e1-42f3657e91ad` | all three passed uncached |
| macOS ARM64, final local targets | `e391bd7d-5af9-45a0-9365-3d6d68e1f16f` | all three passed uncached |
| macOS x86-64, final local targets | `eef3c741-e6f4-4ba9-a870-aa8d8695ec7d` | all three passed uncached |
| e2e consumer, macOS ARM64 local | `9576ec6b-f43d-475a-85cb-efc37b9ef55e` | all three `@llvm//tools:*` targets passed uncached |

Fact: the first ARM64 artifact test (invocation prefix `6aae04d2`) failed because the test
assumed AMD64 while clang-cl correctly defaulted to the exec host. The test now
passes an explicit `--target=x86_64-pc-windows-msvc`; target and exec
architecture are no longer conflated.

Fact: `@local_config_platform//:host` was an invalid repository
(invocation prefix `f336deaf`). `@platforms//host:host` was the correct label. With only the
test runner forced local, build actions still sent Darwin tools to Linux RBE
and failed `Exec format` (invocation prefix `1d3a30df`). Adding `--spawn_strategy=local`
made the host-local contract explicit.

Fact: the direct probe covers paths containing spaces, non-ASCII text, and a
colon where the host permits it; `.d`; English ShowIncludes under
`VSLANG=1033`; `/Brepro` repeated object hash and zero timestamp; UTF-8 and
UTF-16 compiler/archive/link response files; llvm-lib `argv[0]` personality;
and an actual `llvm-lib[.exe]` basename alias. UTF-8 is the required portable
format; UTF-16 archive support is recorded but is not required by the Bazel
contract.

The first exact e2e consumer invocation failed, invocation
`ca2ee949-50f3-4f9b-b305-4a56044a0a51`:

```text
unknown repo 'rules_go' requested from @@llvm+
```

Fact: `rules_go` 0.62.0 was already a non-dev module dependency with
`repo_name=None`, while a second dev-only declaration supplied the root-only
apparent name. Dev dependencies disappear when llvm is consumed. Decision and
fix: give the existing 0.62.0 dependency its normal apparent name and remove
the redundant 0.61.1 dev declaration. No dependency version was added or
changed. The consumer rerun above proves the repository mapping.

Current CI uses native host-local execution for Linux x86-64/ARM64, macOS
x86-64/ARM64, and Windows x86-64/ARM64. Final workflow run IDs/results are
recorded in **Closeout** after the branch is pushed.

The first native workflow run, `32044724795`, reached the Windows probe step
but Bazel 9.2 rejected the repository's obsolete
`--noexperimental_remote_repo_contents_cache` option before analysis on both
Windows architectures. The run was canceled after reproducing the same root
cause on x86-64 and ARM64. The option was removed from both the new probe step
and the existing Windows test command; the remaining explicit empty repository
cache settings are preserved. macOS ARM64 and both started Linux x86-64 probe
jobs had already passed; macOS x86-64 and Linux ARM64 were canceled before a
result. This run is diagnostic, not a completed gate. Bazel 9.2 help confirms
that `--repo_contents_cache` remains supported and the corrected exact probe
command passed locally at invocation
`33578e63-a6d1-4634-91a6-4b76ba2cbd31` (3/3).

The replacement workflow, `32045177588`, passed all four Linux probes and both
macOS probes. Windows ARM64 completed 6,025 build actions, then all three tests
failed before their code ran because the shared `exec_test` wrapper exposed an
extensionless executable symlink; Go's Windows launcher requires the `.exe`
path. Windows x86-64 was still building the same graph. The helper now declares
a `.exe` wrapper whenever its exec-configured inner executable has that
extension, while preserving the existing Unix output path. This is a shared
helper correctness fix, not probe-specific special casing. Bazel 9.2 cquery
for both Windows ARM64 (`20eca760-623d-453b-a81e-99c4f2754561`) and x86-64
(`19e43687-b951-488d-b85c-7ef78c5b1ad8`) resolves the wrapper output as
`test.exe`. The unchanged macOS path and all three focused tests pass at
invocation `8c303b3a-eee1-4dbc-b45e-a04e0018b537`.

The third workflow, `32046398874`, passed all Linux and macOS probes. Windows
x86-64 then failed while building rules_go's standard library: cgo routed its C
compile through the repository toolchain, where clang correctly rejected the
MinGW-only `-mthreads` argument under `-Werror`. The three tools have no cgo
code or cgo dependencies, so their binaries and tests now declare
`pure = "on"`; this prevents an irrelevant C toolchain from entering the Go
standard-library build on either Windows architecture. The resulting aquery
shows `CGO_ENABLED=0` on the Windows x86-64 execution platform at invocation
`289ef8ef-2359-4119-8774-d02625dce964`; focused tests remain 3/3 green at
`0050ff97-a30b-45e7-a8f5-a7af895eede8`.

Final baseline after the module-visibility fix:

```text
bazel build --config=remote //:main
invocation cf19433a-19d1-4ae1-9cde-88dd49134c91: PASS

bazel aquery --config=remote --include_param_files //:main --output=jsonproto
invocation 03fba67f-18a6-476d-a3d0-89ffb36e0b53: PASS
20,597 bytes
SHA-256 567806be8fceb80c4c83de6926e31fbc023aa02e985285d020da677ac5018ae6
```

Final frozen-patch rerun produced the same 20,597-byte aquery and SHA-256:
build invocation `2bef9356-80a9-49fc-9d6d-f51e58e6513f`; aquery invocation
`1194978e-1c84-4e66-ab72-d402aefc5a91`.

Final focused verification before commit:

- macOS ARM64 host-local: `c07354ca-4d42-4979-ace6-753578f2abb6`, 3/3 pass;
- macOS x86-64 host-local: `900ad08c-a3c3-4a60-9b15-31130b2a3402`, 3/3 pass;
- Linux x86-64 RBE consumer: `11164616-35ce-427f-bfa6-7b68427a2fd6`, 3/3 pass;
- macOS ARM64 external consumer: `4db17056-c72c-46f6-a9c2-5e4b4d89965a`, 3/3 pass;
- corrected real Windows-GNU action assertion:
  `78a703ee-0dfa-4ef7-b839-4c88b7bb9f33`, pass;
- Buildifier check, Ruby YAML parse, `git diff --check`, no changed/new Python,
  and no README changes: pass.

Structured review command:

```sh
/Users/corentinkerisit/.agents/skills/autoreview/scripts/autoreview \
  --mode local --stream-engine-output
```

All actionable findings were accepted and fixed, including exact action
cardinality, archive member/timestamp inspection, strict specs, response-file
association, structural PDB parsing, Windows runfile-manifest resolution, and
complete CI matrix/version wiring. The final rerun exited 0 with
`autoreview clean: no accepted/actionable findings reported` and overall
confidence 0.84.

## Decisions 1-25

### 1. Branch update and base

Fact: `git fetch origin main`; `HEAD` and `origin/main` both resolve to
`d2f5dd0f33aae9f52d34ba631540285b2d09b368`; ahead/behind `0 0`.

Decision: Phase 0 is based exactly on PR 709's current `main` result. Layer 1
must record this Phase 0 commit as its parent and recheck `origin/main` before
stack initialization.

### 2. Public platforms and Microsoft STL exposure

Decision: expose `@llvm//platforms:windows_x86_64_msvc` and
`@llvm//platforms:windows_aarch64_msvc` in Layer 1. They mean MSVC ABI plus
libc++, not Microsoft STL. Layer 2 adds the independently selectable
`//constraints/cxxstdlib:msvc` route through custom platforms; no initial
`*_msvc_stl` convenience platform names.

### 3. Windows CRT constraint semantics

Fact: modern MSVC direct probes close through UCRT plus VCRuntime; repository
`msvcrt` currently names the legacy MinGW route.

Decision: reuse `//constraints/windows/crt:ucrt`. Make every current MinGW CRT
consumer ABI-aware so UCRT never selects MSVC ABI by itself. Keep `msvcrt`
MinGW-only. Do not add a `not_applicable` value.

### 4. Both CRT features enabled

Inference: dynamic is the default feature and static is opt-in, so a strict
mutual-exclusion error would make the normal static request conflict with the
default.

Decision: static wins. Static CRT arguments apply when
`static_link_msvcrt` is enabled; dynamic CRT arguments require its absence.
Goldens must prove exactly one of `/MD` or `/MT`.

### 5. Dynamic disabled with static absent

Fact: Bazel ignores an unknown requested feature; omission cannot express a
stable error. rules_cc exposes `ctx.features` and `ctx.disabled_features` to
toolchain configuration analysis.

Decision: a repository-owned validation dependency fails analysis when global
`dynamic_link_msvcrt` is disabled and `static_link_msvcrt` is absent. This is
configuration-wide; per-rule CRT feature toggling remains unsupported and is
tested as such.

### 6. rules_cc 0.2.22 inventory and drift design

Fact: `MODULE.bazel` pins rules_cc 0.2.22. The exhaustive protocol inventory,
override/backfill hazards, and upgrade procedure are in
`windows-msvc-rules-cc-0.2.22.md`.

Decision: every overridden surface gets argument-expansion goldens plus real
`aquery`; GNU form count zero, MSVC form count one, and no legacy backfill.
Every rules_cc bump regenerates the label/variable/default/backfill inventory
and performs a golden/action diff against the old pin.

### 7. PR 187 and rules_cc PR 561 map

Fact: the exact heads, diff hashes, file maps, adoption/rejection decisions,
and provenance rules are in `windows-msvc-rules-cc-0.2.22.md`.

Decision: neither PR is cherry-picked or a dependency. Reimplement the owned
behavior; preserve attribution for materially adapted code.

### 8. Tools on every exec host

Fact: prebuilt maps contain clang-cl, llvm-ar, and lld-link for all six host
OS/CPU pairs. Local macOS ARM64/x86-64 and Linux x86-64 RBE probes pass.
Native six-host GitHub Actions is the closeout execution gate.

Decision: claim an exec host only when the same Go Bazel tests pass natively.
No host SDK discovery and no target/exec inference.

### 9. Dependency protocol

Fact: clang-cl produced correct `.d` files through `/clang:-MD`,
`/clang:-MF`, and `/clang:<path>`; ShowIncludes also produced the English
prefix under `VSLANG=1033`.

Decision: `.d` is the normative protocol. It avoids localized output parsing
and a host parser. ShowIncludes remains comparative probe evidence only.

### 10. Response files

Fact: independent compiler, archive, and linker response probes pass with
UTF-8 on tested hosts; UTF-16 also passes for compiler/link and was observed
for archive where recorded. Quoting covers spaces/non-ASCII/host-legal colons.

Decision: generate UTF-8 response files independently for clang-cl, llvm-ar,
and lld-link. Each is a declared input with tool-specific quoting; never reuse
one tool's serializer by assumption.

### 11. Header parser coherence

Decision: Layer 1 routes header parsing/layering through clang-cl with the same
target/SDK inputs and `.d` protocol if rules_cc can consume that action
coherently. Until that positive test exists, do not advertise
`supports_header_parsing`; never run the clang++ wrapper with CL syntax.

### 12. `supports_start_end_lib`

Fact: lld-link has no GNU `--start-lib/--end-lib` contract. Bazel may silently
ignore an unknown requested feature.

Decision: do not advertise `supports_start_end_lib`. Normal object groups are
expanded. A known rejection feature/sentinel produces a stable analysis error
for an explicit request. ThinLTO and Rust `.rlib` propagation remain outside
the stack until independently designed.

### 13. SDK directory model

Fact: windows_support exposes separate MSVC and Windows SDK repository roots,
not one canonical Visual Studio tree.

Decision: pass explicit, ordered include and library directories. Do not use
or mix `/winsysroot` until a coherent topology is independently proven.

### 14. Case-correct transformations

Fact: the case-sensitive APFS build and both target-architecture header probes
passed. Alias spellings do not suppress Clang's nonportable-case diagnostic.

Decision: consume windows_support transformations on case-sensitive exec
hosts, preserve exact logical include/lib spelling, and keep a warnings-on
diagnostic test plus a quiet functional test. Linux native CI is an additional
case-sensitive gate.

### 15. Interface-library output

Fact: rules_cc/Bazel exposes `interface_library_output_path`; native Windows
uses `/IMPLIB:%{interface_library_output_path}` and `.if.lib`.

Decision: declare `<name>.if.lib`, pass that exact variable to `/IMPLIB:`, and
link consumers through it. DLL, interface library, DEF exports, and copying
are one tested contract; orphan `.lib` files fail the artifact assertion.

### 16. PDB output

Fact: `cc_binary`/`cc_shared_library` declares the sibling `<binary>.pdb` when
`generate_pdb_file` is enabled; rules_cc 0.2.22 exposes no `pdb_file` build
variable. lld-link `/DEBUG` defaults to the output basename and direct probes
produced valid PDBs.

Decision: use `/Z7` compile debug data initially. Enable
`generate_pdb_file`, pass `/DEBUG`, declare the sibling PDB, and rely on
lld-link's matching default name. Do not invent a variable or emit empty
`/PDB:`. Inspect CodeView path privacy and repeated `/Brepro` output.

### 17. libc++ artifact names and auto-link

Fact: upstream libc++ uses output name `c++` for shared/static, sets the static
prefix to `lib`, and its Microsoft ABI auto-link selects `c++.lib` for shared
or `libc++.lib` when visibility annotations are disabled. Upstream warns that
shared libc++ plus a non-DLL CRT does not work correctly.

Decision:

- shared runtime: `c++.dll`;
- shared import library: `c++.lib`;
- static library: `libc++.lib`;
- define `_LIBCPP_NO_AUTO_LINK` for consumers and make the selected artifact an
  explicit declared link input;
- reject shared libc++ plus `/MT`.

### 18. libc++ ABI site configuration by LLVM line

Facts: LLVM 21.1.8, default 22.1.8, and supported 23.1.0-rc1 each carry their
own header inventory. Upstream defaults ABI version 1/namespace `__1`; MSVC
selects VCRuntime; clang-cl auto-detects Microsoft ABI.

Decision: generate a version-specific site header from each line's own source
template and cache it by full LLVM revision plus all config values. Pin the
common ABI contract on every line:

- `_LIBCPP_ABI_VERSION=1`, `_LIBCPP_ABI_NAMESPACE=__1`;
- Microsoft ABI forced on, Itanium forced off;
- VCRuntime selected; `_LIBCPP_NO_VCRUNTIME` absent;
- Win32 threads on, pthread/C11/external thread APIs off;
- exceptions, RTTI, threads, filesystem, localization, Unicode, wide chars,
  and random device on;
- Windows time-zone database off unless a data source becomes a separately
  owned feature;
- hardening mode `none`, matching current repository policy;
- `_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS` only for the static artifact;
- `_LIBCPP_NO_AUTO_LINK` for consumer compilation.

Do not copy the LLVM 22 generated header into 21 or 23. Line-specific macros
remain owned by that line's template and must appear in a checked golden.

### 19. Microsoft STL contract

Decision: Layer 2 selects Microsoft STL only with MSVC ABI and UCRT. Header
order puts the broad VC tree before other C++ headers. Use retail libraries,
`_ITERATOR_DEBUG_LEVEL=0`, no `_DEBUG`, no `/MDd` or `/MTd`, and no debug
payload. `/MD` requires an externally installed/deployed matching VC runtime;
`/MT` links retail static CRT/VCRuntime. The repository does not publish,
bundle, or expose `VC/Redist`; app-local deployment remains a legal-review
follow-up. Mixing repository-owned libc++ and Microsoft-STL closures fails
analysis; opaque prebuilt ABI cannot be inferred.

### 20. STL x CRT x libc++ linkage matrix

| STL | CRT | libc++ artifact | Disposition |
|---|---|---|---|
| libc++ | `/MD` | static `libc++.lib` | supported after Layer 1 proof |
| libc++ | `/MT` | static `libc++.lib` | supported after Layer 1 proof |
| libc++ | `/MD` | `c++.dll` + `c++.lib` | supported after Layer 1 proof |
| libc++ | `/MT` | shared | reject: upstream-unsafe |
| Microsoft STL | `/MD` | not applicable | Layer 2 supported route |
| Microsoft STL | `/MT` | not applicable | Layer 2 supported route |
| either | debug CRT | any | reject |
| mixed repository-owned STL closure | any | any | reject |

Decision: CRT, STL, and libc++ linkage are orthogonal configuration dimensions
but validated together. Transitions preserve all three.

### 21. Sanitizer matrix and C++ closure

Matrix applies independently to libc++/Microsoft STL, x86-64/ARM64, and LLVM
21.1.8/default 22.1.8/23.1.0-rc1. `Candidate` never means publicly supported;
Layer 3 must prove every selected axis and exact runtime filename.

| Capability | `/MD` executable | `/MD` DLL | `/MT` executable | `/MT` DLL |
|---|---|---|---|---|
| ASan | candidate: dynamic runtime + deployment DLL | candidate: dynamic import/runtime | candidate: static runtime whole-archive | candidate only as proven executable/DLL pair with thunk; standalone reject |
| UBSan | candidate: exact standalone runtime | candidate | candidate | candidate |
| libFuzzer | candidate executable | reject | candidate executable | reject |
| ASan+UBSan | candidate using ASan ownership | candidate | candidate | same paired-thunk restriction |
| libFuzzer+ASan | candidate executable | reject | candidate executable | reject |
| CFI | reject in stack; ThinLTO prerequisite unowned | reject | reject | reject |

Decision: build STL-specific compiler-rt variants by default because
compiler-rt contains C++. A shared variant is allowed only after inputs,
directives, symbols, and imports prove no STL dependency. Exact runtime
manifests are keyed by LLVM major, target architecture, CRT, output kind, STL,
and static/import/DLL/thunk form. Missing architecture/version support triggers
owner matrix review; it never silently narrows a public capability.

### 22. llvm-lib personality

Fact: setting argv[0] to `llvm-lib` selects lib syntax on non-Windows; a real
`llvm-lib`/`llvm-lib.exe` basename alias creates valid archives. The Go probe
uses symlink, hardlink, then byte-copy fallback for host portability.

Decision: Layer 4 exposes a deterministic basename alias from the same
llvm-ar binary and tests it on all six exec hosts. It changes only archive
dialect, not archive contents or link behavior.

### 23. Minimum Windows version and subsystem

Fact: direct and existing lld-link outputs defaulted to subsystem/minimum OS
6.0 for x86-64 and ARM64.

Decision: preserve lld-link's 6.0 default; pass `/SUBSYSTEM:CONSOLE` for
executables, allow explicit GUI override, use `/DLL` for DLLs, and do not add
`/OSVERSION` without a separate requirement.

The artifact gate now validates the MSF superblock, block map, stream
directory, and PDB info stream before accepting a PDB; content/path checks
search both byte and UTF-16LE representations. PE inspection also dumps the
debug directory and CodeView records. A real lld-link PDB passed that parser in
focused invocation `fcad20db-f1cb-48b2-8197-4c20e9f6cd5f`; a truncated
signature-only fixture is rejected.

### 24. EULA, redistribution, CI environment, secrets

Fact: windows_support checks
`BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1` before fetching MSVC payloads; the
owner authorized acceptance. Version 0.2.0 exposes include/lib but not Redist.

Decision: CI may set the EULA repository environment only in jobs that fetch
the repository. Cache/downloads remain private CI artifacts. Do not publish
Microsoft payloads or redistributables. Reuse the existing repository CI
credential value only; introduce no new credential value or secret dependency.
Any request
to publish payloads or app-local Redist stops for legal review.

### 25. Stack approval

Fact: owner explicitly approved PLAN Section 9 and authorized the prescribed
branches/worktrees plus draft `gh stack submit --auto` per completed layer.

Decision: Phase 0 is not a product layer and gets no stacked PR. After Phase 0
closeout, initialize the approved four-layer stack and stop before Layer 1 in
this goal.

## Stop-condition audit

| Condition | Phase 0 result |
|---|---|
| stale parent | clear: exact current `origin/main` |
| public semantics unapproved | clear: owner approved enumerated semantics |
| EULA authority | clear for private fetch/build |
| payload redistribution | clear only because redistribution is forbidden |
| missing core tool | clear: all six native exec hosts passed the checked-in probes |
| dependency/response protocol | clear: local/RBE and native CI evidence passes |
| SDK release/API | windows_support 0.2.0 observed |
| case model | clear: case-sensitive APFS and Linux CI passed |
| import library/PDB | direct x86-64/ARM64 proof and representable rules_cc outputs |
| CRT/STL conflict | explicit validation contract |
| shared libc++ + `/MT` | stable reject |
| README/public API edit | no README edit; approved PLAN-only semantics |
| Layer 1 work | none |
| permanent Python introduced | none |

## Closeout

Status: complete. Work stopped before Layer 1.

- Branch: `cerisier/windows-msvc-phase0`.
- Worktree:
  `/Users/corentinkerisit/code/github.com/hermeticbuild/hermetic-llvm-msvc-phase0`.
- Implementation commits: `5521610cf8d2e0ead4e856441272d6fb960b88f8`,
  `937e4f30fb1dceee6bedac8151405c35a3c69015`,
  `dbd2e5aaee421da90cda8fd3a8eeaeb142ecce0c`, and
  `396058720cb3f703023eb973c4d2ed1ce916c914`.
- Final GitHub Actions run: `32047134011`, attempt 2, head
  `396058720cb3f703023eb973c4d2ed1ce916c914`; all 38 jobs passed.
- Required probe jobs passed: Windows ARM64 `95442248256`, Windows x86-64
  `95442248333`, Linux x86-64 last release candidate `95442249047`, Linux
  ARM64 Bazel 8 `95442249179`, Linux ARM64 last release candidate
  `95442250112`, Linux x86-64 Bazel 8 `95442274780`, macOS ARM64
  `95442279750`, and macOS x86-64 `95442293267`.
- Attempt 1 proved all required probes and Windows full jobs, then an unrelated
  Linux ARM64 root suite failed after repeated BuildBuddy TLS negotiation
  disconnects crashed Bazel with exit 33. The failed-only rerun passed,
  including root job `95442247646`.
- Structured autoreview was clean for the complete Phase 0 patch, each
  subsequent Windows CI correction, and the final evidence-only closeout
  (`patch is correct`, confidence 0.90).
- No README or product public API changed. No Microsoft payload was
  redistributed. No permanent Python was introduced.
- Phase 0 is not a product stack layer, so no stacked PR was submitted.
