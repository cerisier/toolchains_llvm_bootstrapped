#!/usr/bin/env bash

set -euo pipefail

DEF_FILE_GENERATOR="${DEF_FILE_GENERATORS%% *}"
BIGOBJ_FIXTURE_WRITER="${BIGOBJ_FIXTURE_WRITERS%% *}"
CLANG_CL="${CLANG_CLS%% *}"
export LLVM_NM="${LLVM_NMS%% *}"

test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/def-file-generator.XXXXXX")"
trap 'rm -rf "${test_tmp}"' EXIT

expect_failure() {
  local expected_message="$1"
  shift
  set +e
  "$@" >"${test_tmp}/stdout" 2>"${test_tmp}/stderr"
  local status="$?"
  set -e
  if [[ "${status}" -eq 0 ]]; then
    echo "expected failure: $*" >&2
    return 1
  fi
  grep -Fq -- "${expected_message}" "${test_tmp}/stderr"
}

expect_failure "Usage: output_def_file" "${DEF_FILE_GENERATOR}"
expect_failure "Could not open parameter file" \
  "${DEF_FILE_GENERATOR}" "${test_tmp}/missing.def" sample.dll \
  "@${test_tmp}/missing.params"

printf "'unterminated\n" >"${test_tmp}/malformed.params"
expect_failure "unterminated shell parameter quote" \
  "${DEF_FILE_GENERATOR}" "${test_tmp}/malformed.def" sample.dll \
  "@${test_tmp}/malformed.params"

mkdir "${test_tmp}/quoted inputs"
cat >"${test_tmp}/quoted inputs/symbols.c" <<'EOF'
int mutable_data = 1;
const int readonly_data = 2;
int exported_function(void) { return mutable_data + readonly_data; }
EOF

"${CLANG_CL}" /nologo /clang:--target=x86_64-pc-windows-msvc /c \
  "/Fo${test_tmp}/quoted inputs/symbols.obj" \
  "${test_tmp}/quoted inputs/symbols.c"
"${CLANG_CL}" /nologo /clang:--target=x86_64-pc-windows-msvc \
  /clang:-flto=thin /c \
  "/Fo${test_tmp}/quoted inputs/symbols.thinlto.obj" \
  "${test_tmp}/quoted inputs/symbols.c"
"${BIGOBJ_FIXTURE_WRITER}" "${test_tmp}/quoted inputs/symbols-big.s"
"${CLANG_CL}" /nologo /clang:--target=x86_64-pc-windows-msvc /c \
  "/Fo${test_tmp}/quoted inputs/symbols-big.obj" \
  "${test_tmp}/quoted inputs/symbols-big.s"

printf 'LIBRARY old.dll\nEXPORTS\n  ExistingData \t DATA\n  Existing\n' \
  >"${test_tmp}/quoted inputs/existing.DEF"
{
  printf '"%s"\n' "${test_tmp}/quoted inputs/symbols.obj"
  printf '"%s"\n' "${test_tmp}/quoted inputs/symbols.thinlto.obj"
  printf '"%s"\n' "${test_tmp}/quoted inputs/symbols-big.obj"
  printf '"%s"\n' "${test_tmp}/quoted inputs/existing.DEF"
} >"${test_tmp}/inputs.params"

"${DEF_FILE_GENERATOR}" "${test_tmp}/merged.def" sample.dll \
  "@${test_tmp}/inputs.params"

cat >"${test_tmp}/expected.def" <<'EOF'
LIBRARY sample.dll
EXPORTS 
	ExistingData 	 DATA
	mutable_data 	 DATA
	readonly_data 	 DATA
	Existing
	bigobj_function
	exported_function
EOF
diff -u "${test_tmp}/expected.def" "${test_tmp}/merged.def"

printf 'not an object\n' >"${test_tmp}/malformed.obj"
expect_failure "llvm-nm exited with status" \
  "${DEF_FILE_GENERATOR}" "${test_tmp}/rejected.def" sample.dll \
  "${test_tmp}/malformed.obj"
