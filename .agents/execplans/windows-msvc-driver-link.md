# Windows MSVC clang-cl driver-link migration

Status: proposed; architecture evidence complete; no implementation performed.

Date: 2026-08-19 (Asia/Tokyo)

Baseline: `b9b18f6b267fd7305930ac9d2fe5f7f24797d400` on
`cerisier/windows-msvc-libcxx`.

## Objective

Change Layer 1 Windows MSVC executable and DLL link actions from direct
`lld-link` invocation to the `clang-cl` driver, while still selecting the
declared sibling `lld-link` and preserving every observable ABI, CRT, runtime,
artifact, dependency, response-file, and unsupported-configuration contract.

This plan does not implement the change. It records the required argument and
tool protocol, the expected simplifications, the new risks, and an executable
verification sequence.

## Executive conclusion

The migration is viable for LLVM 21.1.8, 22.1.8, and 23.1.0-rc1. The preferred
action shape is:

```text
clang-cl
  --target=<x86_64|aarch64>-pc-windows-msvc
  -no-canonical-prefixes
  /clang:-fuse-ld=lld
  /Fe<declared-output>
  <objects and ordinary .lib inputs>
  -Xlinker <each LINK-dialect option>
```

Do not use one terminal `/link` separator. A `clang-cl -### /link ...` probe
with no input before `/link` produces no link job, and `/link` also makes
rules_cc's interleaved input/option ordering difficult to preserve. Individual
`-Xlinker <arg>` pairs let objects and ordinary libraries remain driver inputs
while preserving the existing public contract that `linkopts` use LINK syntax.

This is not a large simplification of the MSVC adapter. It removes the direct
`lld-link` action tool wrapper and makes tool selection consistent with this
repository's non-MSVC driver-link model. It does not remove the project-owned
mapping for CRT closure, SDK paths, whole archive, DEF/import libraries, PDBs,
or runtime inputs. It also introduces driver discovery and child-command
ordering risks that direct `lld-link` did not have.

## Demonstrated facts

### Existing action

The Layer 1 x86-64 `/MD` action query at `b9b18f6b` passed in BuildBuddy
invocation `0e8bce19-4e84-40f7-8f9e-d8b1c4cfbe6e` and showed:

- action executable: the Linux ARM64 `bin/lld-link`;
- explicit `/MACHINE:X64`, `/NODEFAULTLIB`, `/WHOLEARCHIVE:`, `/OUT:`, SDK and
  CRT paths, `libc++.lib`, and `clang_rt.builtins.lib`;
- declared Windows SDK/UCRT/VCRuntime/libc++/compiler-rt inputs;
- Linux ARM64 execution platform for a Windows x86-64 target.

### clang-cl translation

Local macOS ARM64 `clang-cl -###` probes used the repository's prebuilt LLVM
21.1.8, 22.1.8, and 23.1.0-rc1 distributions. For all three:

- `/clang:-fuse-ld=lld` selected the sibling `bin/lld-link`;
- `/Feout.exe` became the child linker's `-out:out.exe`;
- `-Xlinker /MACHINE:X64`, `/NODEFAULTLIB`, `/lldignoreenv`, `/DLL`, and
  `/IMPLIB:out.if.lib` reached `lld-link` unchanged;
- x86-64 and ARM64 target triples selected the requested MSVC target;
- the sibling `lld-link` executable existed in every tested distribution.

The same driver implementation path is present in upstream
`clang/lib/Driver/ToolChains/MSVC.cpp` at:

- LLVM 21.1.8, commit `2078da43e25a4623cab2d0d60decddf709aaea28`;
- LLVM 22.1.8, commit `ca7933e47d3a3451d81e72ac174dcb5aa28b59d1`;
- LLVM 23.1.0-rc1, commit `278c31bfb8ceb7ea17dbfd11a4fb21e6634af957`.

That source translates `-fuse-ld=lld` to `lld-link`, appends `-Xlinker`
arguments as linker inputs, and may create an internal UTF-16 response file for
the child command.

### Discovery and packaging hazards

