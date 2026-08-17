Investigation complete. No source files changed. Plan updated after review.

## Workspace state

- Branch: `cerisier/windows-msvc-clang`
- Worktree: `/Users/corentinkerisit/.codex/worktrees/ab17/hermetic-llvm`
- HEAD: `a1abad2645613f6c241dae1e58951d86b3360522`
- Parent: PR 709 branch `cerisier/windows-abi-authoritative`
- PR 709 base: current `main` at `ec088a1dac0a273311fc2dc9adc0207158767909`
- PR 187 branch not used as a base.
- Branch contains no commits beyond PR 709. The only worktree change is this untracked `PLAN.md`; no source file is modified.

PR 709 currently has all reported checks green except one Ubuntu/Bazel 8 `//tests/...` job. Its failure must be resolved or identified as unrelated before the child PR is published.

The Bazel skill shaped the plan around target/exec separation, explicit constraint validation, lazy module-extension dependencies, hermetic declared tools, and action-graph inspection.

## Executive scope

“Non-clang-cl MSVC handled” means:

- C and C++ actions invoke ordinary `clang` or `clang++`.
- Compiler identity remains `clang`.
- Target ABI selected by:
  - `--target=x86_64-pc-windows-msvc`
  - `--target=aarch64-pc-windows-msvc`
- Compile syntax remains normal rules_cc/GNU-driver syntax:
  - `-c`, `-o`
  - `-MD -MF`
  - `-I`, `-isystem`, `-iquote`
  - `-D`
  - ordinary response files
- Link actions invoke `clang++`, with `-fuse-ld=lld`.
- Clang internally selects LLD’s COFF driver. `lld-link` is a declared tool alias/input, not a user-facing action or argument dialect.
- MSVC ABI does not imply MSVC STL. The target must explicitly select `//constraints/cxxstdlib:msvc`.
- Windows SDK, platform import libraries, UCRT, VCRuntime, MSVC STL, compiler-rt, and redistributable DLLs remain separately modeled semantic components.
- Both retail static and retail dynamic Microsoft runtime linkage supported through the canonical Bazel C++ feature contract:
  - `dynamic_link_msvcrt` is the default and maps to `-fms-runtime-lib=dll` (`/MD` semantics).
  - `static_link_msvcrt` is the opt-in and maps to `-fms-runtime-lib=static` (`/MT` semantics).
- Runtime linkage is selected for the complete target configuration with `--features`, not by a platform constraint, `linkstatic`, or a per-rule `features` attribute.
- Initial `/MD` support is hermetic through link output production, but execution requires a compatible Microsoft Visual C++ v14 Redistributable already installed on the target machine.
- App-local redistributable DLL acquisition and Bazel runfile deployment are a second implementation phase. They must not block or distort the initial ordinary-Clang toolchain work.
- No `clang-cl`, `cl.exe`, direct `lld-link` syntax, or clang-cl-on-non-Windows work.

