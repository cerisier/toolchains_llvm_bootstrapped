#!/usr/bin/env bash

set -euo pipefail

DEF_PARSER="${DEF_PARSERS%% *}"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/msvc-def-parser-cli.XXXXXX")"
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

expect_failure "Usage: output_def_file" "${DEF_PARSER}"
expect_failure "Could not open parameter file" \
  "${DEF_PARSER}" "${test_tmp}/missing.def" sample.dll \
  "@${test_tmp}/missing.params"

printf 'EXPORTS\n  Zeta\n' >"${test_tmp}/zeta.def"
printf 'LIBRARY old.dll\nEXPORTS\n  Alpha\n' >"${test_tmp}/alpha.DEF"
printf '  %s  \n' "${test_tmp}/zeta.def" >"${test_tmp}/first.params"
printf '%s\n' "${test_tmp}/alpha.DEF" >"${test_tmp}/second.params"

"${DEF_PARSER}" "${test_tmp}/merged.def" sample.dll \
  "@${test_tmp}/first.params" "@${test_tmp}/second.params"

printf 'LIBRARY sample.dll\nEXPORTS \n\tAlpha\n\tZeta\n' \
  >"${test_tmp}/expected.def"
cmp "${test_tmp}/expected.def" "${test_tmp}/merged.def"
