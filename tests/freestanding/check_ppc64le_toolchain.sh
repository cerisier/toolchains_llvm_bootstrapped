#!/usr/bin/env bash

set -euo pipefail

readonly target=//tests/freestanding:ppc64le_object
readonly platform=//tests/freestanding:linux_ppc64le
readonly bootstrap_stage=stage1_from_source

command_args=()
if [[ -n "${BAZEL_REMOTE_HEADER:-}" ]]; then
  command_args+=("--remote_header=${BAZEL_REMOTE_HEADER}")
fi

bazel "$@" build "${command_args[@]}" \
  --platforms="${platform}" \
  --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
  --remote_download_outputs=toplevel \
  "${target}"

target_line=$(
  bazel "$@" cquery "${target}" \
    "${command_args[@]}" \
    --platforms="${platform}" \
    --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
    --output=label
)
target_config=${target_line##* (}
target_config=${target_config%)}

bad_target_runtime_deps=$(
  bazel "$@" cquery "deps(${target})" \
    "${command_args[@]}" \
    --platforms="${platform}" \
    --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
    --output=label |
    awk -v config="(${target_config})" '$NF == config' |
    grep -E '(@llvm//runtimes/(cxxstdlib|glibc|musl)|@llvm-project//(compiler-rt|libcxx|libcxxabi)|@glibc|@musl)' || true
)

if [[ -n "${bad_target_runtime_deps}" ]]; then
  echo "linux+ppc64le selected hosted target runtimes:" >&2
  echo "${bad_target_runtime_deps}" >&2
  exit 1
fi

compile_actions=$(bazel "$@" aquery "mnemonic(CppCompile, ${target})" \
  "${command_args[@]}" \
  --platforms="${platform}" \
  --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}")
if ! grep -q -- 'powerpc64le-linux-gnu' <<<"${compile_actions}"; then
  echo "linux+ppc64le did not select the powerpc64le-linux-gnu compiler triple" >&2
  exit 1
fi

archive=$(bazel "$@" cquery "${target}" \
  "${command_args[@]}" \
  --platforms="${platform}" \
  --@llvm//toolchain:bootstrap_stage="${bootstrap_stage}" \
  --output=files | grep -E '\.a$' | head -n 1)
elf_header=$(readelf -h "${archive}")

grep -q 'Class:.*ELF64' <<<"${elf_header}"
grep -q "Data:.*little endian" <<<"${elf_header}"
grep -q 'Type:.*REL' <<<"${elf_header}"
grep -q 'Machine:.*PowerPC64' <<<"${elf_header}"
