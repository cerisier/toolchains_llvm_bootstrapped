# Windows MSVC ABI toolchain execution plan

This is a living execution plan. It records the approved architectural
direction, Phase 0 gates, stacked delivery boundaries, and the
evidence required before support is advertised. It does not authorize a public
API or README change by itself.

## 1. Current workspace and base state

Verified 2026-08-18:

- Worktree:
  `/Users/corentinkerisit/code/github.com/hermeticbuild/hermetic-llvm-msvc-phase0`
- Branch: `cerisier/windows-msvc-phase0`
- Pre-Phase-0-commit HEAD: `d2f5dd0f33aae9f52d34ba631540285b2d09b368`
- Local `origin/main`: `d2f5dd0f33aae9f52d34ba631540285b2d09b368`
- GitHub `main`: `d2f5dd0f33aae9f52d34ba631540285b2d09b368`
- Merge-base with `origin/main`: `d2f5dd0f33aae9f52d34ba631540285b2d09b368`
- PR 709: merged at `d2f5dd0f33aae9f52d34ba631540285b2d09b368`
- PR 709 final head: `05582142a2abdb7404942acd821c8b32844deb92`
- PR 709 checks: all reported checks green.
- PR 187: open; reviewed head
  `ef1eb169508b7f0461463c442e0e100ef575a90a`.
- rules_cc PR 561: open, merge state conflicting; reviewed
  head `35e469c8494389343cce5410030fb1af46709f6e`.
- Superseded critique and research reports remain recoverable from Git history;
  this document is their single current execution contract.
- The historical `cerisier/windows-msvc-clang` worktree and its unrelated
  untracked files remain untouched.
- Owner approval covered the base update and isolated Phase 0 worktree.
- The final PR 709 state is the exact implementation base.
- The unmodified baseline build, action query, MinGW build, and artifact
  inspection were rerun; exact evidence is in
  `.agents/execplans/windows-msvc-phase0.md`.

Review evidence, not a substitute for the post-update baseline:

- `cd e2e/rules_cc && bazel build --config=remote //:main` passed.
- A Windows x86-64 target action executed on Linux AArch64 RBE. This proves
  that execution platform and target platform must remain independent.
- Existing MinGW outputs included `main_default.exe`,
  `windows_explicit_def.dll`, and `libcomm_symbol_static_lib.a`.
- COFF/PE inspection confirmed AMD64 output, UCRT API-set and `KERNEL32.dll`
  imports, expected DLL exports, and `.pic.o` archive members.

## 2. Product and support contract

### MSVC ABI tool suite

For `//constraints/windows/abi:msvc`:

- toolchain compiler identity: `clang-cl`;
- C and C++ frontend executable: direct `clang-cl`;
- initial static librarian: direct `llvm-ar` with deterministic `rcsD`;
- executable and DLL link action: `clang-cl`, selecting the declared sibling
  `lld-link` through the driver;
- explicit target triple on every frontend action;
- explicit machine type on link actions and, after Layer 4, librarian actions;
- CL-compatible compile arguments, with only audited `/clang:` escapes;
- GNU-compatible initial `llvm-ar` arguments;
- LINK-compatible `linkopts`, individually forwarded by the driver with
  response-safe `/clang:-Xlinker` pairs where required;
- no MinGW headers, libraries, startup objects, pseudo-relocation, auto-import,
  or GNU linker mode;
- no Microsoft `cl.exe`, `lib.exe`, or `link.exe` discovery.

For `gnu`, `gnullvm`, and compatibility-fallback Windows ABIs:

- retain ordinary Clang/Clang++;
- retain `llvm-ar`;
- retain GNU-driver linking through LLD;
- retain current MinGW UCRT and legacy-MSVCRT behavior unchanged.

`llvm-lib` is not a core correctness prerequisite. `llvm-ar rcsD` already
produces deterministic archives containing COFF objects that `lld-link`
consumes. Layer 4 changes the librarian command-line personality for Microsoft
LIB parity; it must not change archive semantics.

Decision rationale:

- hermetic-llvm's established model lets the Clang driver select LLD and
  toolchain runtimes from declared resource/library directories. MSVC follows
  that model through clang-cl; project-owned COFF adapters remain only for
  LINK-specific rules_cc surfaces such as whole archive, import libraries,
  PDBs, and subsystems.
- LLD's GNU Windows frontend deliberately selects MinGW mode, including
  auto-import, pseudo-relocation, and MinGW startup/runtime assumptions. Using
  it for MSVC objects would require suppressing and re-proving that entire
  environment.
- clang-cl selects lld-link while preserving the established CL/LINK dialect.
  This keeps runtime and linker selection in the driver without relying on a
  GNU Windows frontend or host Visual Studio discovery.
- Microsoft cl.exe, lib.exe, and link.exe remain outside scope because they
  would make the hermetic Linux/macOS cross-execution contract host-dependent.

### Target and execution separation

- Exec OS/CPU selects a runnable tool binary only.
- Target OS/CPU/ABI selects output triple, machine type, SDK libraries, runtime
  libraries, and artifact semantics only.
- Target CPU, never exec CPU, selects x64 versus ARM64 SDK/runtime inputs.
- Every executable, SDK file, runtime, response file, and generated output used
  by an action is declared.
- `PATH`, Visual Studio, host SDK, and host linker discovery are forbidden.

### Initial C++ standard library

The first public MSVC milestone uses libc++ with VCRuntime:

- libc++ uses its Microsoft ABI implementation; upstream supports
  `LIBCXX_CXX_ABI=vcruntime`, and `_WIN32 && _MSC_VER` selects that ABI path;
- VCRuntime headers and libraries supply ABI/runtime support;
- `_LIBCPP_NO_VCRUNTIME` is not selected: VCRuntime interoperability is the
  intended contract, and disabling it restricts replacement `operator new`
  and `operator delete` cases;
- a curated VCRuntime header subset supplies ABI headers such as
  `vcruntime_new.h`, after libc++ in include-search order; Microsoft STL
  headers are not declared compiler inputs;
- libc++abi and libunwind are absent;
- MinGW inputs and Microsoft STL headers are absent; the only Microsoft-STL
  binary input permitted on the libc++ route is upstream libc++'s narrow
  Microsoft C++ runtime ABI helper provider: `msvcprt.lib`/`msvcp*.dll` for
  `/MD` or `libcpmt.lib` for `/MT`;
- libc++ ABI-affecting configuration and cache identity are pinned by LLVM
  source revision, ABI version/defines, hardening mode, exception/RTTI/thread/
  filesystem configuration, target architecture, and CRT mode;
- Windows MSVC libc++ is configuration-wide static. Consumer compilation
  disables DLL visibility annotations, and ordinary dependency `linkstatic`
  or dynamic mode does not select a different libc++ artifact;
- libc++'s upstream Microsoft-ABI auto-link selects static `libc++.lib` from a
  declared target library directory; no shared libc++ artifact is exposed;
- the library directory is a declared link input, while the driver/COFF
  directive selects the artifact name.

That narrow helper dependency does not select Microsoft STL as the standard
library. It supplies libc++'s Microsoft-ABI `exception_ptr` operations and
uncaught-exception state; libc++ still owns every public standard-library
header and type. Make only the CRT-matched provider reachable through the
selected filtered library directory, prove its exact imported helper surface,
and reject every other Microsoft-STL header or library input on the libc++
route.

Clang-cl's `/MD` and `/MT` defaults do not name that C++ helper provider.
Libc++ therefore owns the narrow dependency through a CRT-selected COFF
dependent-library directive in its archive members. The filename is absent
from Bazel's final-link argv and resolves only from the filtered declared
directory; this does not select Microsoft STL headers or its full closure.

Microsoft STL as the selected complete standard library is the second stack
layer. Do not expose
`//constraints/cxxstdlib:msvc` before that route works end-to-end.
Its established `/MD` route normally uses DLL/import-library form and `/MT`
uses static form. Do not promise an independent Microsoft-STL linkage selector
without upstream evidence.

The implication is one-way:

```text
cxxstdlib = msvc  =>  windows ABI = msvc
windows ABI = msvc  !=>  cxxstdlib = msvc
```

libstdc++ is never an MSVC-ABI option.

The supported interoperability boundary is C, Win32, COM, and focused
Microsoft-ABI C++ interfaces that do not expose standard-library types. Do not
pass strings, containers, streams, allocators, or library-specific exceptions
between libc++ and Microsoft-STL code. An arbitrary Visual Studio library that
exposes `std::*` requires Microsoft STL; libc++'s MSVC-environment ABI is not a
drop-in Microsoft-STL ABI and is not generally stable across LLVM
configurations.

### CRT linkage

CRT linkage is configuration-wide and independent from ordinary dependency
linkage:

- `dynamic_link_msvcrt`: default retail `/MD`;
- `static_link_msvcrt`: opt-in retail `/MT`, suppressing dynamic behavior;
- `linkstatic`, `--dynamic_mode`, `static_linking_mode`,
  `dynamic_linking_mode`, and `static_link_cpp_runtimes` do not choose `/MD`
  versus `/MT`;
- a per-rule `features` attribute is not a supported CRT selector because it
  does not propagate to independently compiled dependencies;
- each selected CRT mode receives its own filtered declared library directory;
  `/MD` or `/MT` and normal COFF default-library directives select the runtime
  closure from that directory;
- do not emit `/NODEFAULTLIB` or enumerate the CRT closure in Bazel link argv;
- `--compilation_mode=dbg` continues to use the selected retail CRT;
- `/MDd`, `/MTd`, debug CRT libraries, and `_DEBUG` are unsupported until
  separately approved.

The canonical feature/default-library names are historical. Modern `/MD`
composition includes UCRT and VCRuntime, optionally an STL; it does not mean
the legacy MinGW `msvcrt.dll` environment selected by
`//constraints/windows/crt:msvcrt`.

The current unconditional `-D_DEBUG` behavior under `dbg` must become
ABI/runtime-aware. Required clang-cl behavior:

