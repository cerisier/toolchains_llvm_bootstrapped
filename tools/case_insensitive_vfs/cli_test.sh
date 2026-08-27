#!/usr/bin/env bash

set -euo pipefail

VFS_TOOL="${VFS_TOOLS%% *}"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/case-insensitive-vfs-cli.XXXXXX")"
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

expect_failure 2 "-root requires a value" "${VFS_TOOL}" -root
expect_failure 2 "-output requires a value" "${VFS_TOOL}" -output
expect_failure 2 "unknown argument: -unknown" "${VFS_TOOL}" -unknown
expect_failure 2 "-output is required" "${VFS_TOOL}" -root "${test_tmp}"
expect_failure 1 "at least one -root is required" \
  "${VFS_TOOL}" -output "${test_tmp}/empty.yaml"

mkdir -p "${test_tmp}/root/Nested"
printf 'header\n' >"${test_tmp}/root/Nested/Windows.h"
"${VFS_TOOL}" \
  -root "${test_tmp}/root" \
  -output "${test_tmp}/overlay.yaml"
grep -Fq '"case-sensitive": false' "${test_tmp}/overlay.yaml"
grep -Fq '"use-external-names": false' "${test_tmp}/overlay.yaml"
grep -Fq '"name": "Windows.h"' "${test_tmp}/overlay.yaml"

"${VFS_TOOL}" \
  -root "${test_tmp}/root" \
  -use-external-names \
  -output "${test_tmp}/external-names-overlay.yaml"
grep -Fq '"use-external-names": true' \
  "${test_tmp}/external-names-overlay.yaml"
