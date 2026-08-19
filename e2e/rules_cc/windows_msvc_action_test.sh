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

assert_absent() {
  local file="$1"
  local value="$2"
  if grep -Fq -- "${value}" "${file}"; then
    fail "${file} unexpectedly contains: ${value}"
  fi
}

action_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/windows-msvc-actions.XXXXXX")"
common_flags=(
  "$@"
  --include_param_files
  --output=text
  --platforms=@llvm//platforms:windows_x86_64_msvc
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1
)

bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  'mnemonic("CppCompile", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  'mnemonic("CppArchive", //:windows_msvc_libcxx_behavior_support)' \
  >"${action_dir}/archive.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  'mnemonic("CppLink", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/link.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  'mnemonic("DefParser", deps(//:windows_msvc_generated_def.dll))' \
  >"${action_dir}/def.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  'mnemonic("CppLink", //:windows_msvc_generated_def.dll)' \
  >"${action_dir}/dll-link.txt"

assert_contains "${action_dir}/compile.txt" "clang-cl"
assert_contains "${action_dir}/compile.txt" "/MD"
assert_contains "${action_dir}/compile.txt" ".d"
assert_contains "${action_dir}/compile.txt" ".params"
assert_contains "${action_dir}/compile.txt" "libcxx_headers_include_search_directory"
assert_contains "${action_dir}/compile.txt" "msvc_sdk_case_overlay.yaml"
assert_absent "${action_dir}/compile.txt" "clang++"
assert_absent "${action_dir}/compile.txt" "-fPIC"
assert_absent "${action_dir}/compile.txt" "_LIBCPP_NO_AUTO_LINK"

assert_contains "${action_dir}/archive.txt" "llvm-ar"
assert_contains "${action_dir}/archive.txt" "rcsD"
assert_contains "${action_dir}/archive.txt" "windows_msvc_libcxx_behavior_support.lib"
assert_absent "${action_dir}/archive.txt" "llvm-lib"

assert_contains "${action_dir}/link.txt" "bin/clang-cl"
assert_contains "${action_dir}/link.txt" "bin/lld-link"
assert_contains "${action_dir}/link.txt" "/clang:-fuse-ld=lld"
assert_contains "${action_dir}/link.txt" "LIB=__hermetic_llvm_empty_lib__"
assert_contains "${action_dir}/link.txt" "-resource-dir="
assert_contains "${action_dir}/link.txt" "-rtlib=compiler-rt"
assert_contains "${action_dir}/link.txt" "resource_directory_default"
assert_contains "${action_dir}/link.txt" "libcxx_msvc_library_search_directory"
assert_contains "${action_dir}/link.txt" "/clang:-Xlinker"
assert_contains "${action_dir}/link.txt" "/clang:/MACHINE:X64"
assert_contains "${action_dir}/link.txt" "/clang:/WHOLEARCHIVE:"
assert_contains "${action_dir}/link.txt" "/clang:/OPT:REF"
assert_contains "${action_dir}/link.txt" "/Fe"
assert_absent "${action_dir}/link.txt" "/NODEFAULTLIB"
assert_absent "${action_dir}/link.txt" "libc++.lib"
assert_absent "${action_dir}/link.txt" "clang_rt.builtins.lib"
assert_absent "${action_dir}/link.txt" "msvcrt.lib"
assert_absent "${action_dir}/link.txt" "msvcprt.lib"
assert_absent "${action_dir}/link.txt" "libc++.dll"
assert_absent "${action_dir}/link.txt" "libclang_rt.builtins.a"
assert_absent "${action_dir}/link.txt" "-Wl,"

assert_contains "${action_dir}/def.txt" "DefParser"
assert_contains "${action_dir}/def.txt" "msvc_def_parser"
assert_contains "${action_dir}/def.txt" ".gen.def"
assert_contains "${action_dir}/dll-link.txt" "/clang:/DEF:"
assert_contains "${action_dir}/dll-link.txt" "/clang:/IMPLIB:"
assert_contains "${action_dir}/dll-link.txt" "/clang:/DLL"
assert_contains "${action_dir}/dll-link.txt" ".if.lib"