| Flag | Required macros | Required COFF default library |
|---|---|---|
| `/MD` | `_MT`, `_DLL`; no `_DEBUG` | `msvcrt.lib` |
| `/MT` | `_MT`; no `_DLL`, no `_DEBUG` | `libcmt.lib` |

Phase 0 must choose and test behavior when both CRT features are enabled and
when dynamic is disabled without static. No silent fallback.

Core `/MD` compile and link actions remain hermetic, but native execution
requires a compatible target-architecture Microsoft Visual C++ v14
Redistributable at least as recent as the selected toolset. Bazel analysis
cannot reliably detect that target-machine prerequisite. `/MT` native tests
must prove the corresponding VC redistributable DLLs are absent. App-local
deployment remains the independent follow-up in Section 20.

### libc++ artifact and CRT compatibility

| libc++ artifact | `/MD` | `/MT` |
|---|---:|---:|
| Static libc++ | supported after proof | supported after proof |
| Shared libc++ | deferred; no Layer 1 route | deferred; no Layer 1 route |

Ordinary dependency `linkstatic` remains independent. Both ordinary static and
dynamic linking modes consume `libc++.lib`; neither exposes `c++.dll` or its
import library. Dynamic libc++ requires a future configuration-wide consumer
annotation and deployment contract.

### Determinism and security claims

The architecture is safer because clang-cl and its selected lld-link child use
their native CL/LINK dialects with declared inputs. It is not automatically a
security-hardening feature.

Required deterministic contract:

- `/Brepro` on compile and link actions;
- deterministic `llvm-ar rcsD` archives;
- deterministic Layer 4 `llvm-lib` archives;
- redacted `__DATE__`, `__TIME__`, and `__TIMESTAMP__`;
- deterministic compilation-directory and path maps;
- stable response-file ordering and encoding;
- reproducible PDBs with inspected path privacy;
- repeated hashes after time separation and, where meaningful, across exec
  hosts.

Any product security claim additionally requires explicit tests for ASLR, NX,
high-entropy addresses, optional Control Flow Guard, `/PDBALTPATH`, host-path
and timestamp absence, and undeclared-host-input absence. Until then, claim
only a safer architecture.

### Scope boundaries

Initial support covers rules_cc C and C++ actions only.

- rules_foreign_cc: unsupported until it can model clang-cl driver links with
  a declared sibling lld-link and separate llvm-ar actions.
- `.rc` and manifest tooling: outside scope pending a resource toolchain.
- MASM `.asm`: outside scope pending `llvm-ml` action modeling.
- Preprocessed `.S`: supported only after direct proof.
- ObjC/ObjC++, C++ modules, OpenMP, arbitrary Microsoft-STL C++ interfaces on
  a libc++ platform: not implied.
- Minimum Windows OS version and default subsystem: Phase 0 decision.
- User `copts`: clang-cl syntax on MSVC platforms.
- User `linkopts`: LINK/lld-link syntax forwarded through clang-cl on MSVC
  platforms.
- App-local VC redistributables: independent later work.
- ThinLTO, profile/coverage, FDO, and CFI: independent later work except a
  prerequisite explicitly owned by the sanitizer layer.

## 3. Public platform and compatibility contract

Public constraint/platform changes require explicit approval before
implementation or README edits.

### Proposed platform defaults

- `@llvm//platforms:windows_x86_64_msvc`: MSVC ABI plus libc++.
- `@llvm//platforms:windows_aarch64_msvc`: MSVC ABI plus libc++.
- Existing `windows_x86_64` and `windows_aarch64`: unchanged MinGW UCRT.
- Existing explicit GNU platforms: unchanged.
- Layer 2 must decide whether to add named `*_msvc_stl` platforms or require a
  custom platform selecting `//constraints/cxxstdlib:msvc`.

Platform names describe ABI/toolchain, not Microsoft STL.

### Windows CRT constraint decision

Preferred Phase 0 decision:

- MSVC ABI selects `//constraints/windows/crt:ucrt` because modern MSVC uses
  UCRT;
- `//constraints/windows/crt:msvcrt` remains MinGW-only and invalid with MSVC
  ABI;
- every current MinGW CRT consumer becomes ABI-aware so `ucrt` never injects
  MinGW files into MSVC actions;
- `/MD` and `/MT` remain features, not platform constraints;
- do not add the ambiguous `windows/crt:not_applicable` value.

If `windows/crt` is actually intended as a MinGW-provider selector, rename or
document that setting before adding a non-applicable value. Record the approved
meaning in Phase 0.

### ABI, standard-library, and CRT matrix

| Windows ABI | C++ stdlib | Windows CRT | Result |
|---|---|---|---|
| unconstrained/gnu/gnullvm | libc++ | ucrt | Existing MinGW UCRT |
| unconstrained/gnu/gnullvm | libc++ | msvcrt | Existing legacy MinGW `msvcrt.dll` |
| msvc | libc++ | ucrt | Layer 1 supported route |
| msvc | Microsoft STL | ucrt | Layer 2 supported route |
| msvc | libstdc++ | any | Analysis error |
| non-msvc | Microsoft STL | any | Analysis error |
| msvc | either supported STL | msvcrt | Analysis error |
| x86/ARM32/ARM64EC target | any | any | No registered toolchain |

### CRT feature-state matrix

| State | Required behavior |
|---|---|
| Default | `/MD`; `msvcrt.lib`; retail CRT |
| `static_link_msvcrt` | `/MT`; `libcmt.lib`; dynamic behavior suppressed |
| Both enabled | Phase 0 chooses static-wins or stable analysis error |
| Dynamic disabled; static absent | Stable analysis error |
| `dbg` plus either mode | Same retail CRT; `_DEBUG` and `*d.lib` absent |

### Standard-library selection matrix

| Windows ABI | C++ stdlib | Contract |
|---|---|---|
| MSVC | libc++ | Layer 1 default; VCRuntime ABI |
| MSVC | Microsoft STL | Layer 2 alternative |
| MSVC | libstdc++ | Analysis error |
| GNU/gnullvm | libc++ | Existing MinGW behavior |
| GNU/gnullvm | Microsoft STL | Analysis error |

Repository-owned transitions and closures must preserve ABI, STL, CRT mode,
and the static Windows MSVC libc++ selection. Analysis can reject mixed repository-owned
routes; it cannot infer the ABI of arbitrary opaque prebuilt libraries. State
that limitation explicitly.

## 4. Target and execution component ownership

| Component | Semantic owner | Required routing |
|---|---|---|
| Windows ABI/triple | PR 709 constraint/platform config | ABI-authoritative; preserve GNU fallback |
| Compiler identity | hermetic-llvm toolchain | `clang-cl` only for MSVC ABI |
| Frontend executable | hermetic LLVM tool maps | Direct clang-cl |
| Initial librarian | hermetic LLVM tool maps | Direct llvm-ar `rcsD` |
| Final librarian dialect | Layer 4 | llvm-lib personality for MSVC ABI only |
| Linker | LLVM LLD | clang-cl-selected declared sibling lld-link |
| Exec binary selection | tool repository/exec constraints | Exec OS/CPU only |
| Target machine selection | target constraints | x64/ARM64 only |
| Windows SDK/UCRT | windows_support | Declared include and library components |
| VCRuntime | windows_support MSVC payload | Declared headers/libraries |
| libc++ | hermetic-llvm runtime build | Microsoft ABI; no libc++abi/libunwind |
| Microsoft STL | Layer 2 + windows_support | `cxxstdlib:msvc` route |
| CRT linkage | Bazel C++ features | Default `/MD`; opt-in `/MT` |
| Ordinary dependency linkage | rules_cc | Independent `linkstatic`/dynamic mode |
| VC redistributables | target prerequisite / later deployment | Not a compile/link input shortcut |
| compiler-rt | hermetic-llvm source runtimes | Exact MSVC resource manifest |
| Artifact naming | hermetic-llvm toolchain | `.obj`, `.lib`, alwayslink form, `.exe`, `.dll`, import library |
| CL/LINK arguments | local rules_cc adapter | ABI-isolated project-owned targets |
| Import library/PDB | link action | Declared outputs, not incidental files |
| Header parsing | rules_cc + portable parser | Same tool/dialect and chosen dependency protocol |
| Source bootstrap | LLVM overlays | Same tool aliases and target semantics as prebuilts |

## 5. Local rules_cc adapter ownership

Pinned compatibility baseline: rules_cc `0.2.22`, as declared in
`MODULE.bazel`.

rules_cc's native Windows toolchain is a behavioral reference, not a complete
drop-in rule-based clang-cl implementation. hermetic-llvm owns the MSVC
rule-based adapter needed for its support matrix.

The adapter:

- uses `cc_args`, `cc_nested_args`, `cc_feature`, and `overrides`;
- is selected by MSVC target ABI, never exec OS;
- is aggregated separately from GNU/MinGW arguments;
- implements the complete supported CL, llvm-ar, and LINK surfaces;
- registers defaults exactly once;
- gives unsupported actions stable capability errors where possible;
- does not wait for rules_cc PR 561;
- does not depend on an unpublished rules_cc revision;
- does not remove local behavior merely because a future upstream equivalent
  exists.

Compatibility obligations:

1. Record every overridden rules_cc label, variable, action set, capability,
   default feature, and legacy backfill used at 0.2.22.
2. Maintain local argument-expansion and feature-state goldens as the normative
   contract.
3. Maintain end-to-end `aquery` tests for executable, inputs, outputs,
   execution platform, environment, and response files.
4. On every rules_cc version bump, rerun the full protocol inventory and a
   differential comparison against the previous pin.
5. Detect upstream label/default/backfill changes that could duplicate or
   suppress local arguments.
6. Treat migration to a future upstream implementation as a separate,
   behavior-preserving refactor with action and artifact equivalence proof.

`cc_feature(overrides = ...)` is not evidence alone. Tests must show the GNU
expansion occurs zero times, the MSVC replacement occurs exactly once, and no
legacy backfill restores the overridden form.

## 6. rules_cc protocol and capability audit

Phase 0 must classify each row as `reuse`, `local replacement`, `deliberate
no-op`, or `unsupported error`. Layer 1 must turn every supported row into an
argument golden plus end-to-end action assertion.

