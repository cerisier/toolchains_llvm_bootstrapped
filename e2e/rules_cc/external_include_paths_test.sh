#!/usr/bin/env bash

set -euo pipefail

test -x "${1:?error_header_binary path required}"
