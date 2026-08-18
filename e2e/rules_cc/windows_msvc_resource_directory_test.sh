#!/usr/bin/env bash
set -euo pipefail

resolve_runfile() {
  local path="${1//\\//}"
  local -a keys=("${path}")

  if [[ -e "${path}" ]]; then
    printf '%s\n' "${path}"
    return 0
  fi

  case "${path}" in
    ./*)
      keys+=("_main/${path#./}")
      ;;
    ../*)
      keys+=("${path#../}")
      ;;
    *)
      keys+=("_main/${path}")
      ;;
  esac

  local key
  if [[ -n "${RUNFILES_DIR:-}" ]]; then
    for key in "${keys[@]}"; do
      if [[ -e "${RUNFILES_DIR}/${key}" ]]; then
        printf '%s\n' "${RUNFILES_DIR}/${key}"
        return 0
      fi
    done
  fi

  if [[ -n "${RUNFILES_MANIFEST_FILE:-}" ]]; then
    local manifest_key
    local manifest_value
    while IFS= read -r line; do
      manifest_key="${line%% *}"
      manifest_value="${line#* }"
      for key in "${keys[@]}"; do
        if [[ "${manifest_key}" == "${key}" ]]; then
          printf '%s\n' "${manifest_value}"
          return 0
        fi
      done
    done <"${RUNFILES_MANIFEST_FILE}"
  fi

  return 1
}

for tool in ARTIFACT_ASSERT LLVM_AR LLVM_NM LLVM_READOBJ; do
  path="${!tool}"
  if ! path="$(resolve_runfile "${path}")"; then
    echo "could not resolve runfile for ${tool}: ${!tool}" >&2
    exit 1
  fi
  printf -v "${tool}" '%s' "${path}"
done

found=0
for resource_dir_key in ${RESOURCE_DIRS}; do
  if ! resource_dir="$(resolve_runfile "${resource_dir_key}")"; then
    echo "could not resolve resource directory runfile: ${resource_dir_key}" >&2
    exit 1
  fi
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