| Protocol surface | Required disposition/evidence |
|---|---|
| Toolchain identity | `compiler = "clang-cl"`; exact MSVC feature set; no exec-OS inference |
| Action tool map | clang-cl compile/final-link driver; llvm-ar archive through Layer 3; declared sibling lld-link child; no fallthrough |
| Compiler input | `/c` plus source; correct ordering for compile, linkstamp, preprocess, assembly dispositions |
| Compiler outputs | `/Fo`, `/Fa`, `/P` plus `/Fi` only for supported declared outputs |
| Language selection | Correct C/C++ mode; no C++-only flags on C actions |
| Defines/includes | `/D`, `/U`, `/I`, `/FI`, `/imsvc` or proven external include equivalent; quote/system semantics |
| User flags | clang-cl `copts`; LINK `linkopts` forwarded individually through the driver; ordering proven |
| Dependency protocol | One coherent `.d` or ShowIncludes path; never hybrid |
| Compiler response files | clang-cl syntax, quoting, encoding, declared input, remote/local paths |
| Archive response files | llvm-ar syntax initially; deterministic `rcsD` plus output/input expansion |
| Link response files | clang-cl driver syntax with audited LINK forwarding; child spill files and ThinLTO files kept distinct |
| Windows quoting | Separate proof for clang-cl, llvm-ar, lld-link on every exec OS; llvm-lib deferred |
| Archive expansion | Objects/groups expanded for llvm-ar; Layer 4 replaces only this boundary |
| Libraries to link | Objects/groups/static/interface/dynamic forms; `/WHOLEARCHIVE:` only for alwayslink |
| Link outputs/options | `/OUT`, `/DLL`, `/LIBPATH`, `/SUBSYSTEM`, `/MACHINE`, `/DEF`, `/IMPLIB`, `/DEBUG`, declared PDB, determinism; explicit `/PDB` only when rules_cc exposes its path |
| Interface libraries | `supports_interface_shared_libraries`, real output variable, generated import library, DLL copying proven together |
| Artifact patterns | `.obj`, `.lib`, approved alwayslink name, `.exe`, `.dll`, declared import-library suffix |
| Tool capabilities | No MSVC PIC claim; exact configured-linker, Windows, dynamic-linker, header-parser, param-file capabilities |
| Known/default features | Every override registered; defaults enabled once; bootstrap runtime toolchains get only supported subset |
| ThinLTO action split | Explicit frontend/index/backend/final tools and dialect; unsupported until independently proved |
| Linkage dimensions | CRT features, C++ runtime linkage, `linkstatic`, and dynamic mode remain orthogonal |
| Unsupported generic features | Explicit disposition for PIC, soname, rpath, fission, GNU strip/coverage, start/end-lib, fully-static, ObjC, modules, assembly |

Minimum local replacements or neutralizations:

- compiler input and every supported output form;
- definitions, forced includes, include classes, and external includes;
- dependency-file handling;
- archive creation and archive inputs;
- link output, DLL mode, library paths, and every libraries-to-link form;
- DEF, import-library, and interface-library handling;
- PIC, random seed, soname, strip, runtime search paths, and other GNU-only
  expansions;
- ThinLTO link/index/backend arguments before ThinLTO can be claimed.

Protocol switches requiring independent positive and negative tests:

- `compiler_param_file`;
- `archive_param_file`;
- linker param-file feature;
- `windows_quoting_for_param_files`;
- `supports_dynamic_linker`;
- `has_configured_linker_path`;
- `supports_interface_shared_libraries`;
- `targets_windows` and `copy_dynamic_libraries_to_binary` behavior;
- `supports_header_parsing` and parser tool path;
- `no_dotd_file` plus `parse_showincludes`, only if ShowIncludes is selected;
- `supports_start_end_lib`, whose real Bazel behavior must be resolved before
  ThinLTO is claimed.

### Dependency and header-parsing gate

Compare:

1. `/showIncludes`, `VSLANG=1033`, `parse_showincludes`, and `no_dotd_file`;
2. clang-cl `/clang:-MD`, `/clang:-MF`, and `/clang:<dependency-file>` with
   normal `.d` consumption.

Select one. Required cross-host proof: remote execution, declared outputs,
spaces, colons, non-ASCII paths, missing/stale-header rebuilds, and no
host-local parser dependency.

Header parsing must use a coherent tool/argument pair:

- route the action through clang-cl with the selected dependency protocol; or
- keep the wrapper with separately translated GNU arguments and explicit
  target/SDK inputs.

Never run the clang++ wrapper with clang-cl-only `/c` arguments.

## 7. PR 187 and rules_cc PR 561 adoption contract

PR 187 got most of the intended Windows stack working end to end. Treat it as
the first implementation reference and mine its working pieces before
inventing replacements. It is still a prototype and requirements source, not
a cherry-pick unit: some concepts are too tightly coupled and some paths take
shortcuts that must be separated or hardened against this plan's contracts.
PR 561 is a design/provenance reference and behavioral oracle, not a
dependency.

### Adopt or reimplement from PR 187

- distinct clang-cl compiler identity;
- separate prebuilt, staged, and runtime-building MSVC tool maps;
- deterministic direct `llvm-ar rcsD` archive path;
- ABI-specific CL/LINK argument aggregation;
- `.obj`, `.lib`, DLL, and import-library artifact categories;
- `/DEF`, `/IMPLIB`, `/OUT`, `/DLL`, `/LIBPATH`, `/WHOLEARCHIVE` expansions;
- SDK/VCRuntime include and library data;
- portable Windows-host header parsing where still needed;
- no PIC or ELF runtime-search behavior on MSVC actions;
- source aliases that cannot accidentally use stage-zero tools;
- targeted `CLANG_BUILD_STATIC`, BLAKE3 MSVC source selection, and COFF
  distributed-ThinLTO weak-indirect-alias obligations when their owner layer
  is reached.

### Reject or deliberately diverge from PR 187

- stale ABI/platform work superseded by PR 709;
- `/MDd`, `/MTd`, and `_DEBUG` under ordinary `dbg`;
- blanket sanitizer disablement;
- `/I` flattening of every system/external include class;
- broad unused-argument suppression hiding dialect errors;
- policy-only `/Zm500`, blanket warning disables, deprecation macros, and
  unproved module features;
- empty no-op features presented as supported;
- global non-MSVC argument rewrites;
- GNU fallback triple changes;
- unexplained LLVM source exclusions;
- MinGW collateral unrelated to a reproduced MinGW bug;
- premature README support claims.

### Non-cc_args PR 187 disposition

| Area | Disposition |
|---|---|
| ABI/platform generation | Use final PR 709 state |
| windows_support extension/lockfile | Reimplement against approved current pin, integrities, root precedence, lazy EULA |
| compiler-rt resource mapping | Adapt to exact MSVC triples/names by LLVM major |
| libc++/libc++abi/libunwind routing | Replace with libc++/VCRuntime contract |
| compiler-rt source filters | Re-derive from pinned LLVM sources; justify each omission |
| OpenMP | Explicitly unsupported initially |
| MinGW PIC/archive/import changes | Discard absent independent reproduction |
| source archive exclusions | Reject absent owning requirement |
| header parser portability | Adapt only if selected protocol needs it |
| README matrix | Update only after owning proof and approval |

### Provenance

Reviewed PR 187 author identity:

```text
Titouan Bion <titouan.bion@gmail.com>
```

Maintain a per-commit provenance map:

- materially adapted PR 187 implementation: Titouan co-author trailer;
- independently reimplemented behavior: acknowledge PR 187 in PR description;
- code ported from PR 561: exact source commit plus Apache provenance;
- unrelated original work: no blanket trailer;
- never attribute the same copied block ambiguously to both prototypes.

## 8. Phase 0 decision and spike gate

Phase 0 changes no public product behavior. It completes the evidence ledger
and freezes the shared architecture before Layer 1.

### Already decided

- MSVC ABI selects clang-cl compilation and driver links, llvm-ar archives,
  and a declared sibling lld-link child.
- MinGW retains ordinary Clang + llvm-ar + GNU-style linking.
- libc++/VCRuntime is the first complete MSVC C++ environment.
- Microsoft STL is the second layer.
- Sanitizers follow both standard libraries and must work with both.
- llvm-lib is the final dialect-only layer, not a core blocker.
- hermetic-llvm owns its pinned-rules_cc MSVC adapter.
- retail `/MD` is default; retail `/MT` is opt-in; debug CRT unsupported.
- every public layer is independently useful; C-only/compile-only progress is
  internal to Layer 1.

### Reproduced facts

- `MODULE.bazel` pins rules_cc 0.2.22.
- `tools/defs.bzl` exposes `clang-cl`, `lld-link`, and `llvm-ar`; it does not
  expose `llvm-lib`.
- prebuilt tool mapping contains clang-cl/lld-link/llvm-ar paths; bootstrap
  `LLVM_TOOLS` omits llvm-lib.
- local clang-cl `/MD` and `/MT` probes produced the macro/default-library
  contract recorded above.
- clang-cl `/Brepro` zeroed the COFF timestamp and repeated object output
  matched; omission preserved the current timestamp.
- clang-cl produced a valid `.d` file through audited `/clang:` escapes.
- `/showIncludes` produced the expected English prefix in the reviewed probe.
- generic rules_cc whole-archive arguments are invalid for the lld-link child;
  MSVC needs driver-forwarded `/WHOLEARCHIVE:` expansion.
- `3rd_party/llvm-project/x.x/libcxx/libcxx.BUILD.bazel` contains upstream
  Microsoft-ABI machinery, but its current Windows dependencies still route
  through `@mingw//:mingw_headers`.
- `runtimes/cxxstdlib/BUILD.bazel` currently routes Windows libc++ through
  libc++abi/libunwind, hard-codes an ELF `.so`/soname shared artifact, lacks
  dynamic Windows libc++ routing, and rejects Windows libstdc++.
