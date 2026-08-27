#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo >&2 "ERROR: cannot find $f"; exit 1; }
f=
set -e
# --- end runfiles.bash initialization v3 ---

set -euo pipefail

fail() {
  echo >&2 "$@"
  exit 1
}

resolve() {
  local key="${1//\\//}"
  local path
  path="$(rlocation "${key}")"
  [[ -e "${path}" ]] || fail "missing runfile: ${key}"
  printf '%s\n' "${path}"
}

LLVM_AR="$(resolve "${LLVM_AR}")"
LLVM_NM="$(resolve "${LLVM_NM}")"
LLVM_READOBJ="$(resolve "${LLVM_READOBJ}")"

found_md=0
found_mt=0
found_thinlto=0
found_dll_consumer=0
found_import_library=0
found_pdb=0
debug_executable=
debug_pdb=

machine_line_matches() {
  local machine="$1"
  grep -Eq "Machine: IMAGE_FILE_MACHINE_${machine}([[:space:]]|$)"
}

assert_machine() {
  local artifact="$1"
  "${LLVM_READOBJ}" --file-headers "${artifact}" |
    machine_line_matches "${MACHINE}" ||
    fail "wrong or missing ${MACHINE} machine in ${artifact}"
}

if printf '%s\n' 'Machine: IMAGE_FILE_MACHINE_ARM64EC (0xA641)' |
  machine_line_matches ARM64; then
  fail "ARM64 machine matcher also accepts ARM64EC"
fi

for artifact_key in ${ARTIFACTS}; do
  artifact="$(resolve "${artifact_key}")"
  basename="$(basename "${artifact}")"

  [[ -s "${artifact}" ]] || fail "missing or empty artifact: ${artifact}"

  case "${basename}" in
    c++.dll|libc++.dll)
      fail "dynamic libc++ artifact exposed: ${artifact}"
      ;;
    *.exe|*.dll)
      assert_machine "${artifact}"
      ;;
    *.lib)
      assert_machine "${artifact}"
      [[ -n "$("${LLVM_AR}" t "${artifact}")" ]] ||
        fail "empty COFF archive or import library: ${artifact}"
      ;;
    *.pdb)
      grep -a -Fq "Microsoft C/C++ MSF 7.00" "${artifact}" ||
        fail "invalid PDB signature: ${artifact}"
      found_pdb=1
      debug_pdb="${artifact}"
      ;;
  esac

  case "${basename}" in
    windows_msvc_libcxx_behavior_md.exe)
      imports="$("${LLVM_READOBJ}" --coff-imports "${artifact}")"
      grep -Fq "Name: VCRUNTIME140.dll" <<<"${imports}" ||
        fail "/MD behavior binary does not import VCRuntime"
      grep -Fq "Name: api-ms-win-crt-" <<<"${imports}" ||
        fail "/MD behavior binary does not import UCRT"
      found_md=1
      ;;
    windows_msvc_libcxx_behavior_mt.exe)
      imports="$("${LLVM_READOBJ}" --coff-imports "${artifact}")"
      if grep -Eq "Name: (MSVCP140|VCRUNTIME140|api-ms-win-crt-)" <<<"${imports}"; then
        fail "/MT behavior binary imports a dynamic Microsoft runtime"
      fi
      found_mt=1
      ;;
    windows_msvc_libcxx_behavior_thinlto.exe)
      found_thinlto=1
      ;;
    windows_msvc_libcxx_behavior_debug.exe)
      debug_executable="${artifact}"
      ;;
    windows_msvc_dll_behavior.exe)
      found_dll_consumer=1
      ;;
    windows_add.dll)
      "${LLVM_READOBJ}" --coff-exports "${artifact}" |
        grep -Fq "Name: add42" ||
        fail "dllexport DLL is missing add42"
      ;;
    windows_explicit_def.dll)
      "${LLVM_READOBJ}" --coff-exports "${artifact}" |
        grep -Fq "Name: explicit_add42" ||
        fail "explicit DEF DLL is missing explicit_add42"
      ;;
    windows_msvc_generated_def.dll)
      "${LLVM_READOBJ}" --coff-exports "${artifact}" |
        grep -Fq "Name: generated_add42" ||
        fail "generated DEF DLL is missing generated_add42"
      ;;
    *.if.lib)
      found_import_library=1
      ;;
    windows_msvc_libcxx_behavior_support.lib)
      "${LLVM_NM}" -u "${artifact}" | grep -Fq "__udivti3" ||
        fail "behavior archive does not exercise compiler-rt wide division"
      directives="$("${LLVM_READOBJ}" --coff-directives "${artifact}")"
      if grep -Fiq "defaultlib:libc++.lib" <<<"${directives}"; then
        fail "behavior archive contains a hidden libc++ auto-link directive"
      fi
      ;;
  esac
done

[[ "${found_md}" == 1 ]] || fail "missing /MD behavior executable"
[[ "${found_mt}" == 1 ]] || fail "missing /MT behavior executable"
[[ "${found_thinlto}" == 1 ]] || fail "missing ThinLTO behavior executable"
[[ "${found_dll_consumer}" == 1 ]] || fail "missing DLL consumer executable"
[[ "${found_import_library}" == 1 ]] || fail "missing declared import library"
[[ "${found_pdb}" == 1 ]] || fail "missing declared PDB"
[[ -n "${debug_executable}" ]] || fail "missing debug executable"
[[ -n "${debug_pdb}" ]] || fail "missing debug PDB"

"${LLVM_READOBJ}" --coff-debug-directory "${debug_executable}" |
  grep -Fq "PDBFileName: $(basename "${debug_pdb}")" ||
  fail "debug executable does not reference its declared PDB"
