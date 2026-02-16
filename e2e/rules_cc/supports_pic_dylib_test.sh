#!/usr/bin/env bash
set -euo pipefail

BIN="$BINARY"
if [[ ! -e "$BIN" && -n "${RUNFILES_DIR:-}" ]]; then
  if [[ -e "${RUNFILES_DIR}/${BIN}" ]]; then
    BIN="${RUNFILES_DIR}/${BIN}"
  elif [[ -e "${RUNFILES_DIR}/_main/${BIN}" ]]; then
    BIN="${RUNFILES_DIR}/_main/${BIN}"
  fi
fi

if [[ ! -e "$BIN" ]]; then
  echo "supports_pic dylib test: binary not found: $BIN"
  exit 1
fi

case "$BIN" in
  *.dylib)
    echo "supports_pic dylib test: detected dylib output: $BIN"
    ;;
  *)
    echo "supports_pic dylib test: expected .dylib output, got: $BIN"
    exit 1
    ;;
esac