- That current routing therefore does not satisfy the MSVC libc++ contract;
  COFF static, DLL, and import-library outputs require an owning port rather
  than artifact renaming.
- current runtime resource names are MinGW-style `libclang_rt.*`; Clang's MSVC
  lookup expects names such as `clang_rt.builtins.lib`.
- Bazel ignores an unknown requested feature in the reviewed Bazel baseline;
  omission alone cannot implement an unsupported-capability error.
- The Bazel Central Registry currently lists windows_support `0.2.0` as its
  newest release. Its module defaults pin MSVC `14.50.35717`, Windows SDK
  `10.0.26100.7705`, exact manifest/package integrities, and x64/ARM64.
- windows_support `0.2.0` keeps only MSVC `include` and `lib`, so `VC/Redist`
  is unavailable; this blocks only the independent app-local deployment work.
- windows_support exposes a broad VC include tree and per-architecture library
  trees. Its SDK exposes UCRT/shared/UM/WinRT components and transformations,
  while its own README still describes case-sensitive support as limited.

### Recorded decisions and final host spike

The authoritative command/output evidence, fact/inference classification, and
final decision for every item are recorded in
`.agents/execplans/windows-msvc-phase0.md`; the rules_cc/provenance detail is in
`.agents/execplans/windows-msvc-rules-cc-0.2.22.md`. Decisions are frozen; the
native Linux/macOS/Windows x x86-64/ARM64 workflow passed in GitHub Actions run
32047134011, attempt 2, completing the final Phase 0 execution gate.

1. approved branch update and implementation base;
2. public platform names and Microsoft-STL exposure;
3. UCRT reuse versus clarified/replaced Windows CRT constraint semantics;
4. static-wins versus analysis error when both CRT features appear;
5. dynamic-disabled/static-absent error mechanism;
6. full rules_cc 0.2.22 protocol inventory and upgrade-drift test design;
7. exact PR 187/PR 561 source map;
8. clang-cl, llvm-ar, and lld-link delivery and local execution on Linux
   x64/ARM64, macOS x64/ARM64, Windows x64/ARM64;
9. `.d` versus ShowIncludes dependency protocol;
10. independent compiler/archive/link response-file quoting and encoding;
11. header-parser action/tool coherence;
12. `supports_start_end_lib` semantics and unsupported-feature error mechanism;
13. explicit SDK directory model versus coherent `/winsysroot` topology;
14. case-correct header/library transformations on Linux/macOS;
15. declared `interface_library_output_path` and import-library contract;
16. declared PDB output/default-name contract;
17. static libc++ name, absent shared/import artifacts, and auto-link policy;
18. pinned libc++ ABI site configuration by LLVM line;
19. Microsoft-STL platform, library, debug, iterator-debug, redistribution
   contract;
20. full STL x CRT x libc++-linkage matrix;
21. sanitizer x STL x architecture x CRT x output-kind matrix and
   compiler-rt-internal C++ closure strategy;
22. llvm-lib basename/argv[0] personality alias on all claimed exec hosts;
23. minimum Windows version and subsystem policy;
24. EULA, Microsoft payload redistribution, CI repository environment, and
   secret handling authorization;
25. four-layer stack approval required by repository policy.

Any later contradiction reopens the owning gate. Items 1-18, 23-25 block Layer
1; item 19 blocks Layer 2; items 20-21 block Layer 3; item 22 blocks only Layer
4.

### Phase 0 deliverables and commands

Checked-in before Layer 1 begins:

- `.agents/execplans/windows-msvc-phase0.md`: command/output decision ledger;
- `.agents/execplans/windows-msvc-rules-cc-0.2.22.md`: protocol inventory and
  PR provenance map;
- `tools/msvc_tool_probe/`: Go direct-tool, response-file, path, dependency,
  `/Brepro`, and llvm-lib-personality probes;
- `tools/msvc_action_assert/`: Go JSON `aquery` assertions;
- `tools/msvc_artifact_assert/`: Go COFF/PE/archive/PDB assertions.
- `MODULE.bazel`: rules_go 0.62.0 is a normal dependency so these targets are
  usable when the module is consumed, not only in the root development module.

These Go probes are Phase 0 development scaffolding, not permanent public test
interfaces. Layer 1 may retire them after their important observable contracts
are covered by smaller Bazel behavior, action, analysis-failure, and artifact
tests consistent with the rest of the repository.

Required baseline:

```sh
cd e2e/rules_cc
bazel build --config=remote //:main
bazel aquery --config=remote --include_param_files //:main \
  --output=jsonproto > /tmp/msvc-plan-baseline-aquery.json
```

The checked-in probe tools must provide hermetic Bazel test targets; direct
commands are diagnostic evidence, not the eventual CI interface.

Phase 0 review gate: every item has a recorded decision, the public API and
stack are approved, and no delivery prerequisite is assumed.

Phase 0 stop conditions: missing legal/EULA authority, missing core tool on a
claimed exec host, unrepresentable declared output, unresolved SDK case model,
or unapproved public semantics.

## 9. Layer ownership, mergeability, and conflict contract

This exceeds the repository's 300-400-line stack threshold. Do not create an
implementation branch or worktree until this Stack Plan receives explicit
approval.

### Proposed Stack Plan

Trunk: current GitHub `main` after the approved Phase 0 update.

1. `cerisier/windows-msvc-libcxx` — complete clang-cl + llvm-ar + lld-link,
   SDK/UCRT/VCRuntime, and libc++ MSVC core.
2. `cerisier/windows-msvc-stl` — Microsoft STL as a complete alternative;
   libc++ unchanged.
3. `cerisier/windows-msvc-sanitizers` — proven compiler-rt sanitizers with
   both standard libraries.
4. `cerisier/windows-msvc-llvm-lib` — librarian dialect switch from llvm-ar
   to llvm-lib; behavior unchanged.

All PRs are draft and submitted with non-interactive `gh stack submit --auto`.
Before use, inspect `gh stack <command> --help`. Do not use `gh stack modify`,
`gh stack switch`, or hand-maintained PR bases.

Each layer uses its own branch and absolute worktree. At activation, record the
exact parent commit, branch, and worktree in the layer's Goal Record. No layer
starts with an unresolved parent SHA.

### Mergeability definition

Each layer leaves `main` with a complete documented capability. Compile-only,
C-only, incomplete runtime, or exposed-but-unusable constraint/platform work
may be internal Layer 1 commits; none is a public merge boundary.

Layers share registration, argument, runtime, and CI surfaces. “Mergeable”
does not mean conflict-free. Resolve stack conflicts bottom-up and rerun the
child layer's full unchanged-surface checks after every parent update.

Layer 1 freezes these seams:

- one STL selection boundary, initially populated by libc++;
- unavailable sanitizer capability hooks that never succeed as no-ops;
- one archive tool/argument boundary, initially llvm-ar;
- shared action/artifact assertion helpers;
- transitions preserving ABI, CRT, STL, and libc++ artifact selection.

Later ownership is narrow:

- Layer 2 fills Microsoft STL routing; it does not redesign CL/LINK actions.
- Layer 3 fills compiler-rt capabilities; it does not change unsanitized
  STL/CRT routing.
- Layer 4 changes only MSVC archive executable/arguments; it does not change
  target matrix or archive output contract.

### Goal Record required before activation

Every layer records:

- exact objective;
- exact parent branch and commit;
- exact task branch and absolute worktree;
- scope and non-goals;
- owned invariant;
- baseline reproduction;
- named positive and negative scenarios;
- exact Bazel labels and commands;
- action assertions;
- artifact assertions;
- exec/target/runtime matrix;
- allowed file areas;
- review gate;
- stop conditions;
- commit, draft PR, and handoff evidence.

## 10. Layer 1 / Goal 1: complete MSVC plus libc++ core

### Objective

Deliver the first independently useful MSVC ABI product slice: hermetic
clang-cl compilation and driver links, deterministic llvm-ar archives,
clang-cl-selected lld-link, Microsoft SDK/UCRT/VCRuntime, and libc++ for x64
and ARM64.

### Proposed Goal Record

- Parent: approved post-Phase-0 `main`; exact SHA recorded before activation.
- Branch: `cerisier/windows-msvc-libcxx`.
- Worktree: `/Users/corentinkerisit/code/github.com/hermeticbuild/hermetic-llvm-msvc-libcxx`.
- Owned invariant: an MSVC+libc++ platform has one coherent ABI/CRT/STL
  contract through every action, runtime transition, and output.
- Non-goals: Microsoft STL as the selected standard library, sanitizer
  enablement, llvm-lib dialect, app-local VC redistributables,
  rules_foreign_cc, resources/MASM, advanced instrumentation except required
  C-only spikes. The CRT-selected Microsoft C++ runtime ABI helper provider is
  the sole Microsoft-STL-runtime exception.

### Internal implementation order

1. Rebase onto final PR 709 state; freeze approved platform and CRT semantics.
2. Pin windows_support, payload versions, integrities, transformations, and
   lazy root-module/EULA behavior.
3. Expose runnable clang-cl and llvm-ar action tools plus clang-cl's declared
   sibling lld-link for every claimed exec platform and source-built stage.
4. Reuse the existing driver/resource-directory/library-directory model, then
   add only irreducible CL/COFF argument adapters and capabilities.
5. Route SDK/UCRT/VCRuntime include and library directories; set compatibility
   version and prevent host discovery.
6. Route compiler-rt builtins through the existing target resource-directory
   mechanism; keep profile/coverage and advanced runtimes unavailable.
7. Implement `/MD` and `/MT`, declared import libraries/PDBs, dependency
   parsing, response files, header parsing, artifact names, and linkstamps.
8. Port libc++ to the Microsoft ABI/VCRuntime model, enable its upstream MSVC
   static auto-link from a declared directory, and prove dynamic artifacts are
   absent.
9. Add behavior, action, artifact, determinism, source-built, native-runtime,
   and MinGW-regression tests.
10. Add approved minimal public documentation only after all proof is green.

### Tool packaging and bootstrap

Make `clang-cl` and `llvm-ar` first-class action `cc_tool` labels and package
raw sibling `lld-link` as declared clang-cl tool data for:

