# Windows MSVC clang-cl driver-link migration

Status: owner-approved design; implementation has not started.

Date: 2026-08-19 (Asia/Tokyo)

Baseline: `b9b18f6b267fd7305930ac9d2fe5f7f24797d400` on
`cerisier/windows-msvc-libcxx`.

## Objective

Make Windows MSVC linking follow hermetic-llvm's existing driver-link model as
closely as the CL/COFF platform permits:

- Bazel launches `clang-cl` for executable and DLL links;
- clang-cl selects the declared sibling `lld-link`;
- compiler and C++ runtimes live in declared resource/library directories;
- normal driver and COFF default-library behavior selects runtime files;
- Bazel does not enumerate toolchain-owned runtime `.lib` files on every link;
- Windows-specific adapters remain only where the existing model cannot express
  a required LINK/COFF output or ordering contract.

This plan does not authorize implementation. Start only on the owner's explicit
implementation mark.

## Owner direction

The existing repository model is the default. Do not preserve a direct-link or
manually enumerated runtime closure merely because Layer 1 already implemented
one. Diverge only after an end-to-end proof demonstrates that the existing
driver/resource-directory/library-directory model cannot satisfy an approved
Windows contract. Stop and report that proof before adding an exception.

The intended action shape is:

```text
clang-cl
  --target=<x86_64|aarch64>-pc-windows-msvc
  -no-canonical-prefixes
  /clang:-fuse-ld=lld
  /Fe<declared-output>
  -resource-dir <declared Clang resource directory>
  /MD or /MT
  <ordinary objects and Bazel dependency libraries>
  -Xlinker <LINK-only options>
```

Declared, target-selected directories provide compiler-rt, libc++, the chosen
Microsoft CRT family, UCRT, VCRuntime, and Windows SDK import libraries. The
driver and COFF directives choose filenames from those directories.

## Existing-model mapping

The non-MSVC toolchain already establishes the governing pattern:

- a Clang driver owns final links and selects the LLD personality;
- `//runtimes:resource_directory` stages compiler-rt by target triple;
- `-resource-dir` and `-rtlib=compiler-rt` let Clang choose compiler-rt;
- declared library search directories expose platform and C++ runtimes;
- Bazel still passes ordinary target objects/libraries and special link intent;
- action inputs remain hermetic even when the driver chooses a file by name.

Windows should reuse those concepts and common argument groups where clang-cl
accepts them. CL spelling or COFF output variables justify a thin adapter, not
a second runtime architecture.

## Demonstrated facts

### Driver and linker selection

Local macOS ARM64 probes used the repository's LLVM 21.1.8, 22.1.8, and
23.1.0-rc1 prebuilts. For all three:

- `/clang:-fuse-ld=lld` selected the sibling `bin/lld-link`;
- `/Feout.exe` became the child linker's `-out:out.exe`;
- individual `-Xlinker` pairs reached lld-link unchanged;
- x86-64 and ARM64 triples selected the intended MSVC targets.

Do not use a terminal `/link`. With no input before it clang-cl can emit no
link job, and it conflicts with rules_cc's interleaved option/input ordering.

Source-built clang-cl is a symlink to the monolithic LLVM binary. Direct
`-no-canonical-prefixes` keeps `InstalledDir` at the staged `bin` directory so
the driver selects the staged sibling `lld-link`; this still requires native
Windows and every-source-stage proof.

### Runtime selection

Clang-cl compilation embeds the selected CRT default libraries:

- `/MD` emits `msvcrt` and `oldnames` dependencies;
- `/MT` emits `libcmt` and `oldnames` dependencies.

Microsoft-ABI libc++ headers auto-link `libc++.lib` unless
`_LIBCPP_NO_AUTO_LINK` is defined. The Layer 1 static libc++ configuration uses
the spelling `libc++.lib`.

The MSVC driver adds compiler-rt from its resource directory when
`-rtlib=compiler-rt` is selected. The repository already stages the target
archive as `lib/<triple>/clang_rt.builtins.lib`.

Normal CRT libraries may carry further default-library directives that close
UCRT/VCRuntime dependencies. That behavior must be proven for the filtered
hermetic `/MD` and `/MT` directory trees; it is not permission to expose the
host Visual Studio installation.

### Hermetic discovery

Clang-cl otherwise probes Visual Studio, the Windows SDK, `LIB`, `CL`, and
`_CL_`. Production actions must make all search roots explicit and declared,
clear or control host-affecting variables, and prove that no host path reaches
the child command.