Without `LIB` in the environment, clang-cl injected discovered/guessed VC
paths such as `lib/amd64` and `atlmfc/lib/amd64`. Setting `LIB` to an explicit
empty or sentinel value removed those paths. The existing `/lldignoreenv`
then prevents lld-link from consuming `LIB` itself.

Clang also reads `CL` and `_CL_`. Driver-link actions must set all three
variables explicitly (`LIB`, `CL`, `_CL_`) rather than inherit host state.

Source-built clang-cl is currently a symlink to the monolithic LLVM binary.
With canonical prefixes, Clang resolves the real binary and searches beside
it. A symlink probe proved that the direct driver argument
`-no-canonical-prefixes` keeps `InstalledDir` at the staged `bin` directory and
selects the declared staged sibling `lld-link`. The existing
`/clang:-no-canonical-prefixes` spelling is too late to affect Clang's initial
executable-path resolution. Alternatively copying clang-cl would work but
would duplicate a large binary; the plan uses the direct driver argument and
requires a source-stage proof.

Using driver `/LD` injects a default `<dll>.lib` import-library path before the
project's required `.if.lib`. Prefer `/Fe<dll>` plus
`-Xlinker /DLL` and the exact declared `-Xlinker /IMPLIB:<name>.if.lib`.

### Comparison with existing conventions

- hermetic-llvm's non-MSVC tool map uses `clang++` as the link action tool and
  declares the selected linker beside it. Driver-link therefore aligns with
  this repository's normal architecture.
- rules_cc 0.2.22's native Windows reference invokes `msvc_link_path`
  (`link.exe`) directly, not through `cl.exe`.
- rules_cc PR 561's clang-cl example maps link actions directly to `lld-link`.

The migration is a repository consistency choice, not rules_cc Windows parity.

## Exact protocol mapping

| Current direct-link surface | Driver-link form |
|---|---|
| action tool | `clang-cl` |
| linker selection | `/clang:-fuse-ld=lld` before inputs |
| staged sibling lookup | direct `-no-canonical-prefixes`; declare sibling `lld-link` as tool data |
| target | `--target=x86_64-pc-windows-msvc` or `--target=aarch64-pc-windows-msvc` on link actions |
| output | `/Fe{output_execpath}`; remove project-owned `/OUT:` |
| ordinary object/static/interface/dynamic library | unchanged plain driver input |
| alwayslink archive | `-Xlinker /WHOLEARCHIVE:{library}` |
| library search path | `-Xlinker /LIBPATH:{path}` |
| DLL | `-Xlinker /DLL`, not `/LD` |
| DEF | `-Xlinker /DEF:{def_file_path}` |
| import library | `-Xlinker /IMPLIB:{interface_library_output_path}` |
| machine/subsystem | one `-Xlinker` pair per current LINK option |
| PDB/debug | `-Xlinker /DEBUG`; keep sibling declared PDB behavior |
| determinism | driver `/Brepro`; forward `/INCREMENTAL:NO`, `/PDBALTPATH`, and `/pdbsourcepath` with `-Xlinker` |
| CRT isolation | forward `/NODEFAULTLIB`; retain the explicit ordered CRT closure |
| user/legacy `linkopts` | expand each existing LINK-syntax value as `-Xlinker {value}` |
| Bazel link response file | clang-cl UTF-8/Windows-quoted declared input; child spill file is driver-internal |

Keep `LIB` present and controlled in the action environment. Keep
`/lldignoreenv`. Assert that `CL` and `_CL_` are controlled and that no host VC,
Windows SDK, `LIB`, or `PATH` search contributes a link input.

## Deletion and simplification inventory

Delete or replace:

- link-action mappings from the `lld-link` `cc_tool` to the existing
  `clang-cl` `cc_tool` in prebuilt and bootstrap maps;
- standalone `lld-link` `cc_tool` wrappers and their capabilities;
- source-stage `cc_tool` wrapper creation for `lld-link`, replacing it with the
  raw staged `bin/lld-link` needed as clang-cl data;
- direct-link `/OUT:` generation in favor of `/Fe`;
- tests and comments requiring the Bazel action executable itself to be
  `lld-link`;
- contract wording that calls the Bazel response file a direct lld-link
  response file.

