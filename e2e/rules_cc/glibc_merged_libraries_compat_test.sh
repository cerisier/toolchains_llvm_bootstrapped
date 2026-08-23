#!/usr/bin/env bash
set -euo pipefail

pthread_stubs="$1"
dl_stubs="$2"

if ! grep -q 'pthread_create@@GLIBC_' "$pthread_stubs"; then
  echo "glibc 2.39 libpthread stubs do not export pthread_create" >&2
  exit 1
fi

if ! grep -q 'dlopen@@GLIBC_' "$dl_stubs"; then
  echo "glibc 2.39 libdl stubs do not export dlopen" >&2
  exit 1
fi