- Linux x64 and ARM64 exec;
- macOS x64 and ARM64 exec;
- Windows x64 and ARM64 exec;
- prebuilt, stage0/staged, and source-built toolchains.

For each action tool and declared child:

- resolve and run the matching exec-platform binary locally;
- declare it as the action tool/input;
- inspect generated alias labels and selection keys;
- prove source stages do not resolve to a downloaded stage-zero binary;
- prove target architecture does not select the executable;
- stop if any core tool is absent from a claimed prebuilt.

Missing llvm-lib does not block Layer 1.

Source-built ownership travels with its feature:

- tool aliases with packaging;
- ABI source selection with core actions;
- libc++ Windows/VCRuntime selection with libc++;
- no late umbrella bootstrap step that can mask the wrong source path.

For LLVM 21, default LLVM, and LLVM 23, build a representative source-built
MSVC artifact. Analysis alone is insufficient. Compare prebuilt/source-built
machine type, directives, imports, exports, arguments, and runtime behavior.

### SDK and winsysroot model

Use the existing hermetic-llvm model: pass declared include and library
directories explicitly and stage compiler-rt in the target resource directory.
Do not add a separate `/winsysroot` topology unless that model is proven
insufficient and the owner approves the exception.

Pin:

- windows_support module version;
- MSVC payload version;
- Visual Studio installer manifest URL and integrity;
- Windows SDK version and package integrities;
- root-module override semantics;
- case-correction/VFS transformations required by case-sensitive exec hosts.

Test representative VCRuntime, UCRT, shared/UM/WinRT, include-next, exact-case
header, and exact-case library lookups on Linux and macOS. EULA acceptance must
remain lazy until the MSVC repository is fetched.

Consume windows_support's version-independent directory targets. Validate that
their selected path still matches the pinned MSVC payload version so a
downstream root-module extension override fails analysis with a clear ABI
error instead of silently changing inputs or producing missing labels.

libc++ include order:

1. libc++ headers;
2. curated VCRuntime headers;
3. UCRT;
4. Windows SDK shared/UM/WinRT.

Filter windows_support's broad VC include directory into the exact VCRuntime
header subset. Prove that standard headers resolve to libc++, that Microsoft
STL headers are absent from action inputs, that only the CRT-selected Microsoft
C++ runtime ABI helper provider is reachable from the filtered library
directory, and that include-next behavior is correct.

### MSVC compatibility version

Pass an explicit compatibility version on every clang-cl action, derived from
the selected MSVC payload through one source of truth shared by prebuilt and
source-built toolchains.

Verify for every supported LLVM line and language mode:

- `_MSC_VER`;
- `_MSC_FULL_VER`;
- `_MSVC_LANG`;
- representative VCRuntime and libc++ headers.

### Compile surface

Implement and prove:

- `/c` and `/Fo` for C/C++, linkstamps, and generated sources;
- correct C/C++ language selection;
- `/I`, system/external include semantics, `/D`, `/U`, `/FI`;
- warnings, optimization, assertions, exceptions, RTTI, language standards;
- retail `/MD`/`/MT` and ABI-aware `dbg` macros;
- `/Z7` by default for compile debug data unless `/Zi` plus declared `/Fd`
  outputs is fully modeled;
- `/Brepro`, macro redaction, path maps;
- the selected dependency protocol;
- compiler response files;
- header parsing/layering through a coherent tool/dialect;
- explicit dispositions for preprocess, preprocessed assembly, modules, ObjC,
  and unsupported actions.

No `-fPIC`, ELF visibility, GNU dependency flags, or GNU-only arguments reach
an MSVC action except an individually audited `/clang:` escape.

### Archive surface

Implement and prove:

- direct llvm-ar action;
- `rcsD <declared-output> <objects...>` exactly once;
- objects and object groups;
- archive response files;
- AMD64/ARM64 COFF members;
- deterministic member order and timestamps;
- alwayslink remains a final-link `/WHOLEARCHIVE:` behavior.

Do not introduce `/OUT` or `/MACHINE` on archive actions until Layer 4.

### Link surface

Implement and prove clang-cl driver links which select the declared sibling
lld-link:

- `/Fe` owns the declared output;
- driver/resource-directory selection owns compiler-rt;
- `/MD` or `/MT`, libc++ auto-link, and declared library directories own
  toolchain runtime selection; no explicit runtime filenames in final-link
  argv or
  `/NODEFAULTLIB` appear in Bazel link argv;
- reuse the common driver library-search form when clang-cl accepts it; use a
  forwarded `/LIBPATH:` only after a failed common-form action proof;
- LINK-only `/DLL` is forwarded individually with response-safe
  `/clang:-Xlinker` pairs;
- objects, object groups, static libraries, interface libraries, and approved
  dynamic-library forms;
- `/WHOLEARCHIVE:<library>` only for alwayslink;
- `/DEF:` and explicit/generated exports;
- `/IMPLIB:` with the actual declared interface-library output;
- `/DEBUG` and declared final PDB;
- `/SUBSYSTEM:CONSOLE` plus documented GUI override;
- `/MACHINE:X64` or `/MACHINE:ARM64`;
- `/Brepro` and forwarded `/INCREMENTAL:NO`;
- user LINK-syntax options;
- a clang-cl link response file and explicit dispositions for
  ThinLTO/profile/coverage/sanitizer inputs.

Import-library gate:

- actual DLL action exposes `interface_library_output_path`;
- chosen `.if.lib` or approved suffix is a declared output;
- `/IMPLIB:` names that exact output;
- no orphan `.lib` exists;
- consumer links through the generated import library;
- explicit and generated DEF exports match.

PDB gate:

- debug feature explicitly enabled;
- compile uses `/Z7` or fully declared `/Zi`/`/Fd` outputs;
- clang-cl forwards `/DEBUG` to lld-link;
- final PDB is declared and named as expected;
- matching rules_cc behavior, lld-link may derive the sibling PDB name from the
  driver-translated `/Fe` output; explicit `/PDB:` is required only when
  rules_cc exposes the declared PDB path to the toolchain;
- PE CodeView record names the intended PDB;
- no empty or guessed `/PDB:`;
- reproducibility and path privacy inspected.

### libc++/VCRuntime port

Build libc++ for MSVC ABI with:

- Microsoft ABI implementation;
- VCRuntime headers/libraries;
- no libc++abi or libunwind;
- no MinGW files;
- no Microsoft STL headers or selected standard-library closure; make only
  upstream libc++'s CRT-matched Microsoft C++ runtime ABI helper provider
  reachable in the selected library directory (`msvcprt.lib` for `/MD`,
  `libcpmt.lib` for `/MT`);
- pinned ABI site configuration;
- upstream Microsoft-ABI static auto-link policy;
- COFF static `libc++.lib`; no shared DLL or import-library artifact in Layer 1;
- ABI/CRT/STL-preserving runtime transitions.

Static libc++ must work with `/MD` and `/MT` under both ordinary static and
dynamic dependency linkage. Shared libc++ is deferred; Layer 1 must expose no
`c++.dll` or shared-libc++ import-library route.

Behavior scenarios, x64 and ARM64:

- exceptions, `exception_ptr`, termination, standard exceptions;
- RTTI and dynamic casts;
- allocation/deallocation and replacement operators;
- iostreams and locale;
- filesystem;
- threads, mutexes, condition variables, atomics;
- ordinary, static, and alwayslink libraries;
- executable and DLL production;
- explicit and generated DEF flows;
- generated import-library consumption;
- supported C/Win32 cross-DLL boundaries.

### Layer 1 test surface

Keep the permanent suite small and behavior-oriented:

- one C/C++/assembly libc++ smoke per CRT, with the ordinary exception path
  exercising libc++'s `exception_ptr` ABI rather than a separate matrix;
- one native DLL consumer covering `__declspec(dllexport)`, explicit DEF, and
  generated DEF/import-library flows;
- `//e2e/rules_cc:windows_msvc_artifacts_matrix` for x64/ARM64 PE, COFF archive,
  CRT import, export, import-library, alwayslink, compiler-rt, and PDB behavior;
- `windows_msvc_action_test.sh` for the few protocols not observable by running
  or inspecting artifacts: clang-cl dependency/response inputs, llvm-ar
  `rcsD`, clang-cl driver selection of lld-link, response-safe LINK forwarding,
  whole-archive, SDK case
  overlay, declared import library, resource/library directories, and absence
  of explicit runtime filenames;
- `windows_msvc_analysis_test.sh` for unsupported combinations, including an
  explicit shared-libc++ request.

Do not preserve bespoke Go action/artifact assertion frameworks or exhaustive
private feature goldens after these checks cover the externally observable
contract. MinGW remains protected by the repository's existing tests.

Required focused verification from `e2e/rules_cc`:

```sh
bazel test --config=remote //:windows_msvc_artifacts_matrix
bash ./windows_msvc_action_test.sh --config=remote
bash ./windows_msvc_analysis_test.sh --config=remote
```

Matching Windows CI also runs the libc++ smoke in both configuration-wide CRT
modes and the combined DLL consumer natively. Linux, macOS, and Windows x64
and ARM64 hosts locally execute the representative compile/link actions.

### Acceptance

Layer 1 is complete only when:

- valid MSVC+libc++ x64/ARM64 platforms resolve on every claimed exec host;
- invalid ABI/STL/CRT combinations fail with stable tested errors;
- compiler-rt builtins resolve as the exact MSVC resource-directory artifact;
  unfinished runtimes stay unavailable through a real capability mechanism;
- clang-cl/llvm-ar action tools and clang-cl's declared sibling lld-link work
  for prebuilt and source-built configurations;
- goldens cover every supported protocol row and unsupported disposition;
- actions declare all tools, SDK/UCRT/VCRuntime/libc++ inputs and outputs;
- dependency discovery and all three response-file kinds handle long, spaced,
  colon-bearing, and non-ASCII paths on every exec OS;
- `/MD` or `/MT` is coherent across objects, transitive libraries, generated
  sources, linkstamps, runtimes, transitions, directives, and PE imports;
