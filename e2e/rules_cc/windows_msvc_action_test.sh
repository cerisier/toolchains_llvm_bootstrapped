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

assert_matches() {
  local file="$1"
  local pattern="$2"
  grep -Eq -- "${pattern}" "${file}" || fail "${file} does not match: ${pattern}"
}

action_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/windows-msvc-actions.XXXXXX")"
common_flags=(
  "$@"
  --platforms=@llvm//platforms:windows_x86_64_msvc
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1
)
mingw_flags=(
  "$@"
  --platforms=@llvm//platforms:windows_x86_64
)

bazel --bazelrc=.bazelrc aquery "${mingw_flags[@]}" \
  --features=-compiler_param_file \
  --output=commands \
  'inputs(".*libcxx/src/algorithm.cpp", mnemonic("CppCompile", deps(@llvm-project//libcxx:libcxx)))' \
  >"${action_dir}/mingw-libcxx-compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=-compiler_param_file \
  --output=commands \
  'inputs(".*libcxx/src/algorithm.cpp", mnemonic("CppCompile", deps(@llvm-project//libcxx:libcxx.static.msvc)))' \
  >"${action_dir}/msvc-libcxx-compile.txt"

bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("CppCompile", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_generated_def_binary)' \
  >"${action_dir}/default-compile-flags.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  -c opt \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_generated_def_binary)' \
  >"${action_dir}/opt-compile-flags.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  -c dbg \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_generated_def_binary)' \
  >"${action_dir}/dbg-compile-flags.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=-compiler_param_file \
  --features=llvm_release_no_exceptions \
  --features=llvm_release_no_rtti \
  --features=llvm_release_omit_frame_pointer \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_generated_def_binary)' \
  >"${action_dir}/release-compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=-compiler_param_file \
  --features=llvm_release_no_exceptions \
  --features=llvm_release_no_rtti \
  --features=llvm_release_omit_frame_pointer \
  --cxxopt=/EHsc \
  --cxxopt=/GR \
  --cxxopt=/clang:-fno-omit-frame-pointer \
  --cxxopt=/std:c++20 \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_generated_def_binary)' \
  >"${action_dir}/release-user-overrides.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=-compiler_param_file \
  --features=llvm_release_no_exceptions \
  --features=llvm_release_no_rtti \
  --features=llvm_release_omit_frame_pointer \
  --output=commands \
  'inputs(".*libcxxabi/src/private_typeinfo.cpp", mnemonic("CppCompile", deps(@llvm-project//libcxxabi:libcxxabi.static)))' \
  >"${action_dir}/release-libcxxabi-compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("CppArchive", //:windows_msvc_libcxx_behavior_support)' \
  >"${action_dir}/archive.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --output=text \
  'mnemonic("ValidateStaticLibrary", deps(@llvm-project//libcxx:libcxx.static.msvc))' \
  >"${action_dir}/staged-runtime-validation.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --output=text \
  'mnemonic("ValidateStaticLibrary", deps(//:comm_symbol_static_lib))' \
  >"${action_dir}/complete-runtime-validation.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("CppLink", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/link.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --@llvm//toolchain:bootstrap_stage=stage1_from_source \
  --features=-compiler_param_file \
  --output=commands \
  'mnemonic("CppCompile", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/thin-lto-compile.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --@llvm//toolchain:bootstrap_stage=stage1_from_source \
  --include_param_files \
  --output=text \
  'mnemonic("CppLTOIndexing", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/thin-lto-index.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --@llvm//toolchain:bootstrap_stage=stage1_from_source \
  --include_param_files \
  --output=text \
  'mnemonic("CcLtoBackendCompile", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/thin-lto-backend.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --features=thin_lto \
  --@llvm//toolchain:bootstrap_stage=stage1_from_source \
  --include_param_files \
  --output=text \
  'mnemonic("CppLink", //:windows_msvc_libcxx_behavior_md)' \
  >"${action_dir}/thin-lto-link.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("DefParser", deps(//:windows_msvc_generated_def.dll))' \
  >"${action_dir}/def.txt"
bazel --bazelrc=.bazelrc aquery "${common_flags[@]}" \
  --include_param_files \
  --output=text \
  'mnemonic("CppLink", //:windows_msvc_generated_def.dll)' \
  >"${action_dir}/dll-link.txt"
bazel --bazelrc=.bazelrc cquery "${common_flags[@]}" \
  --dynamic_mode=off \
  --output=starlark \
  --starlark:expr='providers(target)' \
  '@llvm-project//clang:config' \
  >"${action_dir}/clang-static-config.txt"
bazel --bazelrc=.bazelrc cquery "${common_flags[@]}" \
  --dynamic_mode=default \
  --output=starlark \
  --starlark:expr='providers(target)' \
  '@llvm-project//clang:config' \
  >"${action_dir}/clang-dynamic-config.txt"
bazel --bazelrc=.bazelrc cquery "${common_flags[@]}" \
  --output=label \
  'kind(".*cc_toolchain.*", deps(//:windows_msvc_crt_default_probe))' \
  >"${action_dir}/resolved-toolchains.txt"

assert_matches "${action_dir}/resolved-toolchains.txt" "@llvm_toolchains//:linux_(aarch64|x86_64)_cc_toolchain"
assert_absent "${action_dir}/resolved-toolchains.txt" "_msvc_cc_toolchain"

assert_contains "${action_dir}/compile.txt" "clang-cl"
assert_contains "${action_dir}/compile.txt" "/MD"
assert_contains "${action_dir}/compile.txt" ".d"
assert_contains "${action_dir}/compile.txt" ".params"
assert_contains "${action_dir}/compile.txt" "libcxx_headers_include_search_directory"
assert_contains "${action_dir}/compile.txt" "msvc_com_support_headers_source"
assert_contains "${action_dir}/compile.txt" "msvc_sdk_case_overlay.yaml"
assert_absent "${action_dir}/compile.txt" "clang++"
assert_absent "${action_dir}/compile.txt" "-fPIC"
assert_absent "${action_dir}/compile.txt" "_LIBCPP_NO_AUTO_LINK"
assert_absent "${action_dir}/compile.txt" "msvc_include"

assert_contains "${action_dir}/mingw-libcxx-compile.txt" "-Wno-pragma-pack"
assert_contains "${action_dir}/mingw-libcxx-compile.txt" "-Wno-unused-value"
assert_contains "${action_dir}/mingw-libcxx-compile.txt" "-Xclang=-Wno-thread-safety-analysis"
assert_absent "${action_dir}/mingw-libcxx-compile.txt" "/clang:-Wno-pragma-pack"
assert_absent "${action_dir}/mingw-libcxx-compile.txt" "/clang:-Wno-unused-value"
assert_contains "${action_dir}/msvc-libcxx-compile.txt" "bin/clang-cl"
assert_matches "${action_dir}/msvc-libcxx-compile.txt" "/clang:-Wthread-safety.*-Xclang=-Wno-thread-safety-analysis"

assert_contains "${action_dir}/default-compile-flags.txt" "/std:c++17"
assert_contains "${action_dir}/default-compile-flags.txt" "/GS"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-Wall"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-Wthread-safety"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-fcolor-diagnostics"
assert_contains "${action_dir}/default-compile-flags.txt" "/clang:-fno-omit-frame-pointer"
assert_absent "${action_dir}/default-compile-flags.txt" "/Z7"
assert_contains "${action_dir}/opt-compile-flags.txt" "/O2"
assert_contains "${action_dir}/opt-compile-flags.txt" "/DNDEBUG"
assert_contains "${action_dir}/opt-compile-flags.txt" "/Gy"
assert_contains "${action_dir}/opt-compile-flags.txt" "/Gw"
assert_contains "${action_dir}/opt-compile-flags.txt" "/Zc:inline"
assert_absent "${action_dir}/opt-compile-flags.txt" "/Z7"
assert_absent "${action_dir}/opt-compile-flags.txt" "/D_DEBUG"
assert_contains "${action_dir}/dbg-compile-flags.txt" "/Od"
assert_contains "${action_dir}/dbg-compile-flags.txt" "/Z7"
assert_absent "${action_dir}/dbg-compile-flags.txt" "/O2"
assert_absent "${action_dir}/dbg-compile-flags.txt" "/DNDEBUG"
assert_absent "${action_dir}/dbg-compile-flags.txt" "/D_DEBUG"
assert_contains "${action_dir}/release-compile.txt" "/std:c++17"
assert_contains "${action_dir}/release-compile.txt" "/EHs-c-"
assert_contains "${action_dir}/release-compile.txt" "/GR-"
assert_contains "${action_dir}/release-compile.txt" "/clang:-fomit-frame-pointer"
assert_absent "${action_dir}/release-compile.txt" " -fno-exceptions"
assert_absent "${action_dir}/release-compile.txt" " -fno-rtti"
assert_absent "${action_dir}/release-compile.txt" " -fomit-frame-pointer"
assert_matches "${action_dir}/release-user-overrides.txt" "/EHs-c-.* /EHsc "
assert_matches "${action_dir}/release-user-overrides.txt" "/GR-.* /GR "
assert_matches "${action_dir}/release-user-overrides.txt" "/clang:-fomit-frame-pointer.* /clang:-fno-omit-frame-pointer "
assert_matches "${action_dir}/release-user-overrides.txt" "/std:c\\+\\+17.* /std:c\\+\\+20"
assert_contains "${action_dir}/release-libcxxabi-compile.txt" "libcxxabi/src/private_typeinfo.cpp"
assert_contains "${action_dir}/release-libcxxabi-compile.txt" "-funwind-tables"
assert_contains "${action_dir}/release-libcxxabi-compile.txt" "/DNDEBUG"
assert_contains "${action_dir}/release-libcxxabi-compile.txt" "/O2"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" "/D_DEBUG"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" " -fno-exceptions"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" " -fno-rtti"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" " -fomit-frame-pointer"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" "/EHs-c-"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" "/GR-"
assert_absent "${action_dir}/release-libcxxabi-compile.txt" "/clang:-fomit-frame-pointer"

assert_contains "${action_dir}/clang-static-config.txt" "CLANG_BUILD_STATIC"
assert_contains "${action_dir}/clang-static-config.txt" "clang/Config/config.h"
assert_absent "${action_dir}/clang-dynamic-config.txt" "CLANG_BUILD_STATIC"
assert_contains "${action_dir}/clang-dynamic-config.txt" "clang/Config/config.h"

assert_contains "${action_dir}/archive.txt" "llvm-ar"
assert_contains "${action_dir}/archive.txt" "rcsD"
assert_contains "${action_dir}/archive.txt" "windows_msvc_libcxx_behavior_support.lib"
assert_absent "${action_dir}/archive.txt" "llvm-lib"
assert_absent "${action_dir}/staged-runtime-validation.txt" "Mnemonic: ValidateStaticLibrary"
assert_contains "${action_dir}/complete-runtime-validation.txt" "Mnemonic: ValidateStaticLibrary"
assert_contains "${action_dir}/complete-runtime-validation.txt" "static-library-validator"

assert_contains "${action_dir}/link.txt" "bin/clang-cl"
assert_contains "${action_dir}/link.txt" "bin/lld-link"
assert_contains "${action_dir}/link.txt" "/clang:-fuse-ld=lld"
assert_contains "${action_dir}/link.txt" "LIB=__hermetic_llvm_empty_lib__"
assert_contains "${action_dir}/link.txt" "-resource-dir="
assert_contains "${action_dir}/link.txt" "-rtlib=compiler-rt"
assert_contains "${action_dir}/link.txt" "resource_directory_default"
assert_contains "${action_dir}/link.txt" "libcxx_msvc_library_search_directory"
assert_contains "${action_dir}/link.txt" "msvc_com_support_libraries"
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
assert_absent "${action_dir}/link.txt" "msvc_lib_arm64"
assert_absent "${action_dir}/link.txt" "msvc_lib_x64"
assert_absent "${action_dir}/link.txt" "-Wl,"

assert_contains "${action_dir}/thin-lto-compile.txt" "bin/clang-cl"
assert_contains "${action_dir}/thin-lto-compile.txt" "--target=x86_64-pc-windows-msvc"
assert_contains "${action_dir}/thin-lto-compile.txt" "/std:c++17"
assert_contains "${action_dir}/thin-lto-compile.txt" "/clang:-flto=thin"
assert_contains "${action_dir}/thin-lto-compile.txt" "/Fo"
assert_contains "${action_dir}/thin-lto-compile.txt" ".obj"
assert_contains "${action_dir}/thin-lto-compile.txt" "/clang:-fthin-link-bitcode="
assert_contains "${action_dir}/thin-lto-compile.txt" ".indexing.o"
assert_absent "${action_dir}/thin-lto-compile.txt" ".indexing.obj"

assert_contains "${action_dir}/thin-lto-index.txt" "CppLTOIndexing"
assert_contains "${action_dir}/thin-lto-index.txt" "llvm.stripped"
assert_matches "${action_dir}/thin-lto-index.txt" "Command Line: \\(exec .*stage1_(linux|macos)_(aarch64|x86_64)/bin/clang-cl"
assert_matches "${action_dir}/thin-lto-index.txt" "stage1_(linux|macos)_(aarch64|x86_64)/bin/lld-link"
assert_absent "${action_dir}/thin-lto-index.txt" "clang-cl-thinlto-index"
assert_absent "${action_dir}/thin-lto-index.txt" "COMPILER_PATH="
assert_absent "${action_dir}/thin-lto-index.txt" "LLVM_CLANG_CL="
assert_absent "${action_dir}/thin-lto-index.txt" "LLVM_LLD_LINK="
assert_absent "${action_dir}/thin-lto-index.txt" "thinlto_index/bin"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/MACHINE:X64"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/thinlto-index-only:"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/thinlto-emit-imports-files"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/thinlto-prefix-replace:"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/thinlto-object-suffix-replace:.indexing.o;.obj"
assert_contains "${action_dir}/thin-lto-index.txt" "/clang:/lto-obj-path:"
assert_contains "${action_dir}/thin-lto-index.txt" ".lto.merged.o"
assert_contains "${action_dir}/thin-lto-index.txt" ".indexing.o"
assert_absent "${action_dir}/thin-lto-index.txt" ".indexing.obj"
assert_absent "${action_dir}/thin-lto-index.txt" "-Wl,"
assert_absent "${action_dir}/thin-lto-index.txt" " -o "
assert_absent "${action_dir}/thin-lto-index.txt" "-x ir"

assert_contains "${action_dir}/thin-lto-backend.txt" "CcLtoBackendCompile"
assert_contains "${action_dir}/thin-lto-backend.txt" "bin/clang-cl"
assert_contains "${action_dir}/thin-lto-backend.txt" "/clang:-fthinlto-index="
assert_contains "${action_dir}/thin-lto-backend.txt" "windows_msvc_libcxx_behavior.obj"
assert_absent "${action_dir}/thin-lto-backend.txt" ".indexing.o"
assert_absent "${action_dir}/thin-lto-backend.txt" "-Wl,"
assert_absent "${action_dir}/thin-lto-backend.txt" " -o "
assert_absent "${action_dir}/thin-lto-backend.txt" "-x ir"

assert_contains "${action_dir}/thin-lto-link.txt" "bin/clang-cl"
assert_contains "${action_dir}/thin-lto-link.txt" "bin/lld-link"
assert_contains "${action_dir}/thin-lto-link.txt" "/clang:/MACHINE:X64"
assert_contains "${action_dir}/thin-lto-link.txt" ".exe-lto-final.params"
assert_contains "${action_dir}/thin-lto-link.txt" ".lto.merged.o"
assert_contains "${action_dir}/thin-lto-link.txt" "/Fe"
assert_matches "${action_dir}/thin-lto-link.txt" "Command Line: \\(exec .*bin/clang-cl"
assert_absent "${action_dir}/thin-lto-link.txt" "-Wl,"
assert_absent "${action_dir}/thin-lto-link.txt" " -o "
assert_absent "${action_dir}/thin-lto-link.txt" "-x ir"

assert_contains "${action_dir}/def.txt" "DefParser"
assert_contains "${action_dir}/def.txt" "msvc_def_parser"
assert_contains "${action_dir}/def.txt" ".gen.def"
assert_contains "${action_dir}/dll-link.txt" "/clang:/DEF:"
assert_contains "${action_dir}/dll-link.txt" "/clang:/IMPLIB:"
assert_contains "${action_dir}/dll-link.txt" "/clang:/DLL"
assert_contains "${action_dir}/dll-link.txt" ".if.lib"
