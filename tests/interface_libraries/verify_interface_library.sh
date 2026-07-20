#!/usr/bin/env bash

set -euo pipefail

if [[ "$VERSIONED_SYMBOLS" == "yes" ]]; then
  if ! cmp -s "$DYNAMIC_LIBRARY" "$INTERFACE_LIBRARY"; then
    echo "error: interface library for versioned symbols is not a copy of the dynamic library" >&2
    exit 1
  fi
elif cmp -s "$DYNAMIC_LIBRARY" "$INTERFACE_LIBRARY"; then
  echo "error: interface library for unversioned symbols is a copy of the dynamic library" >&2
  exit 1
fi