- `dbg` never introduces `_DEBUG`, `/MDd`, `/MTd`, or debug libraries;
- libc++ route contains no MinGW, libc++abi, libunwind, Microsoft STL headers,
  or Microsoft-STL library input beyond the exact CRT-selected Microsoft C++
  runtime ABI helper provider;
- static-only libc++ support matches the approved matrix under ordinary static
  and dynamic dependency modes;
- direct behavior scenarios execute natively on matching Windows targets;
- repeated artifacts are deterministic;
- prebuilt/source-built and x64/ARM64 artifacts have correct machine types,
  directives, imports, exports, import libraries, and PDBs;
- complete MinGW and existing-suite regression gates pass;
- minimal public docs are approved and match evidence.

### Stop conditions

Stop on any claimed-host tool/path failure, undeclared input/output,
contradictory CRT/defaultlib directive, runtime-transition loss, target/exec
architecture leak, MinGW/Microsoft-STL contamination outside the approved
Microsoft C++ runtime ABI helper provider, SDK case failure,
unrepresentable import library/PDB, or existing-toolchain regression. Do not
merge a compile-only or C-only public platform.

## 11. Layer 2 / Goal 2: Microsoft STL

### Objective

Add Microsoft STL as a complete standard-library alternative selected only by
the C++ standard-library contract. Preserve every Layer 1 libc++ action and
artifact outside approved selection-specific differences.

### Proposed Goal Record

- Parent: exact merged/draft Layer 1 commit recorded before activation.
- Branch: `cerisier/windows-msvc-stl`.
- Worktree: `/Users/corentinkerisit/code/github.com/hermeticbuild/hermetic-llvm-msvc-stl`.
- Owned invariant: changing only the STL selection changes only the intended
  headers/libraries/runtime closure.
- Non-goals: sanitizer enablement, llvm-lib, CL/LINK redesign, app-local VC
  redistributables unless separately approved.

### Implementation scope

- Add functional `//constraints/cxxstdlib:msvc` selection.
- Implement the approved named/custom platform API.
- Route architecture-specific Microsoft STL headers and libraries by target
  CPU.
- Preserve retail `/MD` and `/MT` selection across UCRT, VCRuntime, and STL.
- Implement the approved debug CRT/STL and iterator-debug policy.
- Support static libraries, alwayslink, executables, DLLs, import libraries,
  DEF files, PDBs, linkstamps, and response files.
- Reject repository-owned libc++/Microsoft-STL closure mixing.
- Document the inability to infer arbitrary opaque prebuilt-library ABI.
- Test representative Microsoft-produced libraries at every claimed boundary,
  including an STL-exposing interface only if advertised.
- Preserve Layer 1 libc++ goldens, artifacts, native behavior, and MinGW
  results.

### Named Layer 2 test surface

- `//e2e/rules_cc:windows_msvc_stl_matrix`;
- `//e2e/rules_cc:windows_msvc_mixed_stl_failures`;
- Layer 1 behavior, analysis, action, and artifact checks remain unchanged.

Required focused verification:

```sh
cd e2e/rules_cc
bazel test --config=remote \
  //:windows_msvc_stl_matrix \
  //:windows_msvc_mixed_stl_failures \
  //:windows_msvc_artifacts_matrix
bash ./windows_msvc_action_test.sh --config=remote
bash ./windows_msvc_analysis_test.sh --config=remote
```

### Acceptance

- `cxxstdlib:msvc` resolves only with MSVC ABI and approved UCRT semantics.
- Target CPU selects the correct hermetic payload.
- `/MD` and `/MT` produce coherent retail CRT/STL directives/imports.
- Debug and iterator policy matches the Phase 0 decision.
- Full C++ behavior matrix passes natively for x64/ARM64.
- Static/alwayslink, DLL/import, DEF, PDB, linkstamp, and response-file paths
  pass on all claimed exec hosts.
- Microsoft-library interoperability passes only at advertised boundaries.
- Mixed repository-owned STL closures fail analysis.
- No host Visual Studio discovery occurs.
- Redistribution authority is recorded.
- Every Layer 1 libc++ action/artifact is unchanged except approved
  non-semantic shared metadata.
- Existing suites and MinGW remain green.

### Stop conditions

Stop on host discovery, unclear redistribution rights, mixed STL closure,
debug-policy drift, wrong target-architecture payload, or libc++ regression.

## 12. Layer 3 / Goal 3: sanitizers with both standard libraries

### Objective

Enable only compiler-rt capabilities proven end-to-end with libc++ and
Microsoft STL. A feature tested with one STL is not advertised for the other.

### Proposed Goal Record

- Parent: exact Layer 2 commit recorded before activation.
- Branch: `cerisier/windows-msvc-sanitizers`.
- Worktree: `/Users/corentinkerisit/code/github.com/hermeticbuild/hermetic-llvm-msvc-sanitizers`.
- Owned invariant: each sanitizer runtime matches consumer ABI, architecture,
  CRT mode, output kind, and STL closure.
- Non-goals: llvm-lib, unrelated unsupported sanitizers, app-local VC
  redistributables, optimization/instrumentation not required by an accepted
  sanitizer.

### Runtime manifest

Check in an exact compiler-rt manifest keyed by:

- LLVM major;
- target architecture;
- `/MD` versus `/MT`;
- executable versus DLL;
- libc++ versus Microsoft STL variant where required;
- static library, import library, runtime DLL, and thunk output kind.

Do not use a generic “`.lib` layout” claim. Record actual filenames and Clang
lookup paths. At minimum distinguish:

- `/MD` ASan dynamic runtime and deployment DLL;
- `/MT` executable ASan runtime linked whole-archive;
- `/MT` DLL ASan thunk;
- profile/builtins/runtime forms only when their owner capability is claimed.

Every runtime is built for the same target ABI and compatible CRT mode as its
consumer. Inspect its COFF directives, imports, and declared C++ closure.

compiler-rt sources contain C++. Either:

1. build standard-library-specific runtime variants; or
2. prove via action inputs, directives, symbols, and imports that one runtime
   does not introduce a conflicting STL dependency.

Public-interface absence of STL types is not sufficient proof.

### Supported-capability process

Candidate capabilities:

- ASan;
- UBSan;
- libFuzzer;
- proven combinations;
- applicable CFI modes only after their ThinLTO prerequisite has independent
  action and artifact proof.

For every candidate, fill the approved matrix for libc++/Microsoft STL, x64/
ARM64, `/MD`/`/MT`, executable/DLL, LLVM 21/default/23. Unsupported cells use a
stable analysis-time capability error. Bazel ignoring an unknown feature is
not an acceptable error mechanism.

Sanitizer runtime DLLs remain distinct from VC redistributables and libc++
DLLs. Deployment tests inspect physical adjacency or another documented loader
path.

### Named Layer 3 test surface

- `//e2e/rules_cc:windows_msvc_asan_matrix`;
- `//e2e/rules_cc:windows_msvc_ubsan_matrix`;
- `//e2e/rules_cc:windows_msvc_fuzzer_matrix`;
- `//e2e/rules_cc:windows_msvc_sanitizer_combinations`;
- `//e2e/rules_cc:windows_msvc_sanitizer_invalid_matrix`;
- all Layer 1/2 unsanitized, action/artifact, and MinGW targets.

Required focused verification:

```sh
cd e2e/rules_cc
bazel test --config=remote \
  //:windows_msvc_asan_matrix \
  //:windows_msvc_ubsan_matrix \
  //:windows_msvc_fuzzer_matrix \
  //:windows_msvc_sanitizer_combinations \
  //:windows_msvc_sanitizer_invalid_matrix \
  //:windows_msvc_stl_matrix \
  //:windows_msvc_artifacts_matrix
bash ./windows_msvc_action_test.sh --config=remote
bash ./windows_msvc_analysis_test.sh --config=remote
```

### Acceptance

- Exact checked-in runtime manifest exists for every advertised cell.
- Runtime-internal C++ closure cannot mix standard libraries.
- `/MD` ASan, `/MT` executable ASan, and `/MT` DLL thunk use distinct proven
  topologies and declared runtime deployment.
- UBSan, libFuzzer, combinations, and any CFI mode build and execute with both
  STLs where advertised.
- Actions prove runtime selection, whole-archive behavior, DLL layout, and
  transition preservation.
- Artifacts prove directives, imports, symbols, architecture, and absence of
  cross-STL contamination.
- Unsupported cells fail during analysis with stable errors.
- Native Windows tests run on the matching target architecture.
- Remote jobs inspect cross-target actions/artifacts.
- Unsanitized libc++, unsanitized Microsoft STL, MinGW, and all existing suites
  remain unchanged.

### Stop conditions

Stop on an upstream architecture/runtime limitation and request a matrix
decision. Never skip the cell, weaken native execution to link-only, or claim
support based on one STL.

## 13. Layer 4 / Goal 4: llvm-lib librarian dialect

### Objective

Replace only the MSVC archive action's command-line personality with llvm-lib.
Preserve the llvm-ar baseline's archive format, determinism, target matrix, and
all behavior from Layers 1-3.

### Proposed Goal Record

- Parent: exact Layer 3 commit recorded before activation.
- Branch: `cerisier/windows-msvc-llvm-lib`.
- Worktree: `/Users/corentinkerisit/code/github.com/hermeticbuild/hermetic-llvm-msvc-llvm-lib`.
- Owned invariant: the archive executable/argv syntax changes; archive content
  and downstream behavior do not.
- Non-goals: prebuilt republication unless alias generation is impossible,
  MinGW librarian changes, target-matrix changes, unrelated toolchain work.

### Implementation scope

- Generate `llvm-lib`/`llvm-lib.exe` as a correctly named symlink, copy, or
  multicall alias of the existing llvm-ar/unified LLVM executable for each
  supported exec platform.
- Directly prove basename/argv[0] selects Microsoft LIB parsing.
- Register llvm-lib only for MSVC ABI archive actions.
- Keep all MinGW actions on llvm-ar.
- Replace `rcsD <output> <objects...>` with proven `/OUT:`, `/MACHINE:X64` or
  `/MACHINE:ARM64`, object/object-group, and response-file expansions.
