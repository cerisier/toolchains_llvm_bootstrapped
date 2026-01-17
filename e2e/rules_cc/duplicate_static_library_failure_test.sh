#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="${TEST_SRCDIR:?}/${TEST_WORKSPACE:?}"
LOG="${TEST_TMPDIR:?}/duplicate_static_library.log"
BAZEL_BIN="${BAZEL_BIN:-bazel}"

cd "${WORKSPACE_ROOT}"

if "${BAZEL_BIN}" \
    --enable_bzlmod \
    --experimental_cc_static_library \
    --repo_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1 \
    --repo_env=BAZEL_NO_APPLE_CPP_TOOLCHAIN=1 \
    --remote_cache= \
    --remote_executor= \
    --noremote_accept_cached \
    --noremote_upload_local_results \
    --bes_backend= \
    --bes_results_url= \
    build //e2e/rules_cc:duplicate_symbol_lib >"${LOG}" 2>&1; then
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
