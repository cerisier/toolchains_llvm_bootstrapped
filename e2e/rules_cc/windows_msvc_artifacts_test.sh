#!/usr/bin/env bash
set -euo pipefail

found_pe=0
found_archive=0
pe_artifacts=()
pdb_basenames=()

assert_exception_provider_imports() {
  local artifact="$1"
  local imports
  local msvcp_symbols
  imports="$("${LLVM_READOBJ}" --coff-imports "${artifact}")"
  msvcp_symbols="$(awk '
    /^  Name: MSVCP140\.dll$/ { in_msvcp = 1; next }
    in_msvcp && /^  Symbol: / {
      sub(/^  Symbol: /, "")
      sub(/ \([0-9]+\)$/, "")
      print
    }
    in_msvcp && /^}/ { exit }
  ' <<<"${imports}")"

  if [[ "${CRT_MODE}" == "MT" ]]; then
    if [[ -n "${msvcp_symbols}" || "${imports}" == *"Name: VCRUNTIME140.dll"* || "${imports}" == *"Name: api-ms-win-crt-"* ]]; then
      echo "static-CRT libc++ artifact imports a dynamic Microsoft runtime: ${artifact}" >&2
      exit 1
    fi
    return
  fi

  local allowed
  local symbol
  allowed=$'?__ExceptionPtrAssign@@YAXPEAXPEBX@Z\n?__ExceptionPtrCompare@@YA_NPEBX0@Z\n?__ExceptionPtrCopy@@YAXPEAXPEBX@Z\n?__ExceptionPtrCopyException@@YAXPEAXPEBX1@Z\n?__ExceptionPtrCreate@@YAXPEAX@Z\n?__ExceptionPtrCurrentException@@YAXPEAX@Z\n?__ExceptionPtrDestroy@@YAXPEAX@Z\n?__ExceptionPtrRethrow@@YAXPEBX@Z\n?__ExceptionPtrSwap@@YAXPEAX0@Z\n?__ExceptionPtrToBool@@YA_NPEBX@Z\n?uncaught_exceptions@std@@YAHXZ'
  while IFS= read -r symbol; do
    [[ -z "${symbol}" ]] && continue
    if ! grep -Fqx -- "${symbol}" <<<"${allowed}"; then
      echo "unexpected MSVCP140 helper import ${symbol} in ${artifact}" >&2
      exit 1
    fi
  done <<<"${msvcp_symbols}"
}

for artifact in ${ARTIFACTS}; do
  if [[ ! -s "${artifact}" ]]; then
    echo "missing or empty Windows artifact: ${artifact}" >&2
    exit 1
  fi
  case "${artifact}" in
    *.exe|*.dll)
      found_pe=1
      pe_artifacts+=("${artifact}")
      case "$(basename "${artifact}")" in
        windows_msvc_libcxx_behavior_static.exe|windows_msvc_libcxx_behavior_dynamic_link.exe|windows_msvc_libcxx_exception_ptr.exe|windows_msvc_libcxx_dynamic_link_exception_ptr.exe)
          assert_exception_provider_imports "${artifact}"
          ;;
      esac
      if [[ -n "${ARTIFACT_ASSERT:-}" ]]; then
        "${ARTIFACT_ASSERT}" \
          -file "${artifact}" \
          -kind pe \
          -machine "${MACHINE}" \
          -llvm-readobj "${LLVM_READOBJ}" \
          -llvm-objdump "${LLVM_OBJDUMP}" \
          -absent "mingw" >/dev/null
      fi
      ;;
    *.lib)
      found_archive=1
      if [[ "$(basename "${artifact}")" == "windows_msvc_libcxx_behavior_support.lib" ]] &&
        ! "${LLVM_NM}" -u "${artifact}" | grep -Fq -- "__udivti3"; then
        echo "libc++ behavior archive did not exercise compiler-rt wide division: ${artifact}" >&2
        exit 1
      fi
      if [[ -n "${ARTIFACT_ASSERT:-}" ]]; then
        "${ARTIFACT_ASSERT}" \
          -file "${artifact}" \
          -kind archive \
          -machine "${MACHINE}" \
          -llvm-ar "${LLVM_AR}" \
          -llvm-nm "${LLVM_NM}" \
          -llvm-readobj "${LLVM_READOBJ}" \
          -absent "mingw" >/dev/null
      fi
      ;;
    *.pdb)
      pdb_basenames+=("$(basename "${artifact}")")
      if [[ -n "${ARTIFACT_ASSERT:-}" ]]; then
        "${ARTIFACT_ASSERT}" \
          -file "${artifact}" \
          -kind pdb \
          -contains "Microsoft C/C++ MSF 7.00" >/dev/null
      fi
      ;;
  esac
done

if [[ "${EXPECT_PDB:-0}" == 1 && ${#pdb_basenames[@]} == 0 ]]; then
  echo "no declared PDB was exposed by the debug transitioned targets" >&2
  exit 1
fi

if (( ${#pdb_basenames[@]} > 0 )); then
  for pdb_basename in "${pdb_basenames[@]}"; do
    matched=0
    for pe_artifact in "${pe_artifacts[@]}"; do
      if "${ARTIFACT_ASSERT}" \
        -file "${pe_artifact}" \
        -kind pe \
        -machine "${MACHINE}" \
        -llvm-readobj "${LLVM_READOBJ}" \
        -llvm-objdump "${LLVM_OBJDUMP}" \
        -contains "PDBFileName: ${pdb_basename}" >/dev/null 2>&1; then
        matched=1
        break
      fi
    done
    if [[ "${matched}" != 1 ]]; then
      echo "no PE CodeView record references declared PDB ${pdb_basename}" >&2
      exit 1
    fi
  done
fi

if [[ "${found_pe}" != 1 ]]; then
  echo "no PE executable or DLL was exposed by the transitioned targets" >&2
  exit 1
fi

if [[ "${EXPECT_ARCHIVE:-0}" == 1 && "${found_archive}" != 1 ]]; then
  echo "no COFF archive or import library was exposed by the transitioned targets" >&2
  exit 1
fi
