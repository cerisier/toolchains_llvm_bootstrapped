#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OUTPUT="ERROR: AddressSanitizer: heap-use-after-free on address"

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "Skipping ASan runtime check on Darwin; runtime is only provided for Linux."
  exit 0
fi

BIN="$BINARY"
if [[ ! -x "$BIN" && -n "${RUNFILES_DIR:-}" ]]; then
  if [[ -x "${RUNFILES_DIR}/${BIN}" ]]; then
    BIN="${RUNFILES_DIR}/${BIN}"
  elif [[ -x "${RUNFILES_DIR}/_main/${BIN}" ]]; then
    BIN="${RUNFILES_DIR}/_main/${BIN}"
  fi
fi

echo "Using binary: ${BIN}"
ls -l "${BIN}" 2>/dev/null || true

add_runtime_dir() {
  local dir="$1"
  [[ -z "$dir" ]] && return
  case ":${LD_LIBRARY_PATH_PREFIX:-}:" in
    *":$dir:"*) ;;
    *) LD_LIBRARY_PATH_PREFIX="${LD_LIBRARY_PATH_PREFIX:+${LD_LIBRARY_PATH_PREFIX}:}${dir}" ;;
  esac
}

if [[ -n "${RUNFILES_MANIFEST_FILE:-}" && -f "${RUNFILES_MANIFEST_FILE}" ]]; then
  while IFS= read -r line; do
    add_runtime_dir "$(dirname "$line")"
    if [[ -z "${ASAN_RUNTIME_PATH:-}" ]]; then
      ASAN_RUNTIME_PATH="$line"
    fi
  done < <(awk '$1 ~ /(libclang_rt\.asan|libasan\.shared)/ {print $2}' "${RUNFILES_MANIFEST_FILE}")
fi

if [[ -n "${RUNFILES_DIR:-}" && -d "${RUNFILES_DIR}" ]]; then
  while IFS= read -r lib; do
    add_runtime_dir "$(dirname "$lib")"
    if [[ -z "${ASAN_RUNTIME_PATH:-}" ]]; then
      ASAN_RUNTIME_PATH="$lib"
    fi
  done < <(find "${RUNFILES_DIR}" -maxdepth 6 -type f \( -name 'libclang_rt.asan*.so*' -o -name 'libasan.so*' -o -name 'libasan.shared.so*' \) 2>/dev/null)
fi

if [[ -n "${LD_LIBRARY_PATH_PREFIX:-}" ]]; then
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH_PREFIX}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  echo "Using LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
else
  echo "ASan runtime library not found in runfiles; execution may fail."
fi

PY_BIN="${PYTHON_BIN:-python3}"
if ! command -v "${PY_BIN}" >/dev/null 2>&1 && command -v python >/dev/null 2>&1; then
  PY_BIN=python
fi

if [[ -n "${ASAN_RUNTIME_PATH:-}" && -n "${PY_BIN}" ]]; then
  needed_path="$("${PY_BIN}" - "$BIN" <<'PY' 2>/dev/null
import sys
data = open(sys.argv[1], "rb").read()
needle = b"libasan.shared.so"
idx = data.find(needle)
if idx != -1:
    start = data.rfind(b"\x00", 0, idx) + 1
    s = data[start:idx + len(needle)].decode(errors="ignore")
    if "/" in s:
        print(s)
PY
)"
  if [[ -n "$needed_path" && "$needed_path" == */* ]]; then
    mkdir -p "$(dirname "$needed_path")"
    ln -sf "${ASAN_RUNTIME_PATH}" "${needed_path}"
    echo "Patched missing runtime path: ${needed_path} -> ${ASAN_RUNTIME_PATH}"
  else
    echo "No ASan runtime path to patch; needed_path=${needed_path:-<none>}"
  fi
fi

set +e
OUTPUT="$($BIN 2>&1)"
STATUS=$?
set -e

# Strip trailing newlines for consistency
trim() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

if [[ "$(trim "$OUTPUT")" == *"$(trim "$EXPECTED_OUTPUT")"* ]]; then
  echo "✅ Asan output contains expected string."
else
  echo "❌ Asan output does not contain expected string."
  echo
  echo "---- Expected ----"
  printf '%s\n' "$EXPECTED_OUTPUT"
  echo "---- Got ----"
  printf '%s\n' "$OUTPUT"
  echo "------------------"
  if [[ ${STATUS:-1} -ne 0 ]]; then
    exit "$STATUS"
  fi
  exit 1
fi
