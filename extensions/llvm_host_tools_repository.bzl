"""Repository rule for integrity-pinned LLVM tools used during repository evaluation."""

load(
    ":llvm_host_tools_paths.bzl",
    "llvm_host_tools_archive_target",
    "llvm_host_tools_layout",
)

DEFAULT_LLVM_TOOLCHAIN_MINIMAL_INDEX_FILE = "//extensions:llvm_toolchain_minimal_index.json"

def _host_archive_target(rctx):
    return llvm_host_tools_archive_target(rctx.os.name, rctx.os.arch)

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

    layout = llvm_host_tools_layout(archive_target)
    clang = layout.archive_paths["clang"]
    ld_lld = layout.archive_paths["ld_lld"]
    resource_dir = "lib/clang/{}".format(rctx.attr.llvm_version.partition(".")[0])

    for tool in [clang, ld_lld]:
        if not rctx.path(tool).exists:
            fail("Minimal LLVM archive '{}' is missing {}".format(release, tool))
    if not rctx.path(resource_dir).exists:
        fail("Minimal LLVM archive '{}' is missing {}".format(release, resource_dir))

    # Keep the original root labels for compatibility, and expose suffix-bearing
    # paths for repository rules that pass absolute tool paths to native process
    # launchers. The latter must end in .exe on Windows; making them available on
    # every host gives consumers one portable pair of labels.
    for root_path in sorted(layout.root_symlinks):
        rctx.symlink(layout.root_symlinks[root_path], root_path)

    identity = {
        "archive_sha256": archive["sha256"],
        "host_archive_target": archive_target,
        "llvm_version": rctx.attr.llvm_version,
        "paths": {
            "clang": clang,
            "ld_lld": ld_lld,
            "resource_dir": resource_dir,
        },
        "probe_paths": layout.probe_paths,
        "release": release,
    }
    rctx.file("llvm-host-tools.json", json.encode_indent(identity, indent = "  ") + "\n")
    rctx.file(
        "host-platform.txt",
        "{}/{}\n".format(rctx.os.name, rctx.os.arch),
        executable = False,
    )
    rctx.file("resource-dir.txt", resource_dir + "\n")
    rctx.file(
        "BUILD.bazel",
        """\
package(default_visibility = ["//visibility:public"])

exports_files({root_files} + [
    "host-platform.txt",
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
            root_files = repr(sorted(layout.root_symlinks.keys())),
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
