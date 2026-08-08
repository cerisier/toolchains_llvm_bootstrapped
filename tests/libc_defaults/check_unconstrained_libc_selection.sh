#!/usr/bin/env bash

set -euo pipefail

readonly runtime_target=//runtimes/compiler-rt:clang_rt.builtins.static
readonly riscv_platform=//tests/libc_defaults:linux_riscv64_unconstrained
readonly x86_platform=//tests/libc_defaults:linux_x86_64_unconstrained

command_args=(--noannounce_rc)
if [[ -n "${BAZEL_REMOTE_HEADER:-}" ]]; then
  command_args+=("--remote_header=${BAZEL_REMOTE_HEADER}")
fi

bazel "$@" build "${command_args[@]}" \
  --platforms="${riscv_platform}" \
  --remote_download_outputs=toplevel \
  "${runtime_target}"

verify_selection() {
  local platform=$1
  local required_glibc=$2
  local required_kernel=$3
  local forbidden_glibc=$4
  local forbidden_kernel=$5
  local dependencies
  shift 5

  dependencies=$(
    bazel "$@" cquery "deps(${runtime_target})" \
      "${command_args[@]}" \
      --platforms="${platform}" \
      --output=label
  )

  for required in "${required_glibc}" "${required_kernel}"; do
    if ! grep -Fq -- "${required}" <<<"${dependencies}"; then
      echo "${platform} did not select required dependency ${required}" >&2
      exit 1
    fi
  done

  for forbidden in "${forbidden_glibc}" "${forbidden_kernel}"; do
    if grep -Fq -- "${forbidden}" <<<"${dependencies}"; then
      echo "${platform} unexpectedly selected dependency ${forbidden}" >&2
      exit 1
    fi
  done
}

verify_selection \
  "${riscv_platform}" \
  "glibc_headers_riscv64-linux-gnu.2.33//:gnu_libc_headers" \
  "linux_kernel_headers_riscv.5.12.19//:kernel_headers" \
  "glibc_headers_riscv64-linux-gnu.2.28" \
  "linux_kernel_headers_riscv.4.19.325" \
  "$@"

verify_selection \
  "${x86_platform}" \
  "glibc_headers_x86_64-linux-gnu.2.28//:gnu_libc_headers" \
  "linux_kernel_headers_x86.4.19.325//:kernel_headers" \
  "glibc_headers_x86_64-linux-gnu.2.33" \
  "linux_kernel_headers_x86.5.12.19" \
  "$@"
