#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo >&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

set -euo pipefail

WORKSPACE_ROOT="$(dirname "$(realpath "$0")")"
LOG="${TEST_TMPDIR:?}/duplicate_static_library.log"
if [[ "$#" -ne 1 ]]; then
  echo "Usage: $0 BAZELISK_RLOCATION_PATH"
  exit 1
fi
BAZEL_BIN="$(rlocation "$1")"
if [[ ! -x "${BAZEL_BIN}" ]]; then
  echo "Bazel launcher is missing or not executable: ${BAZEL_BIN}"
  exit 1
fi

cd "${WORKSPACE_ROOT}"
# Bazelisk fails early if neither HOME nor XDG_CACHE_HOME are exported.
USER_HOME="${HOME:-}"
export HOME="${TEST_TMPDIR}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${TEST_TMPDIR}/.cache}"

BAZELRC_FLAGS=(--bazelrc=.bazelrc)
if [[ -n "${USER_HOME}" && -f "${USER_HOME}/.bazelrc" ]]; then
  BAZELRC_FLAGS=(--bazelrc="${USER_HOME}/.bazelrc" "${BAZELRC_FLAGS[@]}")
fi

if "${BAZEL_BIN}" \
    "${BAZELRC_FLAGS[@]}" \
    build \
    --color=yes \
    --curses=yes \
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
