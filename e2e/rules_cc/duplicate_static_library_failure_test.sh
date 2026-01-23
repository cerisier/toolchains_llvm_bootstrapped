#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(python3 - <<'PY' "$0"
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
)"
# Prefer the module workspace directory (where this script lives).
WORKSPACE_ROOT="${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${SCRIPT_PATH}")" && pwd -P)}"
LOG="${TEST_TMPDIR:?}/duplicate_static_library.log"
BAZEL_BIN="${BAZEL_BIN:-bazel}"

cd "${WORKSPACE_ROOT}"

if "${BAZEL_BIN}" \
    --bazelrc=.bazelrc \
    build \
    --remote_cache= \
    --bes_backend= \
    --config=bootstrap \
    //:duplicate_symbol_lib 2>&1 | tee "${LOG}"; then
  echo "Expected duplicate_symbol_lib to fail duplicate symbol validation, but build succeeded."
  cat "${LOG}"
  exit 1
fi

if grep -q "Duplicate symbols found" "${LOG}"; then
  echo "duplicate_static_library_validator_test: detected duplicate symbols as expected."
  exit 0
fi

echo "Build failed, but duplicate symbol message not found."
cat "${LOG}"
exit 1