Move the configured-linker, dynamic-linker, and interface-library capabilities
to the clang-cl action tool. Keep the raw `lld-link[.exe]` in every prebuilt and
source-built package and in `TOOLCHAIN_BINARIES`.

Must remain:

- the MSVC link argument adapter and rules_cc overrides;
- explicit Windows SDK/UCRT and filtered `/MD`/`/MT` VCRuntime library trees;
- `windows_case_copy`; the driver does not make lld-link's filesystem
  case-insensitive;
- `windows_case_vfs`; compile/header lookup is unchanged;
- the portable DEF parser and its license;
- `/NODEFAULTLIB` plus ordered explicit CRT/provider libraries;
- explicit static `libc++.lib` and compiler-rt builtins inputs;
- `/WHOLEARCHIVE`, DEF, declared `.if.lib`, PDB, PE/COFF, CRT, and native
  behavior verification;
- llvm-ar and its archive response-file protocol.

Do not introduce `/winsysroot`, driver-discovered SDK/CRT libraries, automatic
libc++ linking, driver-discovered compiler-rt, Microsoft STL selection,
sanitizers, or llvm-lib personality in this migration.

## Contract amendments requiring owner approval

Before implementation, record one decision superseding Phase 0 and Layer 1's
direct-link wording:

1. the Bazel link action executable is clang-cl; lld-link is a declared child
   tool selected with `/clang:-fuse-ld=lld`;
2. `/Fe` owns the driver output while the child linker still receives its
   translated `-out:`;
3. the declared UTF-8 Bazel response file is a clang-cl link-driver response
   file; any UTF-16 child spill file is internal to the action;
4. public `linkopts` remain LINK syntax and are individually forwarded with
   `-Xlinker`.

The current instruction approves investigation and planning. Implementation
should start only after the owner confirms these exact amendments. Any request
to change public `linkopts`, introduce `/winsysroot`, rely on host discovery,
or alter redistribution/EULA/CI-secret behavior is a separate stop decision.

## Execution plan

### 1. Freeze baseline and amend contracts

- Re-run x64 and ARM64 `/MD` and `/MT` action queries at `b9b18f6`.
- Save the direct action tool, argv, environment, inputs, outputs, and response
  contents for differential comparison.
- Update `PLAN.md`, the Phase 0 ledger, and the Layer 1 goal record with the
  approved superseding decision. Do not edit README files.
- Rollback point: documentation-only commit.

### 2. Change tool packaging and maps

- Add raw sibling `lld-link[.exe]` to clang-cl `cc_tool.data` for every prebuilt
  host.
- Map MSVC link actions to clang-cl and move link capabilities to that tool.
- In bootstrap stages, keep raw `bin/lld-link`, add it to staged clang-cl data,
  and remove only the unused standalone lld-link `cc_tool` wrapper.
- Add link-only `-no-canonical-prefixes` and prove staged `InstalledDir` points
  at the stage directory for LLVM 21/default/23.
- Rollback point: tool-map commit; compile actions must remain unchanged.

### 3. Translate the link argument surface

- Extend target-triple args to link actions without adding the compile-only
  compatibility flag there.
- Add `/clang:-fuse-ld=lld` and `/Fe{output_execpath}` driver arguments.
- Wrap every linker-owned generated, legacy, and user LINK argument in an
  individual `-Xlinker` pair.
- Keep ordinary files as driver inputs; wrap only whole-archive libraries.
- Use `-Xlinker /DLL`, never `/LD`.
- Add controlled `LIB`, `CL`, and `_CL_` link environments and retain
  `/lldignoreenv`.
- Keep explicit libc++, compiler-rt, SDK, CRT, DEF, import-library, and PDB
  inputs/outputs.
- Rollback point: one link-protocol commit with the prior action golden.

### 4. Focused risk tests

- Update `windows_msvc_action_test.sh` to require clang-cl as the CppLink tool,
  both target triples, `/clang:-fuse-ld=lld`, `/Fe`, `-Xlinker` pairing,
  declared lld-link input, controlled environment, whole archive, DEF,
  `.if.lib`, PDB, libc++, compiler-rt, and absence of bare direct LINK options.
