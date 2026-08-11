#!/usr/bin/env python3

import argparse
import lzma
import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time


_EXPECTED_OUTPUTS = [
    "Hello, World corentin!",
    "Result from C library: 42",
]
_PASS_MARKER = "HERMETIC_LLVM_FREEBSD_PASS"


def _parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--c-binary", type=Path, required=True)
    parser.add_argument("--cxx-binary", type=Path, required=True)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--sysroot", type=Path, required=True)
    return parser.parse_args()


def _find_qemu():
    configured = os.environ.get("QEMU_SYSTEM_AARCH64")
    if configured:
        return Path(configured)
    found = shutil.which("qemu-system-aarch64")
    if found:
        return Path(found)
    candidates = [
        Path("/opt/homebrew/bin/qemu-system-aarch64"),
        Path("/usr/local/bin/qemu-system-aarch64"),
        Path("/usr/bin/qemu-system-aarch64"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise RuntimeError(
        "Set QEMU_SYSTEM_AARCH64 to the qemu-system-aarch64 executable"
    )


def _find_firmware(qemu):
    configured = os.environ.get("QEMU_EFI_AARCH64")
    if configured:
        return Path(configured)
    candidates = [
        qemu.resolve().parents[1] / "share/qemu/edk2-aarch64-code.fd",
        Path("/opt/homebrew/share/qemu/edk2-aarch64-code.fd"),
        Path("/usr/local/share/qemu/edk2-aarch64-code.fd"),
        Path("/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise RuntimeError("Set QEMU_EFI_AARCH64 to an AArch64 EDK2 firmware image")


def _decompress_sparse(source, destination):
    zero = bytes(1024 * 1024)
    with lzma.open(source, "rb") as compressed, destination.open("wb") as output:
        while True:
            block = compressed.read(len(zero))
            if not block:
                break
            if block == zero[: len(block)]:
                output.seek(len(block), os.SEEK_CUR)
            else:
                output.write(block)
        output.truncate()


def _create_payload(sysroot, c_binary, cxx_binary, destination):
    with tarfile.open(destination, "w", dereference=False) as archive:
        for child in sorted(sysroot.iterdir()):
            archive.add(child, arcname=child.name, recursive=True)
        archive.add(c_binary.resolve(strict=True), arcname="hello", recursive=False)
        archive.add(cxx_binary.resolve(strict=True), arcname="main", recursive=False)


def _wait_for(process, expected, transcript, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        ready, _, _ = select.select([process.stdout], [], [], 1)
        if not ready:
            if process.poll() is not None:
                raise RuntimeError(
                    f"QEMU exited with {process.returncode} before {expected!r}\n{transcript.decode(errors='replace')}"
                )
            continue
        block = os.read(process.stdout.fileno(), 65536)
        if not block:
            continue
        transcript.extend(block)
        sys.stdout.buffer.write(block)
        sys.stdout.buffer.flush()
        if expected.encode() in transcript:
            return
    raise TimeoutError(
        f"Timed out waiting for {expected!r}\n{transcript.decode(errors='replace')}"
    )


def _write(process, command):
    process.stdin.write((command + "\n").encode())
    process.stdin.flush()


def _run_to_prompt(process, command, transcript, timeout):
    transcript.clear()
    _write(process, command)
    _wait_for(process, "# ", transcript, timeout)


def main():
    args = _parse_args()
    qemu = _find_qemu()
    firmware = _find_firmware(qemu)

    with tempfile.TemporaryDirectory(prefix="freebsd-qemu-") as temporary:
        temporary = Path(temporary)
        image = temporary / "freebsd.raw"
        payload = temporary / "source-runtime.tar"
        _decompress_sparse(args.image, image)
        _create_payload(args.sysroot, args.c_binary, args.cxx_binary, payload)

        command = [
            str(qemu),
            "-machine",
            "virt,accel=hvf",
            "-cpu",
            "host",
            "-m",
            "2048",
            "-smp",
            "2",
            "-nographic",
            "-monitor",
            "none",
            "-snapshot",
            "-bios",
            str(firmware),
            "-drive",
            f"if=none,file={image},format=raw,id=root",
            "-device",
            "virtio-blk-pci,drive=root",
            "-drive",
            f"if=none,file={payload},format=raw,readonly=on,id=payload",
            "-device",
            "virtio-blk-pci,drive=payload",
        ]
        process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        transcript = bytearray()
        try:
            _wait_for(process, "login:", transcript, 240)
            _write(process, "root")
            _wait_for(process, "# ", transcript, 60)
            _run_to_prompt(process, "stty -echo", transcript, 30)
            _run_to_prompt(
                process,
                "mkdir -p /tmp/source-runtime",
                transcript,
                30,
            )
            _run_to_prompt(
                process,
                "tar -xf /dev/vtbd1 -C /tmp/source-runtime",
                transcript,
                120,
            )
            transcript.clear()
            _write(
                process,
                "chroot /tmp/source-runtime /hello && "
                "chroot /tmp/source-runtime /main && "
                "echo HERMETIC_LLVM_FREEBSD_PASS || "
                "echo HERMETIC_LLVM_FREEBSD_FAIL",
            )
            _wait_for(process, "# ", transcript, 120)
            output = transcript.decode(errors="replace")
            if _PASS_MARKER not in output:
                raise RuntimeError(f"Missing {_PASS_MARKER!r}\n{output}")
            for expected_output in _EXPECTED_OUTPUTS:
                if expected_output not in output:
                    raise RuntimeError(f"Missing {expected_output!r}\n{output}")
        finally:
            if process.poll() is None:
                _write(process, "poweroff -p")
                try:
                    process.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    main()
