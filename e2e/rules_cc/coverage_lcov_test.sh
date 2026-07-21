#!/usr/bin/env bash
# Integration test for `bazel coverage` with the hermetic LLVM toolchain.
#
# End to End test for full coverage flow: llvm source-based instrumentation, the
# compiler-rt profile runtime, coverage-tool staging into the test sandbox
# (gcov / llvm-cov / llvm-profdata), and lcov collection via llvm-cov export.
# It must run as a CI step rather than a bazel test target because `bazel
# coverage` cannot be invoked from inside a bazel action.
#
# Extra bazel flags (e.g. --bazelrc, remote cache headers) may be passed as args
# and are forwarded to the coverage invocation.
set -euo pipefail

cd "$(dirname "$0")"

bazel coverage "$@" //:coverage_lib_test

REPORT="$(bazel info output_path)/_coverage/_coverage_report.dat"

echo "==> combined lcov report: ${REPORT}"
if [[ ! -s "${REPORT}" ]]; then
    echo "coverage report is empty or missing: ${REPORT}" >&2
    exit 1
fi

echo "----------------------------------------------------------------------"
cat "${REPORT}"
echo "----------------------------------------------------------------------"

if ! grep -q '^SF:.*coverage_lib\.cc' "${REPORT}"; then
    echo "no source record for coverage_lib.cc in ${REPORT}" >&2
    exit 1
fi

# At least one executed line (covered()) proves instrumentation + collection ran.
if ! grep -qE '^DA:[0-9]+,[1-9]' "${REPORT}"; then
    echo "no covered lines (DA:N,>=1) in ${REPORT}" >&2
    exit 1
fi

# At least one unexecuted line (uncovered()) proves real per-line data, not a
# structurally-empty report.
if ! grep -qE '^DA:[0-9]+,0' "${REPORT}"; then
    echo "no unexecuted lines (DA:N,0) in ${REPORT}" >&2
    exit 1
fi

echo "bazel coverage lcov report OK: ${REPORT}"
