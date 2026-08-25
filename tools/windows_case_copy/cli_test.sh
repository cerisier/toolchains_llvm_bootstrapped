#!/usr/bin/env bash

set -euo pipefail

COPY_TOOL="${COPY_TOOLS%% *}"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/windows-case-copy-cli.XXXXXX")"
trap 'rm -rf "${test_tmp}"' EXIT

expect_failure() {
  local expected_status="$1"
  local expected_message="$2"
  shift 2
  set +e
  "$@" >"${test_tmp}/stdout" 2>"${test_tmp}/stderr"
  local status="$?"
  set -e
  if [[ "${status}" -ne "${expected_status}" ]]; then
    echo "expected status ${expected_status}, got ${status}: $*" >&2
    return 1
  fi
  grep -Fq -- "${expected_message}" "${test_tmp}/stderr"
}

expect_failure 2 "-source requires a value" "${COPY_TOOL}" -source
expect_failure 2 "-output requires a value" "${COPY_TOOL}" -output
expect_failure 2 "unknown argument: -unknown" "${COPY_TOOL}" -unknown
expect_failure 2 "-source and -output are required" \
  "${COPY_TOOL}" -source "${test_tmp}"

mkdir -p "${test_tmp}/source/Nested"
printf 'library\n' >"${test_tmp}/source/Nested/Kernel32.Lib"
"${COPY_TOOL}" \
  -source "${test_tmp}/source" \
  -output "${test_tmp}/output"
cmp "${test_tmp}/source/Nested/Kernel32.Lib" \
  "${test_tmp}/output/Nested/kernel32.lib"
