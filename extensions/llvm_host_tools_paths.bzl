"""Host-specific archive paths and stable repository paths for LLVM probe tools."""

_HOST_ARCHES = {
    "aarch64": "arm64",
    "amd64": "amd64",
    "arm64": "arm64",
    "x86_64": "amd64",
}

_HOST_OSES = {
    "linux": "linux",
    "mac os x": "darwin",
    "macos": "darwin",
    "windows": "windows",
}

def llvm_host_tools_archive_target(os_name, arch):
    """Returns the minimal LLVM archive target for a repository host.

    Args:
        os_name: Host operating-system name reported by Bazel.
        arch: Host architecture name reported by Bazel.

    Returns:
        The matching minimal LLVM release archive target.
    """
    normalized_os = os_name.lower()
    if normalized_os.startswith("windows"):
        normalized_os = "windows"

    host_os = _HOST_OSES.get(normalized_os)
    host_arch = _HOST_ARCHES.get(arch.lower())
    if host_os == None or host_arch == None:
        fail("Unsupported LLVM host platform: os='{}', arch='{}'".format(
            os_name,
            arch,
        ))

    suffix = "-musl" if host_os == "linux" else ""
    return "{}-{}{}".format(host_os, host_arch, suffix)

def llvm_host_tools_layout(archive_target):
    """Returns the archive and generated repository paths for host LLVM tools.

    The compatibility paths keep the original public labels stable. The probe
    paths deliberately retain a `.exe` suffix on every host: Unix can execute
    those symlinks directly, while Windows process launchers require the suffix
    when they receive an absolute path.

    Args:
        archive_target: The release archive target identifier.

    Returns:
        A struct containing archive, compatibility, probe, and symlink paths.
    """
    archive_suffix = ".exe" if archive_target.startswith("windows-") else ""
    archive_paths = {
        "clang": "bin/clang" + archive_suffix,
        "ld_lld": "bin/ld.lld" + archive_suffix,
    }
    compatibility_paths = {
        "clang": "clang",
        "ld_lld": "ld.lld",
    }
    probe_paths = {
        "clang": "clang.exe",
        "ld_lld": "ld.lld.exe",
    }
    return struct(
        archive_paths = archive_paths,
        compatibility_paths = compatibility_paths,
        probe_paths = probe_paths,
        root_symlinks = {
            compatibility_paths["clang"]: archive_paths["clang"],
            compatibility_paths["ld_lld"]: archive_paths["ld_lld"],
            probe_paths["clang"]: archive_paths["clang"],
            probe_paths["ld_lld"]: archive_paths["ld_lld"],
        },
    )