- Add the smallest cross-host driver translation check needed to prove no
  discovered VC/SDK libpaths enter the child command. Prefer a `-###` probe in
  the existing host job; do not add a general assertion framework.
- Keep artifact, behavior, and analysis tests unchanged except where they name
  the top-level link tool.
- Prove a long/non-ASCII link response file through the real action.

### 5. Differential and matrix verification

From `e2e/rules_cc`:

```sh
bazel test --config=remote //:windows_msvc_artifacts_matrix
bash ./windows_msvc_action_test.sh --config=remote
bash ./windows_msvc_analysis_test.sh --config=remote
bazel build --config=remote //:main
```

Also run x64/ARM64 `/MD` and `/MT` behavior builds, debug PDB, ordinary DLL,
explicit DEF, generated DEF, import-library consumer, and alwayslink cells.
Compare pre/post PE/COFF/archive/PDB machine type, directives, imports, exports,
subsystem, interface library, CodeView path, and retained alwayslink symbol.

Inspect action graphs in addition to exit status:

```sh
bazel aquery --config=remote --include_param_files --output=text \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  'mnemonic("CppLink", //:windows_msvc_libcxx_behavior_md)'
bazel aquery --config=remote --include_param_files --output=text \
  --platforms=@llvm//platforms:windows_aarch64_msvc \
  'mnemonic("CppLink", //:windows_msvc_libcxx_behavior_md)'
```

For LLVM 21.1.8, 22.1.8, and 23.1.0-rc1, build the source-stage representative
with `--@llvm//toolchain:bootstrap_stage=stage1_from_source` and prove the
action declares and executes the same-stage clang-cl and sibling lld-link.

Exercise local actions on Linux x86-64/ARM64, macOS x86-64/ARM64, and Windows
x86-64/ARM64. On Windows, execute matching target binaries natively. On every
host, verify target CPU never selects the exec binary and host SDK/VS discovery
does not alter argv or artifacts.

Finally run Buildifier on changed BUILD/Starlark files, `git diff --check`, the
normal repository CI matrix, and rerun/fix until the latest commit is green.

## Acceptance criteria

- Every MSVC CppLink action executes clang-cl and declares its runnable sibling
  lld-link; no action executes link.exe or a host linker.
- x64 and ARM64 child links are selected by explicit target triple and retain
  explicit machine flags.
- No terminal `/link`, bare unforwarded LINK option, GNU `-Wl,`, discovered VC
  path, host SDK path, or host environment input appears.
- Public LINK-syntax `linkopts`, option ordering, response-file quoting, and
  user subsystem override behavior remain intact.
- `/MD` and `/MT` retain exactly their approved explicit CRT closures;
  libc++.lib and compiler-rt builtins remain declared once.
- Executables, DLLs, `.if.lib`, PDBs, DEF flows, whole archive, and native
  behavior match the direct-link baseline for x64 and ARM64.
- Prebuilt and source-built LLVM 21/default/23 pass; all six claimed execution
  hosts execute their own tools.
- MinGW and other platform action graphs/artifacts are unchanged.
- No README, redistribution, EULA, CI-secret, Microsoft STL, sanitizer, or
  llvm-lib scope change.

## Unresolved proof tasks

- Confirm rules_cc preserves per-value `-Xlinker` pairing inside the actual
  materialized Windows-quoted parameter file on all six hosts.
- Confirm an empty `LIB` value survives Bazel action-environment serialization
  on Windows; use a nonempty sentinel if it does not.
- Confirm user `/SUBSYSTEM:WINDOWS` remains later than the default after driver
  translation; adjust feature ordering, not public syntax, if needed.
- Confirm the staged symlink plus direct `-no-canonical-prefixes` behaves the
  same on native Windows; fall back to copying clang-cl only if that proof
  fails.
- Confirm clang-cl's optional internal UTF-16 child response file stays inside
  the sandbox and creates no undeclared persistent output.

Failure of any item is a rollback to direct `lld-link`, not permission to weaken
hermetic inputs, outputs, CRT isolation, or the public linkopts contract.
