#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

: "${BUILDBUDDY_API_KEY:?BUILDBUDDY_API_KEY is required}"

BRANCH_NAME="${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD)}"
VERSION="${BRANCH_NAME##*-}"
if [[ ! "${VERSION}" =~ ^[0-9]{8}$ ]]; then
  echo "Branch name must end with YYYYMMDD (got ${VERSION})" >&2
  exit 1
fi

bazel \
  --bazelrc=".github/workflows/ci.bazelrc" \
  build \
  --remote_header="x-buildbuddy-api-key=${BUILDBUDDY_API_KEY}" \
  --config=prebuilt \
  --config=remote \
  --remote_download_outputs=toplevel \
  //prebuilt/extras:for_all_platforms

rm -rf release
mkdir -p release

PLATFORMS=(
  linux_amd64_musl linux-amd64-musl
  linux_arm64_musl linux-arm64-musl
  macos_arm64      darwin-arm64
  windows_amd64    windows-amd64
)

for ((i=0; i<${#PLATFORMS[@]}; i+=2)); do
  platform_dir=${PLATFORMS[i]}
  archive_suffix=${PLATFORMS[i+1]}

  src="bazel-out/${platform_dir}-opt/bin/prebuilt/extras/${platform_dir}.tar.zst"
  dest="release/toolchain-extra-prebuilts-${VERSION}-${archive_suffix}.tar.zst"

  if [[ ! -f "${src}" ]]; then
    echo "Expected archive not found at ${src}" >&2
    exit 1
  fi

  cp "${src}" "${dest}"
done

(cd release && shasum -a 256 *.tar.zst > SHA256.txt)

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "version=${VERSION}" >> "${GITHUB_OUTPUT}"
fi
