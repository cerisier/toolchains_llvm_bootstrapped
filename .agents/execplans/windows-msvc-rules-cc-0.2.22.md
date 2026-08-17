# rules_cc 0.2.22 MSVC protocol inventory

Status: frozen Phase 0 compatibility contract.

Repository pin: `rules_cc` `0.2.22` in `MODULE.bazel`.

Source inspected:
`/Users/corentinkerisit/Library/Caches/bazel/_bazel_corentinkerisit/55248edb19ed16fc105ac66e2d645152/external/rules_cc+`.

## Classification

- **Reuse**: 0.2.22 protocol is dialect-neutral or already exact.
- **Local replacement**: hermetic-llvm owns an MSVC form and overrides or
  excludes the generic expansion.
- **No-op**: deliberately absent and never advertised as support.
- **Unsupported error**: known request fails analysis with stable text.

`cc_feature(overrides=...)` is only a mechanism. The proof requirement is:
generic/GNU expansion count zero, MSVC expansion count one, and no legacy
backfill restores the generic form.

## Identity, action, and output protocol

| Surface | 0.2.22 protocol | Disposition |
|---|---|---|
| compiler identity | `compiler` string and feature configuration | local value `clang-cl`; target ABI selects it |
| tool map | action configs/tools | local clang-cl compile, llvm-ar archive, direct lld-link link |
| target/exec split | platform/toolchain resolution | reuse; never infer target ABI from exec OS |
| compile actions | C/C++ compile, linkstamp; preprocess/assembly variants | local replacement for supported actions; unsupported error for unported forms |
| archive action | static library action | local deterministic `llvm-ar rcsD` through Layer 3 |
| link actions | executable/dynamic-nodeps/dynamic | local direct LINK dialect |
| ThinLTO actions | index/backend/final variables/actions | unsupported error until separate proof |
| object pattern | artifact category | local `.obj` |
| static library | artifact category | local `.lib` |
| alwayslink library | artifact category plus final-link semantics | local approved suffix; `/WHOLEARCHIVE:` at link, not archive dialect |
| executable | artifact category | local `.exe` |
| dynamic library | artifact category | local `.dll` |
| interface library | native Windows pattern | reuse `.if.lib` and declared interface output |
| PDB | `generate_pdb_file` declares sibling output | reuse declaration/default lld name; no invented variable |

## Compile argument protocol

| Surface/variable | Disposition | Exact contract |
|---|---|---|
| source input | local replacement | `/c <source>` with explicit C/C++ selection where needed |
| `output_file` | local replacement | `/Fo<declared .obj>` |
| assembly/preprocess outputs | local replacement or unsupported | `/Fa`, `/P`/`/Fi` only with declared outputs |
| preprocessor defines | local replacement | `/D`, `/U`; quoting golden |
| forced includes | local replacement | `/FI` |
| include paths | local replacement | `/I`; system/external uses proven `/imsvc` or audited equivalent |
| user compile flags | reuse ordering, local dialect | public `copts` are clang-cl syntax |
| dependency file | local replacement | `/clang:-MD /clang:-MF /clang:<dependency_file>` |
| ShowIncludes variables | no-op | comparative probe only; no `parse_showincludes`/`no_dotd_file` hybrid |
| compiler param file | local replacement | UTF-8 CL quoting; declared input |
| random seed | local replacement | no GNU `-frandom-seed`; `/Brepro` and path privacy own determinism |
| PIC/force PIC | no-op | no PIC feature or `-fPIC` on COFF |
| module/layering flags | unsupported until proven | no clang++ wrapper with CL arguments |
| ObjC/ObjC++ | unsupported error | unclaimed MSVC action |
| warning/optimization/debug | local replacement | CL spelling; retail CRT under `dbg`; `/Z7` initially |

## Archive argument protocol

| Surface/variable | Disposition | Exact contract |
|---|---|---|
| archive output | local replacement | one `rcsD <declared output>` |
| object inputs | local replacement | object and object-group expansion in stable order |
| archive param file | local replacement | UTF-8 llvm-ar syntax and quoting |
| alwayslink | no archive mutation | final link adds `/WHOLEARCHIVE:<library>` |
| `/OUT` `/MACHINE` | no-op through Layer 3 | llvm-lib-only dialect deferred to Layer 4 |

## Link argument and variable protocol

