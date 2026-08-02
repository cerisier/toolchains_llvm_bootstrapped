#!/usr/bin/env bash

set -euo pipefail

readonly tests_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

bash "${tests_dir}/freestanding/check_ppc64le_toolchain.sh" "$@"
bash "${tests_dir}/libc_defaults/check_unconstrained_libc_selection.sh" "$@"
