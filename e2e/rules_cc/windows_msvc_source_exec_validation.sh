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
    sed -n '/Command Line:/,$p' "${file}" | awk 'NR <= 80 { print }' >&2
    fail "${file} does not contain: ${value}"
  fi
}

assert_matches() {
  local file="$1"
  local pattern="$2"
  if ! grep -Eq -- "${pattern}" "${file}"; then
    sed -n '/Command Line:/,$p' "${file}" | awk 'NR <= 80 { print }' >&2
    fail "${file} does not match: ${pattern}"
  fi
}

case "${1:-${RUNNER_ARCH:-}}" in
  X64 | x64 | x86_64 | AMD64 | amd64)
    exec_cpu="x86_64"
    ;;
  ARM64 | arm64 | aarch64)
    exec_cpu="aarch64"
    ;;
  *)
    fail "usage: $0 <X64|ARM64>"
    ;;
esac

runner_temp="${RUNNER_TEMP:-/tmp}"
if command -v cygpath >/dev/null 2>&1; then
  runner_temp="$(cygpath -u "${runner_temp}")"
fi
validation_dir="$(mktemp -d "${runner_temp}/windows-msvc-source-exec.XXXXXX")"

# Keep the already-fetched external repositories, but remove prior outputs and
# avoid repository-cache copies. The source-built LLVM outputs need the runner
# disk that would otherwise be consumed by duplicate repository trees.
bazel --bazelrc=.bazelrc clean

native_flags=(
  --remote_executor=
  --remote_cache=
  --experimental_remote_downloader=
  --repository_cache=
  --repo_contents_cache=
  --spawn_strategy=local
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1
  --@llvm//toolchain:bootstrap_stage=stage1_from_source
)

run_bazel() {
  local command="$1"
  shift
  bazel \
    --bazelrc=.bazelrc \
    "${command}" \
    "${native_flags[@]}" \
    "$@"
}

echo "Native MSVC source-bootstrap validation: exec_cpu=${exec_cpu}, reports=${validation_dir}"

for target_cpu in x86_64 aarch64; do
  case "${target_cpu}" in
    x86_64)
      target_triple="x86_64-pc-windows-msvc"
      ;;
    aarch64)
      target_triple="aarch64-pc-windows-msvc"
      ;;
  esac

  platform="@llvm//platforms:windows_${target_cpu}_msvc"
  compile_report="${validation_dir}/${target_cpu}-compile.txt"
  link_report="${validation_dir}/${target_cpu}-link.txt"

  run_bazel aquery \
    "--platforms=${platform}" \
    --features=-compiler_param_file \
    --output=commands \
    'mnemonic("CppCompile", //:windows_msvc_crt_default_probe)' \
    >"${compile_report}"
  run_bazel aquery \
    "--platforms=${platform}" \
    --include_param_files \
    --output=commands \
    'mnemonic("CppLink", //:windows_msvc_generated_def_thinlto_binary)' \
    >"${link_report}"

  for report in "${compile_report}" "${link_report}"; do
    assert_matches "${report}" "stage1_windows_${exec_cpu}[/\\\\]bin[/\\\\]clang-cl"
    assert_contains "${report}" "--target=${target_triple}"
  done
  assert_contains "${link_report}" "/clang:-fuse-ld=lld"

  run_bazel build \
    "--platforms=${platform}" \
    --features=-dynamic_link_msvcrt \
    --features=static_link_msvcrt \
    //:windows_msvc_generated_def_thinlto_binary \
    //:windows_msvc_libcxx_behavior_mt
done

run_bazel test \
  "--platforms=@llvm//platforms:windows_${exec_cpu}_msvc" \
  --features=-dynamic_link_msvcrt \
  --features=static_link_msvcrt \
  //:windows_msvc_libcxx_behavior_mt

echo "Native Windows source-built clang-cl MSVC execution validation passed."
