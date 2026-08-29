#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo >&2 "$@"
  exit 1
}

assert_contains() {
  local file="$1"
  local value="$2"
  if ! grep -Fq -- "${value}" "${file}"; then
    sed -n '1,200p' "${file}" >&2
    fail "${file} does not contain: ${value}"
  fi
}

layering_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/windows-msvc-layering.XXXXXX")"

for target_platform in windows_x86_64_msvc windows_aarch64_msvc; do
  platform_flags=(
    "$@"
    "--platforms=@llvm//platforms:${target_platform}"
    --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
    --repo_env=BAZEL_WINDOWS_SDK_EULA=1
  )

  bazel --bazelrc=.bazelrc build "${platform_flags[@]}" \
    --features=layering_check \
    //layering:direct_consumer

  bazel --bazelrc=.bazelrc build "${platform_flags[@]}" \
    --features=-layering_check \
    //layering:illegal_transitive_consumer

  illegal_log="${layering_dir}/${target_platform}-illegal.log"
  if bazel --bazelrc=.bazelrc build "${platform_flags[@]}" \
    --features=layering_check \
    //layering:illegal_transitive_consumer \
    >"${illegal_log}" 2>&1; then
    fail "${target_platform} accepted a transitive-only include with layering_check"
  fi

  assert_contains "${illegal_log}" \
    "module //layering:illegal_transitive_consumer does not depend on a module exporting"
  assert_contains "${illegal_log}" "'layering/transitive.h'"
  echo "Verified Windows MSVC layering behavior for ${target_platform}"
done
