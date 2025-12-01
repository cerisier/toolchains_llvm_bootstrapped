#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

# set -uo pipefail

if [[ $# -ne 2 ]]; then
    echo >&2 "Usage: MAGIC_FILE=/path/to/magic FILE_BINARY=/path/to/file /path/to/binary file-output"
    exit 1
fi

file="$(rlocation $FILE_BINARY)"
magic_file="$(rlocation $MAGIC_FILE)"
binary="$1"
want_file_output="$2"

out="$(MAGIC=${magic_file} ${file} -L "${binary}")"

if [[ "${out}" != *"${want_file_output}"* ]]; then
    echo >&2 "Wrong file type: ${out}"
    exit 1
fi
