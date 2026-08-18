#!/usr/bin/env bash
set -euo pipefail

found=0
for resource_dir in ${RESOURCE_DIRS}; do
  builtins="${resource_dir}/lib/${TRIPLE}/clang_rt.builtins.lib"
  if [[ ! -s "${builtins}" ]]; then
    echo "missing MSVC compiler-rt builtins archive: ${builtins}" >&2
    exit 1
  fi
  if [[ -e "${resource_dir}/lib/${TRIPLE}/libclang_rt.builtins.a" ]]; then
    echo "unexpected MinGW compiler-rt builtins name under MSVC triple" >&2
    exit 1
  fi
  "${ARTIFACT_ASSERT}" \
    -file "${builtins}" \
    -kind archive \
    -machine "${MACHINE}" \
    -llvm-ar "${LLVM_AR}" \
    -llvm-nm "${LLVM_NM}" \
    -llvm-readobj "${LLVM_READOBJ}" \
    -absent "mingw" >/dev/null
  found=1
done

if [[ "${found}" != 1 ]]; then
  echo "no transitioned Clang resource directory was exposed" >&2
  exit 1
fi