- Enable llvm-lib-specific Windows quoting only after per-host proof.

### Differential matrix

Compare the Layer 3 llvm-ar result against Layer 4 llvm-lib for:

- member list and order;
- symbol table;
- deterministic bytes/timestamps;
- x64/ARM64 member machine type;
- long, spaced, and non-ASCII paths;
- response-file quoting/encoding;
- clang-cl/lld-link driver consumption;
- ordinary static and alwayslink libraries;
- libc++ and Microsoft STL;
- every supported sanitizer;
- DLL and executable consumers;
- ThinLTO objects if ThinLTO has become supported.

### Named Layer 4 test surface

- `//toolchain/features/msvc:llvm_lib_argument_tests`;
- `//tools:msvc_llvm_lib_personality_test`;
- `//e2e/rules_cc:windows_msvc_llvm_lib_differential_matrix`;
- all previous action/artifact/behavior matrices.

Required focused verification:

```sh
cd e2e/rules_cc
bazel test --config=remote \
  @llvm//toolchain/features/msvc:llvm_lib_argument_tests \
  @llvm//tools:msvc_llvm_lib_personality_test \
  //:windows_msvc_llvm_lib_differential_matrix \
  //:windows_msvc_stl_matrix \
  //:windows_msvc_artifacts_matrix
bash ./windows_msvc_action_test.sh --config=remote
bash ./windows_msvc_analysis_test.sh --config=remote
```

### Acceptance

- Every claimed exec host exposes a proven LIB-personality alias.
- MSVC archive actions use llvm-lib; MinGW uses llvm-ar.
- MSVC archive goldens contain `/OUT` and `/MACHINE` exactly once and no
  inherited `rcsD` operand.
- Differential tests prove archive/member/symbol/determinism equivalence.
- All previously supported STL/sanitizer/link/runtime cells remain green.
- No prebuilt republishing occurs unless repository-time alias generation is
  proven impossible and separately approved.

### Stop conditions

Stop if argv[0] dispatch is not portable, archive determinism/content changes,
MinGW selects llvm-lib, or any prior matrix cell regresses. Layer 4 failure does
not invalidate the already-correct llvm-ar-based support.

## 14. Action-graph validation specification

Use JSON `aquery` plus checked-in assertions. Text grep alone is diagnostic.
For every claimed target architecture, CRT mode, STL, libc++ artifact mode,
sanitizer, and representative exec host, inspect:

- executable and mnemonic/action family;
- `executionPlatform`;
- target triple and machine type;
- complete argv and response-file references;
- response-file contents and encoding;
- declared tools, inputs, outputs, and incidental outputs;
- environment variables;
- include ordering;
- runtime transition preservation;
- absence of GNU/MinGW arguments and inputs.

Required assertions:

- compile executable is clang-cl;
- archive executable is llvm-ar through Layer 3 and llvm-lib in Layer 4;
- link action executable is clang-cl and its declared sibling lld-link is the
  selected child linker;
- no supported action falls through to a GNU tool;
- no unsupported action is advertised through an inaccurate capability;
- compiler/archive/link replacements expand once; overridden GNU forms expand
  zero times;
- dependency feature state exactly matches the selected `.d` or ShowIncludes
  mechanism;
- compiler, archive, and linker param files use independent feature switches
  and declared inputs;
- `/MD` or `/MT` appears exactly where required;
- `/MDd`, `/MTd`, `_DEBUG`, and debug CRT libraries never appear;
- `/Brepro` appears on every compile and link action;
- `/WHOLEARCHIVE`, `/IMPLIB`, `/DEF`, `/DLL`, `/MACHINE`, and any available
  explicit `/PDB` appear only on owning actions; `/Fe` owns the driver output,
  and `/DEBUG` plus the declared sibling PDB is the rules_cc-compatible default
  contract;
- Layer 1-3 archives use `rcsD`, with no llvm-lib `/OUT`/`/MACHINE` syntax;
- Layer 4 archives use `/OUT`/`/MACHINE`, with no `rcsD` operand;
- libc++ headers precede broad VC includes only on libc++ selections;
- Microsoft-STL selections resolve its headers first and contain no libc++
  include/library;
- no libc++abi, libunwind, MinGW, Microsoft STL, or sanitizer input appears
  outside its owning configuration, except the CRT-selected Microsoft C++
  runtime ABI helper provider reachable from Layer 1's filtered library
  directory;
- target CPU selects SDK/runtime libraries;
- transitive libraries, linkstamps, generated sources, runtime builds, and any
  supported ThinLTO backend preserve ABI/CRT/STL;
- source-built actions name the intended stage repository, not stage-zero.

Representative command pattern:

```sh
cd e2e/rules_cc
bazel aquery --config=remote \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_libcxx_behavior_md \
  --include_param_files --output=text
bash ./windows_msvc_action_test.sh --config=remote
```

Equivalent ARM64 and `/MT` queries are mandatory. Layer 2 adds Microsoft STL;
Layer 3 adds each sanitizer; Layer 4 reruns all archive/link consumers.

## 15. Artifact validation specification

Use the repository's `llvm` wrapper where available. Inspect resulting files,
not command status alone.

Required assertions:

- AMD64 versus ARM64 COFF machine type;
- deterministic timestamps and build identity;
- `/DEFAULTLIB` and `/FAILIFMISMATCH` directives;
- archive member machine type/order and alwayslink symbol retention;
- PE subsystem and minimum-version policy;
- expected imports and absence of unintended runtime DLLs;
- exports and DEF behavior;
- import-library content and downstream consumption;
- PDB existence and PE CodeView reference;
- static `libc++.lib` identity and absence of `c++.dll`/`c++.lib`;
- libc++ `/MD` targets consume `msvcprt.lib` and import only the required
  `__ExceptionPtr*` operations and `std::uncaught_exceptions` state from the
  compatible `msvcp*.dll`; libc++ `/MT` targets consume `libcpmt.lib` only for
  the corresponding static helper closure;
- no other Microsoft-STL library, import, header, or `std::*` implementation
  enters libc++ targets;
- no libc++ headers/libraries/DLLs on Microsoft-STL targets;
- no libc++abi/libunwind on MSVC+libc++ targets;
- sanitizer runtime libraries/DLLs and STL-specific closure;
- no MinGW startup, compatibility, auto-import, or pseudo-relocation symbols.

Representative inspection set:

```sh
llvm readobj --file-headers --coff-directives --coff-imports --coff-exports <object-or-pe>
llvm objdump -p <pe>
llvm ar t <archive>
llvm nm --defined-only <archive-or-pe>
```

The focused `windows_msvc_artifacts_test.sh` owns the stable output checks.
Temporary development probes need not remain after the same behavior is
covered here.

## 16. CI and regression design

Separate cross-target correctness, local tool availability, and native runtime
behavior. A Windows runner using RBE is not native execution evidence unless
the action's execution platform is checked or remote execution is disabled.

### Required-per-PR

- Linux x64 RBE: MSVC x64/ARM64 build, action, and artifact smoke matrix.
- Linux ARM64 RBE: complementary exec-host tool/action smoke.
- `/MD` and `/MT` for both target architectures.
- libc++ core from Layer 1; Microsoft STL from Layer 2; focused sanitizer cells
  from Layer 3.
- MinGW UCRT and legacy-MSVCRT regression comparisons.
- rules_cc adapter goldens and negative capability tests.
- Existing repository required checks at their normal depth: rules_cc,
  rules_foreign_cc, rules_rust, rules_rs, cross-compilation, Wasm, custom
  targets, formatting, public-doc verification, LLVM analysis.

### Nightly

- Forced local tools on Linux x64/ARM64 and macOS x64/ARM64.
- Compiler/archive/link response files and dependency discovery.
- Long, spaced, colon-bearing, and non-ASCII paths.
- LLVM 21, default LLVM, LLVM 23; prebuilt and representative source-built
  artifact parity.
- Full x64/ARM64, `/MD`/`/MT`, ordinary static/dynamic dependency-linkage
  matrix with static libc++.
- Both STLs after Layer 2.
- Full supported sanitizer matrix after Layer 3.
- Repeated deterministic builds separated in time.

### Native Windows

- Forced local tool execution on Windows x64 and ARM64.
- Produced PE executed on matching architecture.
- Compatible VC v14 Redistributable provisioned for `/MD` core tests.
- `/MT` tests on a clean runtime environment.
- libc++/Microsoft-STL/sanitizer DLL adjacency as applicable.
- PE import closure inspected before execution.

### Manual or release

- Complete cross-product not economical per PR.
- Clean-machine deployment scenarios.
- source-built LLVM full matrix;
- case-sensitive SDK transformations and payload integrity audit;
- deterministic cross-host comparison;
- rules_cc version-upgrade differential audit.

No layer multiplies every Bazel version, LLVM version, exec host, target CPU,
CRT mode, STL, dependency mode, and sanitizer in every required PR job. The CI
configuration must document pairwise coverage and the nightly/full expansion.

## 17. Goal execution and handoff contract

A layer completes only when:

1. baseline absence/failure is recorded where reasonably possible;
2. implementation and owning regression tests are committed together;
3. the same reproduction passes after the change;
4. focused builds/tests pass with `--config=remote`;
5. required local-exec smoke tests pass;
6. rules_cc argument/feature goldens pass;
7. action assertions pass;
8. artifact assertions pass;
9. negative boundaries fail as designed;
10. MinGW and existing repository regressions pass;
11. task-owned changes are small, reviewed, and committed;
12. branch, commit SHA, absolute worktree, verification, and draft stacked PR
    are recorded;
13. no owning proof is deferred to a later layer.

Cascade only when the parent layer is wholly green, committed, submitted as a
draft stack layer, and free of unresolved owning decisions. After parent
changes, update children bottom-up and repeat their full gates.

Global stop conditions:

