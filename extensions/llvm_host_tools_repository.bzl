"""Repository rule for integrity-pinned LLVM tools used during repository evaluation."""

DEFAULT_LLVM_TOOLCHAIN_MINIMAL_INDEX_FILE = "//extensions:llvm_toolchain_minimal_index.json"

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

def _host_archive_target(rctx):
    host_os = _HOST_OSES.get(rctx.os.name.lower())
    host_arch = _HOST_ARCHES.get(rctx.os.arch.lower())
    if host_os == None or host_arch == None:
        fail("Unsupported LLVM host platform: os='{}', arch='{}'".format(
            rctx.os.name,
            rctx.os.arch,
        ))

    suffix = "-musl" if host_os == "linux" else ""
    return "{}-{}{}".format(host_os, host_arch, suffix)

def _release_key(index, llvm_version, requested_release):
    if requested_release:
        return requested_release

    release = index.get("latest_by_llvm_version", {}).get(llvm_version)
    if release == None:
        fail("No minimal LLVM release is indexed for LLVM {}".format(llvm_version))
    return release

def _llvm_host_tools_repository_impl(rctx):
    index = json.decode(rctx.read(rctx.path(rctx.attr.index)), default = None)
    release = _release_key(index, rctx.attr.llvm_version, rctx.attr.release)
    archive_target = _host_archive_target(rctx)
    release_archives = index.get("releases", {}).get(release)
    if release_archives == None:
        fail("Unknown minimal LLVM release '{}'".format(release))

    archive = release_archives.get(archive_target)
    if archive == None:
        fail("Minimal LLVM release '{}' has no archive for host '{}'".format(
            release,
            archive_target,
        ))

    rctx.download_and_extract(
        url = archive["url"],
        sha256 = archive["sha256"],
    )

    executable_suffix = ".exe" if archive_target.startswith("windows-") else ""
    clang = "bin/clang" + executable_suffix
    ld_lld = "bin/ld.lld" + executable_suffix
    resource_dir = "lib/clang/{}".format(rctx.attr.llvm_version.partition(".")[0])

    for tool in [clang, ld_lld]:
        if not rctx.path(tool).exists:
            fail("Minimal LLVM archive '{}' is missing {}".format(release, tool))
    if not rctx.path(resource_dir).exists:
        fail("Minimal LLVM archive '{}' is missing {}".format(release, resource_dir))

    # Stable root labels let downstream repository rules use repository_ctx.path
    # without reproducing host-specific executable suffix logic.
    rctx.symlink(clang, "clang")
    rctx.symlink(ld_lld, "ld.lld")

    identity = {
        "archive_sha256": archive["sha256"],
        "host_archive_target": archive_target,
        "llvm_version": rctx.attr.llvm_version,
        "paths": {
            "clang": clang,
            "ld_lld": ld_lld,
            "resource_dir": resource_dir,
        },
        "release": release,
    }
    rctx.file("llvm-host-tools.json", json.encode_indent(identity, indent = "  ") + "\n")
    rctx.file("resource-dir.txt", resource_dir + "\n")
    rctx.file(
        "BUILD.bazel",
        """\
package(default_visibility = ["//visibility:public"])

exports_files([
    "clang",
    "ld.lld",
    "llvm-host-tools.json",
    "resource-dir.txt",
])

filegroup(
    name = "resource_dir",
    srcs = glob([{resource_glob}], allow_empty = False),
)

filegroup(
    name = "all_files",
    srcs = glob(["**"], allow_empty = False),
)
""".format(
            resource_glob = repr(resource_dir + "/**"),
        ),
    )

    # The selected archive depends on the repository host. Keeping this
    # explicitly non-reproducible prevents one host's lockfile entry from being
    # incorrectly reused for another host architecture or operating system.
    return rctx.repo_metadata(reproducible = False)

llvm_host_tools_repository = repository_rule(
    implementation = _llvm_host_tools_repository_impl,
    attrs = {
        "index": attr.label(
            allow_single_file = True,
            default = Label(DEFAULT_LLVM_TOOLCHAIN_MINIMAL_INDEX_FILE),
            doc = "Minimal LLVM release index.",
        ),
        "llvm_version": attr.string(
            mandatory = True,
            doc = "LLVM version whose host tools should be downloaded.",
        ),
        "release": attr.string(
            doc = "Exact release key. Defaults to the index's latest release for llvm_version.",
        ),
    },
    doc = "Downloads pinned clang and ld.lld tools for repository-time compiler probes.",
)
