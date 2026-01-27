#!/usr/bin/env bash
set -euo pipefail

EXPECTED_OUTPUT="ubsan_fail.cc:11:15: runtime error: signed integer overflow: 2147483647 + 1 cannot be represented in type 'int'
SUMMARY: UndefinedBehaviorSanitizer: undefined-behavior ubsan_fail.cc:11:15
ubsan_fail.cc:14:15: runtime error: shift exponent -1 is negative
SUMMARY: UndefinedBehaviorSanitizer: undefined-behavior ubsan_fail.cc:14:15
ubsan_fail.cc:17:17: runtime error: division by zero
SUMMARY: UndefinedBehaviorSanitizer: undefined-behavior ubsan_fail.cc:17:17"

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
    if [[ -z "${MSAN_RUNTIME_PATH:-}" ]]; then
      MSAN_RUNTIME_PATH="$line"
    fi
  done < <(awk '$1 ~ /(libclang_rt\.msan|libmsan)/ {print $2}' "${RUNFILES_MANIFEST_FILE}")
fi

if [[ -n "${RUNFILES_DIR:-}" && -d "${RUNFILES_DIR}" ]]; then
  while IFS= read -r lib; do
    add_runtime_dir "$(dirname "$lib")"
    if [[ -z "${MSAN_RUNTIME_PATH:-}" ]]; then
      MSAN_RUNTIME_PATH="$lib"
    fi
  done < <(find "${RUNFILES_DIR}" -maxdepth 6 -type f \( -name 'libclang_rt.msan*.so*' -o -name 'libmsan.so*' \) 2>/dev/null)
fi

if [[ -n "${LD_LIBRARY_PATH_PREFIX:-}" ]]; then
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH_PREFIX}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  echo "Using LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
fi

PY_BIN="${PYTHON_BIN:-python3}"
if ! command -v "${PY_BIN}" >/dev/null 2>&1 && command -v python >/dev/null 2>&1; then
  PY_BIN=python
fi

if [[ -n "${MSAN_RUNTIME_PATH:-}" && -n "${PY_BIN}" ]]; then
  needed_path="$("${PY_BIN}" - "$BIN" <<'PY' 2>/dev/null
import sys
data = open(sys.argv[1], "rb").read()
for needle in (b"libmsan.so", b"libclang_rt.msan"):
    idx = data.find(needle)
    if idx != -1:
        start = data.rfind(b"\x00", 0, idx) + 1
        s = data[start:idx + len(needle)].decode(errors="ignore")
        if "/" in s:
            print(s)
            sys.exit(0)
PY
)"
  if [[ -n "$needed_path" && "$needed_path" == */* ]]; then
    mkdir -p "$(dirname "$needed_path")"
    ln -sf "${MSAN_RUNTIME_PATH}" "${needed_path}"
    echo "Patched missing runtime path: ${needed_path} -> ${MSAN_RUNTIME_PATH}"
  else
    echo "No MSan runtime path to patch; needed_path=${needed_path:-<none>}"
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
  echo "✅ Msan output contains expected string."
else
  echo "❌ Msan output does not contain expected string."
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
