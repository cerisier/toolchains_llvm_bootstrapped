#!/usr/bin/env python3
"""Register one unpublished LLVM archive in a Bazel test module."""

import argparse
import hashlib
import json
import re
from pathlib import Path


_REPOSITORIES = [
    "llvm-toolchain-minimal-darwin-amd64",
    "llvm-toolchain-minimal-darwin-arm64",
    "llvm-toolchain-minimal-linux-amd64",
    "llvm-toolchain-minimal-linux-arm64",
    "llvm-toolchain-minimal-windows-amd64",
    "llvm-toolchain-minimal-windows-arm64",
]


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--index", required=True, type=Path)
    parser.add_argument("--llvm-version-module", required=True, type=Path)
    parser.add_argument("--module", required=True, type=Path)
    parser.add_argument("--output-index", required=True, type=Path)
    parser.add_argument(
        "--target",
        choices=["windows-amd64", "windows-arm64"],
        required=True,
    )
    return parser.parse_args()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _llvm_version(module: Path) -> str:
    matches = re.findall(
        r'^LLVM_VERSION\s*=\s*"([^"]+)"\s*$',
        module.read_text(),
        re.MULTILINE,
    )
    if len(matches) != 1:
        raise ValueError(f"expected exactly one LLVM_VERSION assignment in {module}")
    return matches[0]


def main() -> None:
    args = _parse_args()
    archive = args.archive.resolve()
    index = json.loads(args.index.read_text())
    llvm_version = _llvm_version(args.llvm_version_module)
    release_key = index["latest_by_llvm_version"][llvm_version]
    archive_sha256 = _sha256(archive)
    index["releases"][release_key][args.target] = {
        "sha256": archive_sha256,
        "url": archive.as_uri(),
    }
    args.output_index.write_text(json.dumps(index, indent=2) + "\n")

    repository_args = ",\n".join(
        f'    "{repository}"' for repository in _REPOSITORIES
    )
    with args.module.open("a") as module:
        module.write(
            f'''\n# CI-only registration of the unpublished archive selected by this index.
local_llvm_toolchain_minimal = use_extension(
    "@llvm//extensions:llvm_toolchain_minimal.bzl",
    "llvm_toolchain_minimal",
)
local_llvm_toolchain_minimal.index(file = "//:{args.output_index.name}")
use_repo(
    local_llvm_toolchain_minimal,
{repository_args},
)
'''
        )

    print(f"archive={archive}")
    print(f"sha256={archive_sha256}")
    print(f"release={release_key}")
    print(f"target={args.target}")


if __name__ == "__main__":
    main()
