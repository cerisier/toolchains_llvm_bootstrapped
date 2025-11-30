#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OUTPUT="ubsan_fail.cc:11:15: runtime error: signed integer overflow: 2147483647 + 1 cannot be represented in type 'int'
SUMMARY: UndefinedBehaviorSanitizer: undefined-behavior ubsan_fail.cc:11:15
ubsan_fail.cc:14:15: runtime error: shift exponent -1 is negative
SUMMARY: UndefinedBehaviorSanitizer: undefined-behavior ubsan_fail.cc:14:15
ubsan_fail.cc:17:17: runtime error: division by zero
SUMMARY: UndefinedBehaviorSanitizer: undefined-behavior ubsan_fail.cc:17:17
s=-2147483648 t=-2147483648 u=0"

OUTPUT="$($BINARY 2>&1)"

# Strip trailing newlines for consistency
trim() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

if [[ "$(trim "$OUTPUT")" == *"$(trim "$EXPECTED_OUTPUT")"* ]]; then
  echo "✅ UBSan output contains expected string."
else
  echo "❌ UBSan output does not contain expected string."
  echo
  echo "---- Expected ----"
  printf '%s\n' "$EXPECTED_OUTPUT"
  echo "---- Got ----"
  printf '%s\n' "$OUTPUT"
  echo "------------------"
  exit 1
fi