The preferred initial model is explicit declared resource/library directories,
matching this repository's existing `-resource-dir` plus library-search-path
model. Do not introduce a separate `/winsysroot` topology unless explicit
directories are proven insufficient and the owner approves that exception.

## Exact protocol

| Surface | Required form |
|---|---|
| action tool | `clang-cl` |
| actual linker | declared sibling `lld-link` selected by `/clang:-fuse-ld=lld` |
| target | explicit x86-64 or ARM64 MSVC triple on link actions |
| output | `/Fe{output_execpath}` |
| compiler-rt | declared resource directory plus driver `-rtlib=compiler-rt`; no Bazel-emitted builtins filename |
| libc++ | declared library directory plus upstream MSVC auto-link; no Bazel-emitted `libc++.lib` filename |
| CRT mode | `/MD` or `/MT`; object/default-library directives choose the family |
| CRT/SDK files | selected, declared, case-correct library directories; no enumerated link closure |
| ordinary Bazel dependencies | unchanged driver inputs |
| alwayslink archive | `-Xlinker /WHOLEARCHIVE:{library}` |
| library search path | reuse the common driver library-search form when clang-cl accepts it; otherwise use proven `-Xlinker /LIBPATH:{path}` |
| DLL | `-Xlinker /DLL`, not `/LD` |
| DEF/import library | exact declared paths forwarded with `-Xlinker` |
| PDB/debug | declared sibling PDB plus forwarded `/DEBUG` |
| user `linkopts` | public LINK syntax, individually forwarded with `-Xlinker` |
| response file | declared clang-cl link-driver response file; child spill file is internal |

Do not emit `/NODEFAULTLIB`: it disables the platform mechanism selected by
this plan. Do retain controls that prevent lld-link from reading ambient host
state.

## Expected simplification

Delete or replace:

- the direct `lld-link` action mapping and standalone action-tool wrapper;
- project-owned `/OUT:` generation;
- `/NODEFAULTLIB`;
- explicit ordered `/MD` and `/MT` library-name closures;
- explicit `libc++.lib` link arguments and `_LIBCPP_NO_AUTO_LINK`;
- explicit `clang_rt.builtins.lib` link arguments;
- tests/comments requiring those filenames in Bazel's top-level argv;
- direct-lld-link response-file wording.

Keep:

- raw `lld-link[.exe]` beside clang-cl and declared as tool data;
- target-selected compiler resource and runtime/library directories;
- filtered `/MD` and `/MT` Microsoft library directories until broader input
  exposure is explicitly approved;
- `windows_case_copy` for case-correct SDK/import-library lookup;
- `windows_case_vfs` for Clang header lookup;
- the portable DEF parser and its BSD notice;
- rules_cc adapters for objects, libraries, whole archive, DEF, `.if.lib`, PDB,
  subsystem, machine, and response files;
- artifact and native behavior verification;
- deterministic llvm-ar and archive response files.

If a runtime cannot be selected through the existing driver/directory model,
record the smallest demonstrated exception and obtain owner approval before
adding an explicit runtime filename.

## Recorded contract amendments

This documentation-only preparation records these superseding decisions in
`PLAN.md`, the Phase 0 ledger, and the Layer 1 goal record:

1. the Bazel link action executable is clang-cl; lld-link is its declared child;
2. `/Fe` replaces project-owned `/OUT:`;
3. runtime selection follows declared directories plus driver/COFF defaults;
4. `/NODEFAULTLIB` and the explicit runtime closure are removed;
5. libc++ MSVC auto-link and compiler-rt resource-directory discovery are
   enabled;
6. public `linkopts` remain LINK syntax and are forwarded individually;
7. any Windows-only departure from the existing runtime model requires a
   failed proof and a new owner decision.

No README, redistribution, EULA, CI-secret, Microsoft STL, sanitizer, dynamic
libc++, debug CRT, or llvm-lib decision is included.

## Execution plan

### 1. Freeze the direct-link baseline

- Save x64/ARM64 `/MD` and `/MT` actions and runtime artifacts at `b9b18f6`.
- Record action tool, environment, inputs/outputs, PE imports, COFF directives,
  PDB association, DLL exports/import library, and alwayslink symbol.
- Commit only the approved plan/ledger amendments before code.

Rollback point: documentation-only commit.

### 2. Reuse the existing driver tool model