| Surface/variable | Disposition | Exact contract |
|---|---|---|
| `output_execpath` | local replacement | `/OUT:<path>` |
| dynamic-library mode | local replacement | `/DLL` |
| library search dirs | local replacement | `/LIBPATH:<path>` |
| `libraries_to_link` object/object group | local replacement | direct ordered paths |
| static/interface libraries | local replacement | direct paths |
| dynamic library form | local replacement | generated `.if.lib` for build-owned DLL |
| alwayslink | local replacement | `/WHOLEARCHIVE:<path>` only |
| `def_file_path` | local replacement | `/DEF:<path>` |
| `interface_library_output_path` | reuse variable, local flag | `/IMPLIB:%{interface_library_output_path}` |
| `generate_interface_library` | reuse protocol | must produce DLL plus declared `.if.lib` together |
| user link flags | reuse ordering, local dialect | public `linkopts` are direct LINK syntax |
| linker param file | local replacement | UTF-8 LINK quoting; separate from ThinLTO params |
| subsystem/machine | local replacement | `/SUBSYSTEM:CONSOLE`; `/MACHINE:X64` or `ARM64` |
| debug/PDB | local replacement plus reuse declaration | `/DEBUG`; sibling default-name PDB |
| determinism | local replacement | `/Brepro /INCREMENTAL:NO` |
| soname/rpath/install-name | no-op | ELF/Mach-O-only forms absent |
| strip/fission | unsupported error | no GNU strip or split-DWARF form |
| coverage/profile/sanitizer inputs | unsupported by core | owning later capability must add exact form |
| ThinLTO variables | unsupported error | no generic `-Wl`/plugin flags |

## Feature/default/capability inventory

| Label or feature family | Disposition |
|---|---|
| `compiler_param_file` | local positive/negative test |
| `archive_param_file` | local positive/negative test |
| linker param-file feature | local positive/negative test |
| `windows_quoting_for_param_files` | reuse only after all three serializers pass |
| `supports_dynamic_linker` | enable for proven direct lld-link actions |
| `has_configured_linker_path` | enable with exact lld-link tool path |
| `supports_interface_shared_libraries` | enable with DLL/`.if.lib` end-to-end test |
| `targets_windows` | enable from target ABI/OS, not exec host |
| `copy_dynamic_libraries_to_binary` | enable only with physical DLL output proof |
| `supports_header_parsing` | disabled until coherent clang-cl parser action passes |
| `no_dotd_file`, `parse_showincludes` | disabled because `.d` is selected |
| `supports_start_end_lib` | known unsupported request -> analysis error |
| `supports_pic` | not advertised |
| `static_link_cpp_runtimes` | remains C++ runtime-linkage dimension, not CRT mode |
| `dynamic_link_msvcrt` | default; args conditioned on absence of static feature |
| `static_link_msvcrt` | opt-in; static wins |
| debug CRT features | known unsupported request -> analysis error |
| `experimental_replace_legacy_action_config_features` | audit backfill on every override |
| `backfill_legacy_args` implied set | differential golden; never assume override suppresses it |

Fact: rules_cc's feature constraints support `none_of` for argument
requirements. `cc_feature.implies` silently disables an implication when the
implied feature is unavailable. Converted legacy mutual-exclusion information
uses `provides`; neither behavior alone implements every required stable error.

Decision: use positive feature constraints for argument selection and an
explicit repository-owned validation path for invalid global feature states.
Unsupported public feature names are registered as known rejection paths so
Bazel cannot silently ignore them.

## Unsupported generic features/actions

| Surface | Result |
|---|---|
| PIC/force-PIC | deliberate no-op |
| soname/rpath/install-name | deliberate no-op |
| fission/split DWARF | unsupported error |
| GNU strip | unsupported error |
| GNU coverage/profile flags | unsupported until owning capability |
| start/end-lib | unsupported error |
| fully-static generic mode | unsupported error; use explicit CRT/runtime dimensions |
| ObjC/ObjC++ | unsupported error |
| C++ modules | unsupported error initially |
| assembler/preprocessed assembler variants | explicit per-action decision in Layer 1; no fallthrough |
| ThinLTO | unsupported error in core stack |
| OpenMP | unsupported initially |

## Upgrade-drift test design

For every future rules_cc version change:

1. record old/new module versions and source revisions;
2. enumerate `cc/toolchains/args`, `features`, `capabilities`, `variables`,
   artifacts, and legacy backfills;
3. diff label names, feature names, enabled defaults, `implies`, `overrides`,
   `provides`, variable availability, and action sets;
4. run local argument-expansion goldens for every row above;
5. assert GNU spelling count zero and MSVC spelling count one;
6. run real JSON `aquery` assertions for compiler, archive, executable, DLL,
   import library, PDB, tool paths, inputs, outputs, platform, environment, and
   response files;
