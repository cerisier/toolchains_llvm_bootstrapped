#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo >&2 "$@"
  exit 1
}

assert_contains() {
  local file="$1"
  local value="$2"
  grep -Fq -- "${value}" "${file}" || fail "${file} does not contain: ${value}"
}

assert_matches() {
  local file="$1"
  local pattern="$2"
  grep -Eqi -- "${pattern}" "${file}" || fail "${file} does not match: ${pattern}"
}

assert_absent() {
  local file="$1"
  local value="$2"
  if grep -Fiq -- "${value}" "${file}"; then
    fail "${file} unexpectedly contains: ${value}"
  fi
}

assert_before() {
  local file="$1"
  local first="$2"
  local second="$3"
  local first_line
  local second_line
  first_line="$(grep -Finm1 -- "${first}" "${file}" | cut -d: -f1 || true)"
  second_line="$(grep -Finm1 -- "${second}" "${file}" | cut -d: -f1 || true)"
  [[ -n "${first_line}" && -n "${second_line}" && "${first_line}" -lt "${second_line}" ]] ||
    fail "${file} does not order ${first} before ${second}"
}

action_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/windows-msvc-system-headers.XXXXXX")"

for target_platform in windows_x86_64_msvc windows_aarch64_msvc; do
  case "${target_platform}" in
    windows_x86_64_msvc)
      target_triple="x86_64-pc-windows-msvc"
      ;;
    windows_aarch64_msvc)
      target_triple="aarch64-pc-windows-msvc"
      ;;
    *)
      fail "unsupported test platform: ${target_platform}"
      ;;
  esac

  platform_flags=(
    "$@"
    "--platforms=@llvm//platforms:${target_platform}"
    --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
    --repo_env=BAZEL_WINDOWS_SDK_EULA=1
    --features=layering_check
  )
  command_file="${action_dir}/${target_platform}-command.txt"
  command_args_file="${action_dir}/${target_platform}-command-args.txt"
  action_file="${action_dir}/${target_platform}-action.txt"

  bazel --bazelrc=.bazelrc build "${platform_flags[@]}" \
    //:windows_msvc_system_headers

  bazel --bazelrc=.bazelrc aquery "${platform_flags[@]}" \
    --features=-compiler_param_file \
    --output=commands \
    'inputs("windows_msvc_system_headers[.]cc", mnemonic("CppCompile", //:windows_msvc_system_headers))' \
    >"${command_file}"
  tr ' ' '\n' <"${command_file}" >"${command_args_file}"

  bazel --bazelrc=.bazelrc aquery "${platform_flags[@]}" \
    --include_param_files \
    --output=text \
    'inputs("windows_msvc_system_headers[.]cc", mnemonic("CppCompile", //:windows_msvc_system_headers))' \
    >"${action_file}"

  assert_contains "${command_file}" "bin/clang-cl"
  assert_contains "${command_file}" "--target=${target_triple}"
  assert_contains "${command_file}" "/clang:-ivfsoverlay"
  assert_contains "${command_file}" "/clang:-Xclang /clang:-fmodule-map-file-home-is-cwd"
  assert_contains "${command_file}" "/clang:-fmodules-strict-decluse"
  assert_contains "${command_file}" "/clang:-Wprivate-header"
  assert_contains "${command_file}" "/clang:-fno-cxx-modules"
  assert_contains "${command_file}" "/clang:-fmodule-name=//:windows_msvc_system_headers"
  assert_matches "${command_file}" "/clang:-fmodule-map-file=[^ ]*windows_msvc_system_headers[.]cppmap"
  assert_matches "${command_file}" "/clang:-fmodule-map-file=[^ ]*module_map[.]modulemap"

  assert_before "${command_args_file}" "libcxx_headers_include_search_directory" "/clang:-nobuiltininc"
  assert_before "${command_args_file}" "/clang:-nobuiltininc" "/lib/clang/"
  assert_before "${command_args_file}" "/lib/clang/" "msvc_com_support_headers_source"
  assert_before "${command_args_file}" "msvc_com_support_headers_source" "msvc_vcruntime_headers_source"
  assert_before "${command_args_file}" "msvc_vcruntime_headers_source" "/ucrt"
  assert_before "${command_args_file}" "/ucrt" "/shared"
  assert_before "${command_args_file}" "/shared" "/um"
  assert_before "${command_args_file}" "/um" "/winrt"

  assert_contains "${action_file}" "Execution platform: @@llvm++rbe_platform_repository+rbe_platform//:rbe_linux_"
  assert_contains "${action_file}" "libcxx_headers_include_search_directory"
  assert_matches "${action_file}" "lib/clang/[0-9]+/include"
  assert_contains "${action_file}" "msvc_com_support_headers_source"
  assert_contains "${action_file}" "msvc_vcruntime_headers_source"
  assert_contains "${action_file}" "msvc_sdk_header_case_overlay.yaml"
  assert_matches "${action_file}" "/ucrt/stdio[.]h"
  assert_matches "${action_file}" "/shared/minwindef[.]h"
  assert_matches "${action_file}" "/um/windows[.]h"
  assert_matches "${action_file}" "/winrt/winstring[.]h"

  for action_output in "${command_file}" "${action_file}"; do
    assert_absent "${action_output}" "mingw"
    assert_absent "${action_output}" "winpthreads"
    assert_absent "${action_output}" "msvc_include"
    assert_absent "${action_output}" "windows_support++msvc_runtime"
    assert_absent "${action_output}" "/usr/include"
    assert_absent "${action_output}" "/Applications/"
    assert_absent "${action_output}" "C:\\Program Files"
  done

  echo "Verified Windows MSVC system headers for ${target_platform}"
done