- wrong or stale approved parent;
- changed public semantics without approval;
- missing EULA/legal authority;
- missing core tool on a claimed exec host;
- dependency/response-file failure on a claimed exec host;
- unavailable windows_support API/release;
- incomplete case handling;
- unrepresentable declared import library or PDB;
- conflicting `/MD`/`/MT`, retail/debug, or STL directives;
- requirement to expose dynamic libc++ without a separately approved contract;
- transition loses CRT/STL selection;
- demonstrated architecture/LLVM/sanitizer upstream limitation;
- unexpected MinGW action/artifact change;
- host SDK/tool discovery;
- required README/public API edit lacks approval;
- work expands outside the active stack layer.

An upstream limitation triggers a support-matrix review. It never authorizes a
silent test deletion or capability reduction.

### Paste-ready PR description contract

Every layer handoff includes:

```text
Motivation:

Invariant/contract:

Root cause or missing ownership path:

Change:

Baseline reproduction:

Verification:
- commands and exact results
- action assertions
- artifact assertions
- native behavior
- negative boundaries
- MinGW/existing-suite regressions

Intentional differences / unsupported cells:

Provenance:
```

## 18. Public documentation gate

README/support-matrix edits are last in each owning layer and require approval.
Document only demonstrated behavior:

- exact provided platforms and custom-platform constraints;
- clang-cl `copts` and driver-forwarded LINK `linkopts` dialect;
- default `/MD`, global opt-in `/MT`, and retail `dbg` policy;
- libc++ versus Microsoft STL availability by layer;
- static-only Windows MSVC libc++ across ordinary static/dynamic dependency
  linkage;
- target/exec architecture matrix;
- external VC Redistributable prerequisite for core `/MD` execution;
- unsupported actions and capabilities;
- sanitizer cells only after Layer 3 proof;
- minimum Windows/subsystem policy;
- mixed opaque-prebuilt-STL limitation.

Do not call the binaries “more secure” without the separate hardening evidence
listed in Section 2.

## 19. Independent follow-up: advanced optimization/instrumentation

ThinLTO, profile instrumentation, source coverage, FDO, and CFI remain outside
the four-layer product stack unless Layer 3 explicitly owns a prerequisite.

Each capability needs:

- explicit clang-cl/lld-link action mapping;
- rules_cc protocol and param-file goldens;
- exact source-built LLVM ownership;
- action/artifact proof on x64/ARM64;
- supported STL/CRT matrix;
- stable analysis error for unsupported cells;
- MinGW non-regression.

COFF distributed ThinLTO must include the weak-indirect-alias fix and a
`stage1_from_source` test so stage-zero lld-link cannot mask it. Determine
`supports_start_end_lib` semantics before claiming ThinLTO or Rust `.rlib`
propagation.

## 20. Independent follow-up: app-local VC redistributables

This is separate from compile/link correctness, libc++ DLLs, and sanitizer
runtime DLLs.

Require:

- licensed `VC/Redist` payload preservation in windows_support;
- architecture-specific logical DLL sets;
- feature-aware deployment only for effective `/MD`;
- executable adjacency or another demonstrated loader path;
- clean-machine native execution;
- no VC redistributable DLLs for `/MT`;
- no debug or unrelated payload;
- explicit legal review;
- no change to compiler/linker actions or ABI established by the core stack.

## 21. Progress, surprises, decisions, and outcomes

### Progress

- [x] Ordinary-Clang design reviewed and rejected.
- [x] clang-cl compile/driver-link, llvm-ar archive, and lld-link child
  architecture selected.
- [x] libc++/VCRuntime initial C++ direction selected.
- [x] Four-layer dependency order defined.
- [x] PR 187 and rules_cc PR 561 roles clarified.
- [x] Current GitHub base and PR states reverified 2026-08-17.
- [x] Phase 0 branch/public API/legal/tool/protocol decisions approved.
- [x] Layer 1 complete; driver-model replacement, focused proof, all six
  execution hosts, and LLVM 21/22/23 analysis are green in GitHub Actions run
  `32265648963` attempt 2.
- [ ] Layer 2 complete.
- [ ] Layer 3 complete.
- [ ] Layer 4 complete.

### Surprises and constraints

- `llvm-lib` absence is not a core archive blocker; it is normally an
  llvm-ar/unified-tool personality.
- clang-cl supports a viable `.d` route through audited `/clang:` escapes.
- Windows libc++ supports VCRuntime without libc++abi/libunwind.
- Upstream Microsoft-ABI libc++ implements `exception_ptr` operations and
  uncaught-exception state through the Microsoft C++ runtime: `msvcprt`/MSVCP
  for `/MD`, `libcpmt` for `/MT`. This narrow binary dependency is not
  Microsoft STL selection.
- Shared libc++ plus `/MT` conflicts with upstream guidance.
- rules_cc 0.2.22 lacks a complete public rule-based clang-cl surface.
- Unknown Bazel features may be ignored, so omission is not a capability
  error.
- Current Windows RBE can execute on a different OS/CPU than the target.
- windows_support's broad VC include path complicates physical STL-header
  isolation and case-sensitive hosts.
- compiler-rt's internal C++ use makes sanitizer/STL compatibility an owning
  proof obligation.
- clang-cl can select the declared sibling lld-link and toolchain runtimes from
  declared resource/library directories; direct lld-link plus an enumerated
  runtime closure is unnecessary unless a focused proof shows otherwise.

### Decision log

| Date | Decision | Status |
|---|---|---|
| 2026-08-17 | Direct clang-cl compile and lld-link link actions | Superseded 2026-08-19 |
| 2026-08-17 | llvm-ar remains core librarian; llvm-lib final dialect layer | Accepted architecture |
| 2026-08-17 | libc++/VCRuntime precedes Microsoft STL | Accepted architecture |
| 2026-08-17 | Sanitizers require both-STL verification | Accepted architecture |
| 2026-08-17 | Local adapter owned against rules_cc 0.2.22 | Accepted architecture |
| 2026-08-18 | Reuse UCRT constraint; keep legacy `msvcrt` MinGW-only | Approved |
| 2026-08-18 | Static CRT feature wins over default dynamic CRT feature | Approved |
| 2026-08-18 | `.d` dependency files and UTF-8 tool-specific response files | Approved |
| 2026-08-18 | Explicit SDK directories; windows_support case transformations | Approved |
| 2026-08-18 | Windows MSVC exposes only static `libc++.lib`; `c++.dll`/`c++.lib` are deferred; disable auto-link | Static-only portion retained; explicit link/disabled auto-link superseded 2026-08-19 |
| 2026-08-18 | Microsoft payload redistribution forbidden in the stack | Approved |
| 2026-08-18 | Four-layer `gh stack` plan | Explicitly approved |
| 2026-08-18 | Allow only the CRT-selected Microsoft C++ runtime ABI helper provider (`__ExceptionPtr*` and uncaught-exception state) on libc++ routes; Microsoft STL headers/full selection remain Layer 2 | Owner-approved Phase 0 amendment, refined by emitted-artifact proof |
| 2026-08-19 | Follow the existing driver/runtime-directory model: clang-cl links through declared sibling lld-link; driver/COFF defaults select toolchain runtimes from declared directories; no `/NODEFAULTLIB` or Bazel-enumerated runtime closure | Complete; focused proof and GitHub Actions run `32265648963` attempt 2 green |
| 2026-08-19 | libc++ archive members carry the CRT-selected `msvcprt`/`libcpmt` dependent-library directive because clang-cl `/MD`/`/MT` omits it; no provider filename returns to final-link argv | Implemented after focused implicit-selection failure; within the approved narrow ABI-helper exception |

### Outcomes

Phase 0 is complete. It freezes the approved evidence and contracts, adds only
the decision/provenance ledgers and their verification tooling, and stops
before Layer 1. No product MSVC behavior or README changed; completion does not
mean MSVC support exists.

## 22. Authoritative references

- [LLVM WinMsvc cross-toolchain configuration](https://github.com/llvm/llvm-project/blob/main/llvm/cmake/platforms/WinMsvc.cmake)
- [Clang-cl documentation](https://clang.llvm.org/docs/UsersManual.html#clang-cl)
- [Clang toolchain composition](https://clang.llvm.org/docs/Toolchain.html)
- [LLD Windows support](https://lld.llvm.org/windows_support.html)
- [libc++ platform support](https://releases.llvm.org/22.1.0/projects/libcxx/docs/index.html#platform-and-compiler-support)
- [libc++ vendor configuration](https://releases.llvm.org/22.1.0/projects/libcxx/docs/VendorDocumentation.html)
- [libc++ Windows vendor support](https://releases.llvm.org/22.1.0/projects/libcxx/docs/VendorDocumentation.html#support-for-windows)
- [libc++ ABI-library configuration](https://releases.llvm.org/22.1.0/projects/libcxx/docs/VendorDocumentation.html#abi-specific-options)
- [libc++ MSVC ABI selection source](https://github.com/llvm/llvm-project/blob/llvmorg-22.1.0/libcxx/include/__configuration/abi.h)
- [libc++ VCRuntime configuration](https://libcxx.llvm.org/UserDocumentation.html#libc-configuration-macros)
- [GCC binary compatibility](https://gcc.gnu.org/onlinedocs/gcc/Compatibility.html)
- [libstdc++ ABI policy](https://gcc.gnu.org/onlinedocs/gcc-8.1.0/libstdc%2B%2B/manual/manual/abi.html)
- [rules_cc 0.2.22 Windows reference](https://github.com/bazelbuild/rules_cc/blob/0.2.22/cc/private/toolchain/windows_cc_toolchain_config.bzl)
- [rules_cc PR 561](https://github.com/bazelbuild/rules_cc/pull/561)
- [hermetic-llvm PR 187](https://github.com/hermeticbuild/hermetic-llvm/pull/187)
- [Microsoft `/MD` and `/MT` contract](https://learn.microsoft.com/en-us/cpp/build/reference/md-mt-ld-use-run-time-library)
- [Microsoft CRT composition](https://learn.microsoft.com/en-us/cpp/c-runtime-library/crt-library-features?view=msvc-170)
- [windows_support BCR module](https://registry.bazel.build/modules/windows_support/)