- Map MSVC link actions to the existing clang-cl tool.
- Give clang-cl the declared sibling lld-link and the same link capabilities.
- Reuse the common target, resource-directory, compiler-rt, and runtime search
  concepts wherever their spelling works in CL mode.
- Keep raw staged lld-link beside source-built clang-cl; remove only its
  standalone action wrapper.
- Prove `-no-canonical-prefixes` preserves same-stage sibling discovery.

Rollback point: tool-map-only commit.

### 3. Move runtime ownership to the driver/directories

- Pass the target triple, `/clang:-fuse-ld=lld`, `/Fe`, resource directory,
  `-rtlib=compiler-rt`, and `/MD` or `/MT` to driver link actions.
- Begin with the repository's existing target, resource, compiler-rt, and
  library-search argument groups; introduce CL spelling only where clang-cl
  rejects a common spelling in an inspected action.
- Expose target-selected libc++, CRT, UCRT, VCRuntime, and SDK library
  directories as declared inputs/search roots.
- Remove `_LIBCPP_NO_AUTO_LINK`, `/NODEFAULTLIB`, explicit CRT/provider names,
  explicit libc++, and explicit compiler-rt builtins.
- Control `LIB`, `CL`, `_CL_`, `PATH`, and any Visual Studio/SDK discovery.
- Materialize an action and inspect the child command before changing special
  LINK option adapters.

Rollback point: runtime-selection commit.

### 4. Translate only irreducible LINK surfaces

- Keep ordinary object and dependency libraries as driver inputs.
- Individually forward whole archive, `/DLL`, `/DEF`, `/IMPLIB`, `/DEBUG`,
  machine/subsystem, determinism, and user LINK options. Forward library paths
  only if the common driver form fails its clang-cl action proof.
- Preserve exact declared outputs and rules_cc ordering.
- Prefer common rules_cc/common-toolchain features; retain MSVC-local features
  only where CL spelling or COFF variables make reuse impossible.

Rollback point: link-adapter commit.

### 5. Focused proof

Keep the permanent tests behavior-oriented:

- C/C++/assembly libc++ smoke for `/MD` and `/MT`;
- native DLL consumer with dllexport, explicit DEF, and generated DEF;
- x64/ARM64 artifact inspection for PE/COFF, imports, PDB, `.if.lib`, and
  alwayslink;
- one action query proving clang-cl, sibling lld-link, resource/library
  directories, response files, forwarding, and absence of explicit runtime
  filenames/host paths;
- existing unsupported-combination analysis tests.

The action proof must show that the child lld-link command resolves runtime
names from declared directories and contains no host Visual Studio/SDK path.

### 6. Matrix closeout

Run focused remote tests from `e2e/rules_cc`, then the normal repository CI.
Exercise Linux x64/ARM64, macOS x64/ARM64, and Windows x64/ARM64 execution
hosts. Build representative prebuilt and source-built LLVM 21/default/23
artifacts. Execute matching binaries natively on Windows.

Inspect the resulting action graph and artifacts, not only command status.

## Acceptance criteria

- Every MSVC final link executes clang-cl and declares its sibling lld-link.
- Runtime inputs follow the existing declared resource/library-directory model.
- Bazel emits no explicit toolchain-owned CRT, libc++, or compiler-rt filename.
- `/MD` and `/MT` produce the approved CRT imports/default-library directives.
- libc++ auto-link selects only static `libc++.lib`; no dynamic libc++ appears.
- compiler-rt builtins come from the target resource directory exactly once.
- No `/NODEFAULTLIB`, host VC/SDK path, ambient `LIB`/`CL`/`_CL_`, GNU child-
  linker form, `link.exe`, or host linker appears.
- Objects, ordinary libraries, alwayslink, DLL, DEF, `.if.lib`, PDB, subsystem,
  machine, response-file, and public LINK-syntax contracts still pass.
- Prebuilt/source-built LLVM 21/default/23 and all six execution hosts pass.
- MinGW and non-Windows action graphs remain unchanged.
- No README or later-layer scope changes.

## Stop conditions

Stop for owner direction if:

- a runtime needs an explicit filename rather than directory/driver selection;
- `/winsysroot` appears necessary;
- exposing a broader Microsoft library directory would implicitly support
  Microsoft STL or change the public input surface;
- driver behavior differs across supported LLVM lines or execution hosts;
- a new redistribution, EULA, CI-secret, or public-API decision appears.

An unsuccessful implicit-selection proof is not permission to restore the old
explicit closure. Preserve the direct-link baseline as rollback evidence and
report the smallest blocking difference.
