#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OUTPUT="runtime error: call to function (unknown) through pointer to incorrect function type 'void (*)(int, char **, char **)'"

OUTPUT="$($BINARY 2>&1)"

# Strip trailing newlines for consistency
trim() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

if [[ "$(trim "$OUTPUT")" == *"$(trim "$EXPECTED_OUTPUT")"* ]]; then
  echo "✅ Asan output contains expected string."
else
  echo "❌ Asan output does not contain expected string."
  echo
  echo "---- Expected ----"
  printf '%s\n' "$EXPECTED_OUTPUT"
  echo "---- Got ----"
  printf '%s\n' "$OUTPUT"
  echo "------------------"
  exit 1
fi
