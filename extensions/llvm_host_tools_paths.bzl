"""Host-specific archive paths and stable repository paths for LLVM probe tools."""

def llvm_host_tools_layout(archive_target):
    """Returns the archive and generated repository paths for host LLVM tools.

    The compatibility paths keep the original public labels stable. The probe
    paths deliberately retain a `.exe` suffix on every host: Unix can execute
    those symlinks directly, while Windows process launchers require the suffix
    when they receive an absolute path.
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
