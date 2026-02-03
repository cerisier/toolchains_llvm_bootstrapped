#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(dirname $(realpath "$0"))"
LOG="${TEST_TMPDIR:?}/duplicate_static_library.log"
BAZEL_BIN="${BAZEL_BIN:-bazel}"

cd "${WORKSPACE_ROOT}"

if "${BAZEL_BIN}" \
    --bazelrc=.bazelrc \
    build \
    --color=yes \
    --curses=yes \
    --bes_backend= \
    --config=remote \
    --config=bootstrap \
    //:duplicate_symbol_lib 2>&1 | tee "${LOG}"; then
  echo "Expected duplicate_symbol_lib to fail duplicate symbol validation, but build succeeded."
  exit 1
fi

if grep -q "Duplicate symbols found" "${LOG}"; then
  echo "duplicate_static_library_validator_test: detected duplicate symbols as expected."
  exit 0
fi

echo "Build failed, but duplicate symbol message not found."
exit 1
