#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo >&2 "Usage: MAGIC_FILE=/path/to/magic FILE_BINARY=/path/to/file /path/to/binary file-output"
    exit 1
fi

file="$FILE_BINARY"
magic_file="$MAGIC_FILE"
binary="$1"
want_file_output="$2"

out="$(MAGIC=${magic_file} ${file} -L "${binary}")"

if [[ "${out}" != *"${want_file_output}"* ]]; then
    echo >&2 "Wrong file type: ${out}"
    exit 1
fi