7. inspect COFF/PE/archive/PDB artifacts;
8. run all invalid-feature analysis failures and existing MinGW regressions;
9. treat adoption of new upstream MSVC support as a separate equivalence
   refactor, not an automatic removal of the adapter.

## PR 187 provenance map

Command:

```sh
gh pr view 187 --json \
  number,title,state,isDraft,mergeable,headRefName,headRefOid,baseRefName,\
author,updatedAt,commits,files
shasum -a 256 /tmp/hermetic-llvm-pr187.diff
```

Facts:

- PR: hermeticbuild/hermetic-llvm #187, `DRAFT: Add MSVC target support`.
- author: `ArchangelX360` / Titouan Bion.
- state: open draft; mergeability `CONFLICTING`.
- head: `ef1eb169508b7f0461463c442e0e100ef575a90a`.
- updated: `2026-08-03T02:09:19Z`.
- reviewed diff SHA-256:
  `1d70d3f9cb2e025a177f81a770a9a4916cf22aaa7d6629eec9ac0cc9e5a9d0a9`.

| PR 187 area | Disposition |
|---|---|
| clang-cl identity and distinct tool maps | reimplement |
| direct deterministic llvm-ar | adopt behavior, reimplement |
| CL/LINK aggregation and COFF artifacts | requirements source; reimplement against 0.2.22 |
| `/DEF`, `/IMPLIB`, `/OUT`, `/DLL`, `/LIBPATH`, `/WHOLEARCHIVE` | adopt behavior with declared-output proofs |
| SDK/VCRuntime data | rederive against windows_support 0.2.0 |
| portable header parser | use only if selected `.d` model needs it |
| source aliases/bootstrap separation | adopt invariant |
| PR 187 ABI/platform definitions | reject; superseded by merged PR 709 |
| `/MDd`, `/MTd`, `_DEBUG` | reject |
| blanket sanitizer disablement/no-op features | reject |
| flattened include classes/suppress-unused-args | reject |
| `/Zm500`, broad warning/policy macros, unproved modules | reject |
| MinGW collateral/source exclusions | reject absent independent reproduction |
| libc++abi/libunwind Windows route | replace with libc++/VCRuntime |
| README claims | reject until owning proof and separate approval |

Provenance decision: materially adapted code receives
`Co-authored-by: Titouan Bion <titouan.bion@gmail.com>`. Independently
reimplemented behavior acknowledges PR 187 in the PR description without a
blanket trailer.

## rules_cc PR 561 provenance map

Command:

```sh
gh pr view 561 -R bazelbuild/rules_cc --json \
  number,title,state,isDraft,mergeable,headRefName,headRefOid,baseRefName,\
author,updatedAt,commits,files
shasum -a 256 /tmp/rules-cc-pr561.diff
```

Facts:

- PR: bazelbuild/rules_cc #561, `Support MSVC with rule-based toolchain`.
- author: `calebzulawski` / Caleb Zulawski.
- state: open, not draft; mergeability `CONFLICTING`.
- commits:
  `1e5e51f16173ad68cdd6df149aa08a229cd89c05` and
  `35e469c8494389343cce5410030fb1af46709f6e`.
- head: `35e469c8494389343cce5410030fb1af46709f6e`.
- updated: `2026-08-12T19:24:19Z`.
- reviewed diff SHA-256:
  `fb913d6fd6879369cab133d00396237986f036ceef18562be2506bb6ba9e583a`.

| PR 561 area | Disposition |
|---|---|
| compiler visibility/identity pattern | behavioral reference |
| compiler input/output, defines/includes | compare and selectively port |
| archive/library/link Windows args | behavioral oracle; local ownership remains |
| capability changes | compare against this inventory; do not depend on head |
| toolchain config/legacy converter changes | provenance source only; pin stays 0.2.22 |
| example clang-cl/MSVC toolchains | test-vector source, not production dependency |
| golden updates | derive local normative goldens |

Decision: copied Apache-licensed code records exact source commit and file in
the owning commit/PR. Behavior independently reconstructed from the protocol
does not receive ambiguous dual attribution.

## Protocol review result

No required Layer 1 output is unrepresentable in rules_cc 0.2.22:
`interface_library_output_path`, `.if.lib`, and sibling PDB declaration exist.
The gaps are owned argument/action adapters and stable validation paths, not
missing Bazel artifact categories. Layer 1 must implement and prove them; this
ledger does not claim that implementation already exists.
