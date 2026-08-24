#!/usr/bin/env bash
set -euo pipefail

expect_failure() {
  local name="$1"
  local expected="$2"
  shift 2
  local output="${RUNNER_TEMP:-/tmp}/${name}.log"
  if bazel --bazelrc=.bazelrc build "$@" >"${output}" 2>&1; then
    echo >&2 "${name} unexpectedly succeeded"
    exit 1
  fi
  if ! grep -Fq -- "${expected}" "${output}"; then
    echo >&2 "${name} did not report: ${expected}"
    sed -n '1,160p' "${output}" >&2
    exit 1
  fi
}

common_flags=(
  "$@"
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1
)

expect_failure \
  windows-msvc-libstdcxx \
  "Layer 1 MSVC ABI requires //constraints/cxxstdlib:libcxx" \
  "${common_flags[@]}" \
  --platforms=//:windows_x86_64_msvc_libstdcxx_invalid \
  //:windows_msvc_crt_default_probe

expect_failure \
  windows-msvc-missing-crt \
  "MSVC ABI requires exactly one retail CRT mode" \
  "${common_flags[@]}" \
  --features=-dynamic_link_msvcrt \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_crt_default_probe

expect_failure \
  windows-msvc-unsupported-feature \
  "is provided by all of the following features: msvc_supported_configuration asan" \
  "${common_flags[@]}" \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_unsupported_feature_probe

expect_failure \
  windows-msvc-header-parsing \
  "MSVC ABI Layer 1 does not support feature(s): parse_headers" \
  "${common_flags[@]}" \
  --features=-layering_check \
  --features=parse_headers \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_crt_default_probe

expect_failure \
  windows-msvc-dynamic-libcxx \
  "is incompatible" \
  "${common_flags[@]}" \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  @llvm-project//libcxx:libcxx.shared