Clang is inherently cross-targeted through `-target`, with target headers and libraries supplied using normal include/library options. [Clang cross-compilation documentation](https://clang.llvm.org/docs/CrossCompilation.html). Clang’s `-fms-runtime-lib=static|dll` directly corresponds to `/MT|/MD`; debug forms also exist but will not be exposed. [Clang command reference](https://clang.llvm.org/docs/ClangCommandLineReference.html).

Recommendation: keep Clang as link driver. This preserves rules_cc syntax, compiler-runtime discovery, sanitizer/profile runtime selection, and target-aware COFF dispatch. LLVM recommends invoking linkers through compiler drivers, while LLD provides a production-grade COFF flavor supporting import libraries, DLLs, `.def`, resources, and PDBs. [LLD usage](https://lld.llvm.org/), [LLD Windows support](https://lld.llvm.org/windows_support.html).

## Demonstrated baseline facts

On the unmodified PR 709 parent:

- Windows x86-64 actions run on Linux AArch64 RBE, proving exec architecture remains independent from target architecture.
- Current compile action uses:
  - `clang++`
  - `-target x86_64-w64-windows-gnu`
  - GNU include/define/dependency syntax
  - `-c ... -o ...`
- Current link action uses:
  - `clang++`
  - `-fuse-ld=lld`
  - MinGW directories
  - `-lucrt`
  - `-shared`
  - ordinary `-o`
- Current MinGW build produced:
  - `main_default.exe`
  - `windows_explicit_def.dll`
  - `libcomm_symbol_static_lib.a`
- PE inspection showed AMD64 COFF, UCRT API-set imports, `KERNEL32.dll`, valid DLL exports, and `.pic.o` archive members.
- Ordinary LLVM 22 Clang `-###` accepts the same GNU compile syntax for both MSVC triples.
- Ordinary Clang link `-###` invokes `lld-link` internally for both architectures.
- `-fms-runtime-lib` object directives were:
  - `static`: `libcmt.lib`
  - `static_dbg`: `libcmtd.lib`
  - `dll`: `msvcrt.lib`
  - `dll_dbg`: `msvcrtd.lib`
- Pinned rules_cc 0.2.22's native Windows toolchain enables `dynamic_link_msvcrt` by default and makes `static_link_msvcrt` the opt-in that suppresses dynamic CRT arguments.
- Pinned rules_cc computes `static_linking_mode`/`dynamic_linking_mode` from `linkstatic` and `--dynamic_mode` without requesting `static_link_msvcrt`, demonstrating that ordinary dependency linkage and MSVC CRT linkage are independent.
- `bazel aquery //tests/linux_linking:hello --features=definitely_unknown_feature` succeeded under the current Bazel 9.2 baseline, demonstrating that an unknown requested feature is ignored rather than rejected during analysis.
- MSVC compiler-rt lookup expects `clang_rt.builtins.lib`, not the current MinGW-style `libclang_rt.*` basename.
- ThinLTO, profile/coverage, ASan, UBSan, CFI, and libFuzzer driver paths exist for both MSVC architectures in LLVM 22.
- Clang directly rejects Windows targets for TSan, MSan, LSan, DFSan, NSan, SafeStack, RTSan, TypeSan, and XRay.

Microsoft documents UCRT, VCRuntime, CRT startup, and STL as distinct library sets. Static `/MT` and dynamic `/MD` must remain consistent across linked modules. [Microsoft CRT composition](https://learn.microsoft.com/en-us/cpp/c-runtime-library/crt-library-features?view=msvc-170), [`/MD` and `/MT` contract](https://learn.microsoft.com/en-us/cpp/build/reference/md-mt-ld-use-run-time-library?view=msvc-170).

## Architectural invariants

1. Target ABI never changes compiler-driver dialect.
2. Exec OS/CPU only selects executable tools; target OS/CPU/ABI selects output semantics.
3. Existing unconstrained, GNU, and GNU-LLVM Windows platforms remain MinGW-compatible.
4. `windows/crt:msvcrt` continues to mean legacy `msvcrt.dll` selection for MinGW only.
5. MSVC STL is selected exclusively through `cxxstdlib`.
6. Microsoft runtime linkage is a target-configuration-wide Bazel C++ feature: default `dynamic_link_msvcrt`, opt-in `static_link_msvcrt`.
7. `linkstatic`, `--dynamic_mode`, `static_linking_mode`, `dynamic_linking_mode`, and `static_link_cpp_runtimes` do not select `/MT` versus `/MD`; they own ordinary dependency/runtime-artifact linkage.
8. Public usage selects static linkage through global target `--features=static_link_msvcrt`; a per-rule feature is not a supported interface because it does not propagate to compiled dependencies.
9. Retail `dbg` builds still use retail CRT; debug CRT is not exposed.
10. Every binary/tool used by an action is a declared input. `PATH` discovery forbidden.
11. Upstream rules_cc features remain authoritative where ordinary Clang syntax already works.
12. Project adapters limited to missing COFF-specific outputs, ordinary-Clang flag forwarding, and feature-aware VC redistributable deployment not expressible through current generic runtime attrs.
13. No advertised capability silently disappears for MSVC targets.
14. MinGW UCRT and legacy-MSVCRT action and artifact behavior remain regression-tested.
15. Phase-1 `/MD` support has an explicit external deployment prerequisite; it is not described as a standalone or hermetically runnable output.
16. Phase-2 app-local runtime deployment is additive: it must not change compiler/linker actions, runtime selection, or artifact ABI established in Phase 1.

## Component and ownership map

| Component | Semantic owner | Planned routing |
|---|---|---|
| Windows target ABI/triple | PR 709 constraints/platform config | Existing ABI-authoritative mapping |
| Clang/Clang++ | hermetic-llvm tool map | Ordinary driver for every compile/link action |
| COFF linker | LLVM LLD | Declared `lld-link` alias selected internally by Clang |
| Windows headers/platform libs | windows_support Windows SDK | Shared/UM/WinRT include and UM library components |
| UCRT | windows_support Windows SDK | Separate include and library components |
| VCRuntime | windows_support MSVC payload | Separate header/library semantic target |
| MSVC STL | `cxxstdlib:msvc` + windows_support | Included only for selected C++ standard library |
| MSVC CRT startup/linkage | Bazel C++ feature configuration | Canonical `dynamic_link_msvcrt`/`static_link_msvcrt` names with ordinary-Clang `-fms-runtime-lib=dll|static` arguments |
| Ordinary dependency linkage | rules_cc `linkstatic`/`--dynamic_mode` | Remains independent from MSVC CRT linkage |
| Generic toolchain runtime artifacts | rules_cc `static_link_cpp_runtimes` plus `static_runtime_lib`/`dynamic_runtime_lib` | Continue to follow ordinary static/dynamic linking mode; do not select `/MT`/`/MD` |
| VC redistributables | Target-machine prerequisite in Phase 1; windows_support plus a feature-aware deployment adapter in Phase 2 | Compatible installed v14 Redistributable first; architecture-specific app-local runtime/STL DLL groups later, selected by effective MSVC CRT feature rather than ordinary link mode |
| compiler-rt | hermetic-llvm source runtimes | MSVC triple and `.lib` resource-directory layout |
| Artifact naming | hermetic-llvm cc toolchain | ABI-specific `.obj`, `.lib`, `.dll`, `.if.lib`, `.exe` |
| rules_cc actions | upstream rules_cc 0.2.22 | Generic compile/link/ThinLTO/param/dependency features |
| Import library/PDB adapters | hermetic-llvm | Small Clang-driver-forwarded COFF args only |
| LLVM source bootstrap | hermetic-llvm LLVM overlays | Target-ABI-aware source selection and LLD patches |

## Proposed public constraint/platform contract

This is a public API change and requires approval as part of this plan.

Add only:

- `//constraints/cxxstdlib:msvc`
- `//constraints/windows/crt:not_applicable`

Provided platforms:

- `@llvm//platforms:windows_x86_64_msvc`
- `@llvm//platforms:windows_aarch64_msvc`

Existing `windows_x86_64` and `windows_aarch64` remain GNU/MinGW UCRT platforms through PR 709.

Do not add an MSVC-runtime constraint or static/dynamic MSVC platform aliases. The public runtime-linkage contract is:

- Default MSVC target configuration: `dynamic_link_msvcrt` enabled, `-fms-runtime-lib=dll`.
- Static MSVC target configuration: add global `--features=static_link_msvcrt`, which emits `-fms-runtime-lib=static` and suppresses dynamic CRT arguments.
- `--compilation_mode=dbg` does not change either mode to a debug CRT.
- `linkstatic` and `--dynamic_mode` remain independently selectable.

Example static invocation:

```sh
bazel build \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  --features=static_link_msvcrt \
  //path/to:target
```

The raw feature is meaningful only to an MSVC-capable toolchain. Bazel ignores unknown requested features, so documentation and CI must always scope it with an MSVC platform; feature use on a MinGW toolchain is not promised to produce an analysis error.

## Supported and invalid combinations

| ABI | C++ stdlib | Windows CRT constraint | MSVC CRT feature state | Result |
|---|---|---|---|---|
| unconstrained/gnu/gnullvm | libc++ | ucrt | MSVC features unavailable/irrelevant | Existing MinGW UCRT |
| unconstrained/gnu/gnullvm | libc++ | msvcrt | MSVC features unavailable/irrelevant | Existing legacy MinGW `msvcrt.dll` |
| msvc | msvc | not applicable | default `dynamic_link_msvcrt` | Supported retail `/MD` equivalent; compatible target-architecture VC v14 Redistributable required at execution in Phase 1 |
| msvc | msvc | not applicable | `static_link_msvcrt` requested | Supported retail `/MT` equivalent; dynamic CRT arguments suppressed |
| msvc | libc++/libstdc++ | any | any | Analysis error: incompatible C++ stdlib |
| non-msvc | msvc | any | any | Analysis error: MSVC STL requires MSVC ABI |
| msvc | msvc | ucrt/msvcrt | any | Analysis error: MinGW CRT selector invalid for MSVC ABI |
| msvc | msvc | not applicable | `dbg` plus either retail mode | Supported; remains retail and never selects `/MDd` or `/MTd` |
| msvc | msvc | not applicable | dynamic without installed VC Redistributable | Build/link succeeds; execution has a documented external prerequisite in Phase 1 |
| Windows x86/ARM32/ARM64EC | any | any | any | No registered target toolchain |

Combination config groups drive toolchain selection for ABI, STL, and MinGW CRT compatibility. Invalid platform combinations fail during analysis/toolchain resolution, with tests asserting the involved constraint labels. MSVC CRT linkage is selected only after toolchain resolution through the canonical feature contract.

`linkstatic` and `--dynamic_mode` are orthogonal to the MSVC CRT feature. Tests must cover static and dynamic ordinary dependency-link modes under both `/MD` and `/MT` and prove the CRT selection does not change.

`--compilation_mode=dbg` remains valid but selects the retail CRT associated with the effective feature mode. Tests must prove no `*d.lib` directive or `*d.dll` import appears.

The Phase-1 prerequisite is the Microsoft Visual C++ v14 Redistributable, not a full Visual Studio or Build Tools installation. It must match the target architecture and be at least as recent as the selected MSVC toolset. Bazel analysis cannot reliably detect whether a remote target machine satisfies this deployment prerequisite.

## Current-main and PR 709 gap analysis

PR 709 correctly supplies:

- ABI values and safe `unconstrained` behavior.
- GNU fallback for old OS/CPU-only Windows platforms.
- Explicit GNU repository platforms.
- ABI-aware target triples.
- ABI-aware compiler-rt resource directories.
- MinGW-only toolchain registration until MSVC support exists.

Remaining gaps:

- No windows_support dependency.
- No MSVC STL value.
- No ordinary-Clang implementation of the canonical `dynamic_link_msvcrt`/`static_link_msvcrt` feature contract.
- No MSVC-compatible toolchain registrations.
- No SDK/UCRT/VCRuntime/MSVC STL inputs.
- No app-local redistributable DLLs; this is a Phase-2 deployment gap, not a Phase-1 build/link blocker.
- No MSVC compiler-rt basename/layout.
- No ABI-specific COFF artifact patterns.
- No declared import-library emission.
- Current PDB feature passes `-Wl,--pdb=` without a path and produced no baseline PDB.
- Header parser is disabled on Windows and its implementation is POSIX-oriented.
- LLVM source overlays use compiler identity such as `msvc-cl` where target ABI should own the decision.
- Bootstrap aliases do not make `lld-link` an input to ordinary Clang link actions.
- Advanced capability support lacks MSVC-specific tests and availability gates.
- No MSVC CI/e2e matrix.

Relevant current areas: [toolchain declaration](/Users/corentinkerisit/.codex/worktrees/ab17/hermetic-llvm/toolchain/declare_toolchains.bzl), [cc toolchain](/Users/corentinkerisit/.codex/worktrees/ab17/hermetic-llvm/toolchain/cc_toolchain.bzl), [runtime routing](/Users/corentinkerisit/.codex/worktrees/ab17/hermetic-llvm/runtimes/BUILD.bazel), [CI](/Users/corentinkerisit/.codex/worktrees/ab17/hermetic-llvm/.github/workflows/ci.yaml).

## rules_cc conclusion

rules_cc 0.2.22 already provides the correct ordinary-driver forms for:

- compile source/output
- dependency files
- include/define options
- archiving
- libraries-to-link
- `.def`
- response files
- ThinLTO

Its native Windows toolchain also establishes the relevant CRT-selection contract:

- `dynamic_link_msvcrt` is enabled by default.
- `static_link_msvcrt` is an opt-in feature and suppresses the dynamic CRT arguments.
- `linkstatic` and `--dynamic_mode` request `static_linking_mode`/`dynamic_linking_mode` for ordinary dependency linkage; they do not request `static_link_msvcrt`.
- `static_link_cpp_runtimes` controls the toolchain's generic `static_runtime_lib`/`dynamic_runtime_lib` inputs according to that ordinary link mode. It does not represent `/MT` versus `/MD`.

See the pinned [rules_cc Windows CRT features](https://github.com/bazelbuild/rules_cc/blob/0.2.22/cc/private/toolchain/windows_cc_toolchain_config.bzl#L661-L714), [binary link-mode selection](https://github.com/bazelbuild/rules_cc/blob/0.2.22/cc/private/rules_impl/cc_binary_impl.bzl#L419-L425), and [rule-based runtime attributes](https://github.com/bazelbuild/rules_cc/blob/0.2.22/cc/toolchains/toolchain.bzl#L124-L134).

The feature names are historical: modern `/MD` composition includes UCRT and VCRuntime, optionally MSVC STL, rather than exclusively the legacy `msvcrt.dll`. Preserve the canonical external names for Bazel compatibility while using precise internal descriptions.

[rules_cc PR 561](https://github.com/bazelbuild/rules_cc/pull/561) is still open, conflicting, and primarily implements these features for MSVC/clang-cl dialect. It is not a dependency for this design. Until an appropriate public upstream feature exists, hermetic-llvm owns the smallest local ordinary-Clang adapter:

- `dynamic_link_msvcrt` -> `-fms-runtime-lib=dll`
- `static_link_msvcrt` -> `-fms-runtime-lib=static`
- no debug-CRT branch under `dbg`

The runtime-linkage feature must be requested globally in the target configuration. A feature placed only on one `cc_binary` or `cc_library` does not propagate to independently compiled dependencies and can violate Microsoft's single-runtime contract.

Current generic runtime attrs cannot be assumed to deploy VC redistributable DLLs correctly: their static/dynamic choice follows ordinary linking mode, while `/MD` versus `/MT` is independent. Phase 2 therefore needs a feature-aware deployment path or a narrowly scoped upstream API, proven under both `linkstatic` values.

Likely project-owned adapters:

- Import/interface library output: forward `/IMPLIB:<declared-output>` through Clang, likely `-Wl,/IMPLIB:...`.
- PDB output: `-gcodeview`, `-Wl,/DEBUG`, and declared `-Wl,/PDB:<path>`.
- Any missing COFF subsystem/build-ID option.
- Portable Windows header-parser execution.

These remain hypotheses until their Bazel variables and declared outputs are demonstrated in `aquery`.

## windows_support dependency findings

Current release: v0.2.0, pinned to MSVC 14.50.35717 and Windows SDK 10.0.26100.7705.

Good existing properties:

- Exact SDK integrities.
- Pinned Visual Studio installer manifest.
- x64/ARM64 routing.
- EULA checked lazily when `@msvc_runtime` is fetched.
- Reproducibility metadata.
- Root configuration overrides dependency defaults.

Current limitations relevant to Phase 2:

- MSVC extraction preserves only `include` and `lib`.
- `VC/Redist` is deleted.
- No redistributable DLL targets.
- One broad MSVC include directory and one broad architecture library directory.
- No logical file targets for the retail VCRuntime and MSVC STL DLL groups.
- SDK exposes UCRT and UM directories, but no higher-level semantic component contract.

These limitations do not block truthful Phase-1 `/MD` support. The existing MSVC headers and `.lib` files are sufficient to compile and link; the public contract requires a compatible target-architecture VC v14 Redistributable at execution.

Required upstream windows_support work for Phase-2 hermetic app-local deployment:

1. Preserve licensed x64 and ARM64 VC redistributable payloads.
2. Preserve the existing build-time header/library targets and additionally expose semantic targets for:
   - VCRuntime redistributable DLLs
   - MSVC STL/concurrency redistributable DLLs
3. Keep target-CPU routing independent from exec CPU.
4. Retain EULA laziness.
5. Add extraction/layout/integrity/laziness tests.
6. Cut a new release and pin the smallest compatible version here.

Microsoft limits redistribution to licensed users and the applicable REDIST list. Phase 1 therefore documents the centrally installed redistributable prerequisite and does not redistribute DLLs. Phase 2 must carry explicit acquisition/deployment policy. [Microsoft redistribution terms](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files?view=msvc-170). App-local DLLs are acceptable for hermetic tests, while production documentation should continue to recommend Microsoft’s centrally serviced redistributable package.

## PR 187 salvage and attribution map

Exact commit author identity, verified across all eight commits:

`Titouan Bion <titouan.bion@gmail.com>`

No PR 187 commit is suitable for wholesale cherry-picking. The main commit is stale and entangles ABI, clang-cl dialect, copied rules_cc features, runtime routing, bootstrap, tests, and documentation.

| PR 187 contribution | Decision | Reason | Attribution if used |
|---|---|---|---|
| Windows ABI constraint concept | Superseded | PR 709 owns the corrected implementation | None in child PR |
| MSVC target triple mapping | Superseded | PR 709 preserves GNU fallback correctly | None in child PR |
| windows_support integration/EULA concept | Adapt | Still required; current upstream contract differs | Titouan co-author on integration commit |
| SDK/MSVC include/library routing | Rewrite/adapt | Use `-isystem`/`-L`, semantic components, ordinary Clang | Titouan co-author |
| MSVC artifact patterns | Adapt | `.obj/.lib/.dll/.if.lib` remains useful | Titouan co-author |
| `lld-link`/bootstrap alias awareness | Rewrite | Alias only as Clang-declared input; no direct dialect | Titouan co-author if materially derived |
| compiler-rt MSVC routing | Rewrite/adapt | Correct triple and `.lib` basename required | Titouan co-author |
| Header-parser Windows portability hunk | Adapt | Independent useful implementation | Titouan co-author |
| Static/dynamic CRT feature concept | Adapt | Preserve canonical rules_cc feature names and default/opt-in behavior; replace CL flags with ordinary-Clang `-fms-runtime-lib`; never introduce a platform constraint | Titouan co-author |
| Import-library and `.def` support | Adapt | Forward through ordinary Clang | Titouan co-author |
| MinGW archive/PIC collateral | Discard | Caused by clang-cl capability changes; unrelated |
| Copied rules_cc MSVC feature sets | Discard | Wrong driver dialect; stale upstream dependency |
| `clang-cl`, direct `lld-link`, `/c`, `/Fo`, `/showIncludes` | Discard | Explicitly outside scope |
| Disabling `.d` dependencies | Discard | Violates driver-syntax invariant |
| Silent sanitizer/coverage removal | Discard | Violates capability policy |
| README support checkmarks | Rewrite after proof | Current draft overclaims support |

Implementation attribution policy:

- No blanket trailer.
- Every commit materially adapting Titouan’s work receives:
  `Co-authored-by: Titouan Bion <titouan.bion@gmail.com>`
- Unrelated original commits receive no trailer.
- If an independently reusable commit is later found, preserve its author instead; none is currently identified.
- Eventual PR description explicitly acknowledges PR 187 as the prototype/requirements source.
- zbarsky’s later ThinLTO/bootstrap findings are tracked separately and are not attributed to Titouan unless Titouan-authored code is reused.

## Ordered implementation plan

### Phase 1: ordinary-Clang MSVC toolchain with an installed-redist execution contract

### 1. Public target contract and registrations

Areas:

- `constraints/cxxstdlib`
- `constraints/windows/crt`
- `platforms`
- `platforms/config`
- `toolchain/declare_toolchains.bzl`
- bootstrap declarations

Work:

- Add only `cxxstdlib:msvc`, `windows/crt:not_applicable`, and the two CPU-specific MSVC platforms.
- Do not add an MSVC-runtime constraint or static/dynamic platform aliases.
- Add MSVC registrations alongside PR 709’s MinGW-compatible registrations.
- Preserve every existing MinGW match.
- Add analysis tests for valid and invalid ABI/STL/MinGW-CRT combinations.
- Keep runtime-linkage features out of toolchain compatibility and platform resolution.

Acceptance:

- Existing unconstrained/gnu/gnullvm Windows platforms resolve exactly as before.
- MSVC platforms resolve for x64 and ARM64 across all six supported exec OS/CPU pairs.
- Invalid ABI/STL/MinGW-CRT combinations fail during analysis.
- No SDK/MSVC repository fetched for MinGW targets.

Review gate: exact public labels/platform names and explicit confirmation that runtime linkage is not a target constraint.

### 2. windows_support build-time dependency

Areas:

- upstream `windows_support`
- root `MODULE.bazel`
- lockfile
- extensions/runtime routing

Work:

- Pin the current compatible windows_support version/integrities.
- Wire its existing SDK, UCRT, MSVC header, and architecture-specific library targets for compilation and linking.
- Add project-owned logical VCRuntime/MSVC-STL wrappers over the existing upstream include/library trees, and route the STL semantics only through `cxxstdlib:msvc`. Physical co-location does not imply semantic selection.
- Preserve EULA laziness.
- Do not make redistributable DLL exposure an initial toolchain prerequisite.

Acceptance:

- MinGW analysis does not fetch `@msvc_runtime`.
- MSVC analysis reports the EULA requirement before compilation if unset.
- x64 actions receive x64 files; ARM64 actions receive ARM64 files, regardless of exec CPU.
- Repository contents/integrities are reproducible.
- `/MD` links successfully without app-local VC DLL artifacts in the Bazel runtime closure.

### 3. Ordinary Clang driver and COFF toolchain

Areas:

- `toolchain/llvm`
- `toolchain/bootstrap`
- `toolchain/cc_toolchain.bzl`
- `toolchain/args`
- `toolchain/features`
- artifact patterns

Work:

- Keep compiler identity `clang`.
- Keep compile/link action tools as clang/clang++.
- Declare `lld-link` alias/data beside LLD multicall binary.
- Add MSVC triples, normal include/library args, and ABI-specific artifact names.
- Disable meaningless Windows-MSVC PIC preference without altering MinGW.
- Add only necessary import-library/PDB forwarding adapters.

Acceptance:

- `aquery` contains no `clang-cl` or direct `lld-link` action.
- Compile actions retain GNU rules_cc syntax and `.d` discovery.
- Link action is clang++, internally dispatching COFF LLD.
- Outputs use `.obj`, `.lib`, `.lo.lib`, `.exe`, `.dll`, `.if.lib`.
- Response files work with spaces and long paths.

### 4. Runtime and C++ standard-library routing

Areas:

- `toolchain/args/windows`
- `runtimes`
- compiler-rt overlays
- `toolchain/BUILD.bazel`

Work:

- Add C/SDK/UCRT/VCRuntime headers independently.
- Add MSVC STL only under `cxxstdlib:msvc`.
- Define the canonical MSVC CRT features locally for ordinary Clang until rules_cc exposes a suitable public implementation:
  - enable `dynamic_link_msvcrt` by default and emit `-fms-runtime-lib=dll`;
  - expose `static_link_msvcrt` as the global opt-in, emit `-fms-runtime-lib=static`, and suppress dynamic CRT arguments.
- Keep `linkstatic`, `--dynamic_mode`, and `static_link_cpp_runtimes` independent from MSVC CRT selection.
- Keep runtime selection uniform across every independently compiled C/C++ dependency by testing only target-configuration-wide feature selection; do not document per-rule `features` as a runtime-selection interface.
- Correct compiler-rt resource triples and `.lib` names.
- Keep sanitizer/profile compiler-rt runtime deployment separate from the Microsoft VC Redistributable prerequisite.
- Keep `dbg` on retail CRT.

Acceptance:

- C-only action gains no MSVC-STL semantic dependency or STL default-library directive; any physically shared upstream include directory is documented rather than mistaken for ABI-driven STL selection.
- C++ action gains MSVC STL only through `cxxstdlib:msvc`.
- Default `/MD` configuration gives every relevant C/C++ frontend action, including transitive dependency actions, `-fms-runtime-lib=dll` and no static directive.
- Global `--features=static_link_msvcrt` gives every relevant C/C++ frontend action, including transitive dependency actions, `-fms-runtime-lib=static` and no dynamic directive.
- Link-time default-library forwarding is added only if an object/directive and no-source link reproduction proves it necessary; compile directives and final link inputs must agree either way.
- Both CRT modes retain their result under `linkstatic=True`, `linkstatic=False`, `--dynamic_mode=off`, and `--dynamic_mode=fully` where those ordinary link modes are otherwise valid.
- Static PE imports no VC redist DLLs.
- Dynamic PE imports the expected VCRuntime/MSVC STL DLLs and executes on a Windows test environment provisioned with a compatible target-architecture VC v14 Redistributable.
- Phase-1 Bazel outputs do not claim to carry the VC Redistributable in runfiles.
- No debug CRT directive/import.
- MinGW UCRT/MSVCRT actions unchanged.

### 5. Complete rules_cc surface

Areas:

- `e2e/rules_cc`
- header parser
- COFF features/artifact patterns

Coverage:

- C and C++
- `.S` preprocessed assembly
- static and alwayslink libraries
- executables
- DLLs
- import/interface libraries
- explicit/generated `.def`
- compile/archive/link response files
- `.d` dependency discovery
- header parsing and layering
- artifact naming
- PDB/debug information
- linkstamps

Acceptance:

- Every action builds for x64 and ARM64.
- Alwayslink-only symbol remains in final PE.
- Import library can link a consumer.
- Explicit/generated DEF exports match.
- Header parser/layering catches undeclared includes on Windows.
- Linkstamp object has the MSVC target machine.
- PDB is declared, emitted, and referenced by the PE debug directory.

Raw MASM `.asm` remains unsupported; `.S` through Clang is supported.

Windows resources: currently no registered Bazel Windows-resource toolchain exists. `@llvm//tools:llvm-rc` remains a standalone tool and LLD can consume `.res`, but automatic resource compilation is outside this PR unless separately approved as a public toolchain addition.

### 6. ThinLTO, profile, coverage, FDO, sanitizers

Work:

- Validate upstream rule-based ThinLTO through the Clang driver.
- Add profile generation/runtime, source coverage, profile merge, and FDO-use tests.
- Add explicit sanitizer capability gates.

Required supported-and-tested set:

- ThinLTO
- profile instrumentation
- LLVM source coverage
- FDO profile use
- UBSan
- ASan, including its runtime DLL
- CFI with LTO
- libFuzzer
- libFuzzer + ASan

Both x64 and ARM64 unless an upstream LLVM runtime limitation is proven. Such a limitation becomes an explicit review blocker, not a silent exclusion.

Required analysis-time unavailable set:

- MSan
- DFSan
- NSan
- SafeStack
- RTSan
- TypeSan
- TSan
- LSan
- XRay
- GCC/gcov coverage mode
- Fission
- existing Windows OpenMP path remains unavailable

LLVM documents Windows support for UBSan and ASan, while TSan and MSan platform lists exclude Windows. [UBSan](https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html), [ASan](https://clang.llvm.org/docs/AddressSanitizer.html), [TSan](https://clang.llvm.org/docs/ThreadSanitizer.html), [MSan](https://clang.llvm.org/docs/MemorySanitizer.html).

ThinLTO is supported by COFF LLD; coverage/profile runtime behavior is documented for Windows. [ThinLTO](https://clang.llvm.org/docs/ThinLTO.html), [source coverage](https://clang.llvm.org/docs/SourceBasedCodeCoverage.html).

### 7. LLVM source bootstrap

Areas:

- `toolchain/bootstrap`
- `extensions/llvm.bzl`
- LLVM version overlays/patches
- compiler-rt source overlays

Work:

- Generate `lld-link` alias separately; keep `LLVM_TOOLS` as primary multicall tools `clang` and `lld`.
- Replace compiler-name-based MSVC source selection with target-ABI selection.
- Correct `CLANG_BUILD_STATIC` and BLAKE3 source selection.
- Verify/add the COFF distributed-ThinLTO weak-indirect-alias fix.
- Preserve the existing lazy-bitcode-index fix.
- Test `stage1_from_source` so stage-zero LLD cannot mask source patches.
- Port/version patches across LLVM 21, 22, and 23 overlays.

Acceptance:

- Stage-1-from-source Clang/LLD builds MSVC x64 and ARM64 ThinLTO binaries.
- No `clang-cl` primary bootstrap target.
- Generated alias is a declared action input.
- LLVM 21/default/23 analysis passes.
- Source-built and prebuilt toolchains produce equivalent machine/import/export behavior.

### 8. Regression matrix, CI, and documentation

Areas:

- `e2e/rules_cc`
- `e2e/cross_compilation`
- CI workflow
- README/public docs

Work:

- Add MSVC platforms and negative-analysis tests.
- Preserve MinGW UCRT and legacy-MSVCRT tests.
- Add action/artifact inspection scripts.
- Document EULA, the default-dynamic/opt-in-static feature contract, global target-configuration usage, the Phase-1 installed-redist prerequisite, unsupported features, and no clang-cl support.
- Document explicitly that `linkstatic`/`--dynamic_mode` choose ordinary dependency linkage and do not select `/MT`/`/MD`.
- Regenerate public docs only after behavior is demonstrated.

Review gate: README/public support contract before editing.

### Phase 2: hermetic app-local `/MD` DLL runfiles

This phase begins only after Phase 1 is working and reviewed. It is additive: no changes to the established target triples, compiler dialect, canonical CRT-selection features, or linked ABI.

Areas:

- upstream `windows_support`
- root `MODULE.bazel` and lockfile
- runtime routing and a feature-aware VC redistributable deployment adapter
- e2e application-local deployment tests

Work:

- Extend windows_support to preserve only the licensed architecture-specific retail VC redist payload required for app-local deployment.
- Expose logical VCRuntime and MSVC STL/concurrency DLL groups without exposing debug, MFC, ATL, localized, or unrelated payloads.
- Pin the resulting windows_support release and preserve EULA laziness.
- Route the selected target-architecture retail DLL group into Bazel's runtime closure only when `dynamic_link_msvcrt` is effective and `static_link_msvcrt` is absent.
- Do not key VC redistributable deployment on `linkstatic`, `--dynamic_mode`, `static_linking_mode`, `dynamic_linking_mode`, or the generic `static_link_cpp_runtimes` runtime attrs.
- If current rules_cc cannot add toolchain-owned DLL runfiles based on the effective feature configuration, implement or upstream the smallest explicit adapter rather than overloading `dynamic_runtime_lib` with incorrect semantics.
- Ensure DLLs are physically beside the executable, or in another demonstrated Windows loader search location; a data dependency alone is insufficient proof.
- Keep compiler-rt sanitizer/profile DLL deployment separately owned.

Acceptance:

- x64 and ARM64 `/MD` binaries run on clean target machines without a centrally installed VC Redistributable.
- `/MD` binaries receive the same required VC DLL closure for both static and dynamic ordinary dependency-link modes.
- `/MT` binaries receive no VC redistributable DLLs for either ordinary dependency-link mode.
- PE import inspection proves every non-system VC runtime/STL import is satisfied by the application-local layout.
- No debug or unrelated redistributable files enter the runfiles closure.
- Static `/MT` outputs and Phase-1 compile/link actions remain byte-for-byte or action-equivalent except for intentional runtime-deployment metadata.
- MinGW targets neither fetch nor receive VC redistributable payloads.
- Licensing/EULA failure is lazy, explicit, and occurs before redistributable acquisition.

## Action-graph inspection plan

For every architecture and MSVC CRT feature mode, assert:

- Compile executable is clang/clang++.
- Target triple is `*-pc-windows-msvc`.
- `-c`, `-o`, `-MD`, `-MF`, `-I`, `-isystem`, `-iquote`, and `-D` remain present.
- No `/c`, `/Fo`, `/showIncludes`, or clang-cl response quoting.
- Link executable is clang++ with `-fuse-ld=lld`.
- `lld-link` is a declared input but not the action executable.
- SDK/UCRT/VCRuntime/STL paths are separately visible.
- Default feature configuration enables `dynamic_link_msvcrt`; every compile action receives `-fms-runtime-lib=dll`.
- Global `--features=static_link_msvcrt` enables the static feature; every compile action receives `-fms-runtime-lib=static`, and no dynamic CRT argument remains effective.
- Transitive `cc_library`, linkstamp, and any other independently configured frontend actions use the same CRT feature mode; ThinLTO outputs retain matching COFF default-library directives even if backend actions do not expand the frontend-only flag.
- Varying `linkstatic` and `--dynamic_mode` changes only ordinary dependency linkage, never `-fms-runtime-lib`.
- Import library and PDB output paths are declared.
- DEF file reaches the driver.
- Archive uses llvm-ar deterministically.
- ThinLTO index/backend actions use COFF-correct paths and `NUL` behavior.
- Linkstamp compile retains target ABI.
- Exec platform never affects target library architecture.

## Output-artifact inspection plan

Use `llvm readobj`, `llvm objdump`, `llvm ar`, and `llvm pdbutil` to verify:

- AMD64 vs ARM64 machine type.
- PE executable/DLL subsystem.
- Static/alwayslink archive members and retained symbols.
- DLL exports and consumer import library.
- Explicit/generated DEF behavior.
- `/DEFAULTLIB` COFF directives.
- Static vs dynamic runtime imports.
- Absence of debug-runtime imports.
- Compiler-rt/profile/sanitizer runtime linkage.
- Phase-1 execution against a documented centrally installed compatible VC Redistributable.
- Phase-2 application-local deployed DLL closure.
- PDB existence and PE CodeView/debug-directory reference.
- ThinLTO output sections/symbols.
- MinGW UCRT API-set imports versus legacy `msvcrt.dll`.

The same reproduction/action inspection runs before and after each owning change.

## CI and exec/target matrix

| Exec | x64 MSVC | ARM64 MSVC | Depth |
|---|---|---|---|
| Linux x64 | Full build/aquery/artifacts, static+dynamic | Full cross-build/aquery/artifacts | Primary |
| Linux ARM64 | Cross-build smoke | Build smoke | Exec-independence |
| Windows x64 | Native build/run, static+dynamic with provisioned v14 Redistributable | Cross-build | Runtime x64 |
| Windows ARM64 | Cross-build | Native build/run, static+dynamic with provisioned v14 Redistributable | Runtime ARM64 |
| macOS x64 | Both target build smoke | Both target build smoke | Tool availability |
| macOS ARM64 | Both target build smoke | Both target build smoke | Tool availability |

Additional:

- Run the default-dynamic and global-static feature modes for every primary target row; do not model them as different target platforms.
- Add a focused four-way orthogonality matrix covering `/MD` and `/MT` against static and dynamic ordinary dependency-link modes.
- ThinLTO/profile/coverage/sanitizer runtime execution on native Windows x64 and ARM64.
- Stage1-from-source verification on Linux x64 for both targets.
- LLVM 21/default/23 analysis.
- Existing complete MinGW matrix unchanged.
- Bazel 8 and last release candidate where current CI already does both.
- Phase 2 adds clean-machine/app-local `/MD` execution jobs that do not depend on a centrally installed VC Redistributable.

## Risks and unresolved implementation proofs

- The existing windows_support build-time contract must be sufficient for Phase 1; any missing import/header granularity discovered by action inspection may still require a narrowly scoped upstream change.
- A windows_support redist release is a Phase-2 prerequisite only.
- Exact generic rules_cc import-library output behavior still needs an implementation spike.
- PDB output variable/declared-artifact handling must be proven.
- ASan ARM64 source-overlay completeness must be demonstrated.
- rules_cc's generic `dynamic_runtime_lib` follows ordinary link mode and therefore cannot be assumed to model `/MD`; Phase-2 feature-aware DLL propagation needs a focused implementation spike and may require a narrow upstream API.
- Bazel ignores feature names unknown to the selected toolchain. The documented static feature invocation must be scoped to an MSVC platform; arbitrary use on MinGW cannot be promised to fail analysis.
- A per-rule `features = ["static_link_msvcrt"]` does not provide target-graph consistency and remains intentionally unsupported as the public selection interface.
- COFF distributed ThinLTO weak-alias patch may differ by LLVM version.
- App-local VC redists are suitable for hermetic tests but need careful production/legal documentation.
- PR 709 must be green and remain the direct parent.
- Public constraint/platform names require approval.
- Automatic Windows resource compilation requires a separate explicit public-API decision.

## PR structure recommendation

One child PR stacked directly on PR 709, as requested. No further PR stack.

Internally: two reviewable phases and small ordered commits corresponding to the implementation steps above. Phase 1 establishes complete ordinary-Clang MSVC compile/link support with the explicit installed-redist execution contract. Phase 2 adds hermetic app-local `/MD` runfiles without revisiting Phase-1 architecture. This is larger than the repository’s normal stacking threshold, but the explicit single-feature/single-replacement-PR requirement takes precedence. Each commit remains independently reviewable and receives precise Titouan attribution only where applicable.

No implementation will begin until you explicitly approve this plan, including the proposed public constraint/platform contract and canonical MSVC CRT feature contract.
