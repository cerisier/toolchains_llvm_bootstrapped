load("@bazel_lib//lib:repo_utils.bzl", "repo_utils")
load("//:http_bsdtar_archive.bzl", "http_bsdtar_archive")

_VERSION = "7.9"

_ARCHIVE_URLS = [
    "https://cdn.openbsd.org/pub/OpenBSD/{version}/{archive}",
    "https://cloudflare.cdn.openbsd.org/pub/OpenBSD/{version}/{archive}",
]

_ARCHIVES = {
    "src.tar.gz": "fb305c553059b48e8ee64539f392b783cb38a67865823f6f6a94f3b220a1268b",
    "sys.tar.gz": "c9ef294021ef7aafd5f18ffe8ebfed63394e5a86d65d7436d6db78551f9d57f1",
}

_SYS_HEADER_DIRECTORIES = [
    "crypto",
    "ddb",
    "dev",
    "isofs",
    "miscfs",
    "msdosfs",
    "net",
    "net80211",
    "netinet",
    "netinet6",
    "netmpls",
    "nfs",
    "ntfs",
    "scsi",
    "sys",
    "ufs",
    "uvm",
]

def _urls(archive):
    return [url.format(version = _VERSION, archive = archive) for url in _ARCHIVE_URLS]

_COMPAT_HEADERS = {
    "endian.h": "sys/endian.h",
    "fcntl.h": "sys/fcntl.h",
    "frame.h": "machine/frame.h",
    "stdarg.h": "sys/stdarg.h",
    "stdint.h": "sys/stdint.h",
    "syslog.h": "sys/syslog.h",
    "termios.h": "sys/termios.h",
    "varargs.h": "sys/varargs.h",
}

def _host_bsdtar_label(rctx):
    platform = repo_utils.platform(rctx)
    binary = "tar.exe" if platform.startswith("windows_") else "tar"
    return Label("@bsd_tar_toolchains_{}//:{}".format(platform, binary))

def _extract(rctx, archive, includes, substitution = None, excludes = []):
    args = []
    for include in includes:
        args.extend(["--include", include])
    for exclude in excludes:
        args.extend(["--exclude", exclude])
    if substitution:
        args.extend(["-s", substitution])
    args.extend(["-xf", archive])

    result = rctx.execute([rctx.path(_host_bsdtar_label(rctx))] + args)
    if result.return_code != 0:
        fail("Failed to extract {}:\n{}\n{}".format(archive, result.stderr, result.stdout))

def _openbsd_headers_repository_impl(rctx):
    src_archive = ".downloaded.src.tar.gz"
    sys_archive = ".downloaded.sys.tar.gz"
    rctx.download(_urls("src.tar.gz"), src_archive, sha256 = _ARCHIVES["src.tar.gz"])
    rctx.download(_urls("sys.tar.gz"), sys_archive, sha256 = _ARCHIVES["sys.tar.gz"])

    _extract(
        rctx,
        src_archive,
        ["include", "include/*"],
        excludes = ["*/CVS/*", "include/Makefile"],
    )
    _extract(
        rctx,
        sys_archive,
        ["sys/{directory}/*.h".format(directory = directory) for directory in _SYS_HEADER_DIRECTORIES],
        substitution = "|^sys/|include/|",
    )
    _extract(
        rctx,
        sys_archive,
        ["sys/arch/{}/include/*.h".format(rctx.attr.arch)],
        substitution = "|^sys/arch/{}/include/|include/machine/|".format(rctx.attr.arch),
    )

    for name, target in _COMPAT_HEADERS.items():
        rctx.file("include/" + name, "#include <{}>\n".format(target))

    rctx.delete(src_archive)
    rctx.delete(sys_archive)
    rctx.symlink(rctx.path(rctx.attr.build_file), "BUILD.bazel")
    return rctx.repo_metadata(reproducible = True)

_openbsd_headers_repository = repository_rule(
    implementation = _openbsd_headers_repository_impl,
    attrs = {
        "arch": attr.string(mandatory = True, values = ["amd64", "arm64"]),
        "build_file": attr.label(
            allow_single_file = True,
            default = "//3rd_party/openbsd:headers.BUILD.bazel",
        ),
    },
)

def _openbsd_impl(module_ctx):
    http_bsdtar_archive(
        name = "openbsd_src",
        urls = _urls("src.tar.gz"),
        sha256 = _ARCHIVES["src.tar.gz"],
        includes = [
            "lib/csu",
            "lib/csu/*",
            "lib/libc/Symbols.list",
            "lib/libc/arch/aarch64/Symbols.list",
            "lib/libc/arch/amd64/Symbols.list",
            "lib/libm/Symbols.map",
            "lib/librthread/Symbols.map",
        ],
        build_file = "//3rd_party/openbsd:src.BUILD.bazel",
    )

    _openbsd_headers_repository(
        name = "openbsd_headers_amd64",
        arch = "amd64",
    )
    _openbsd_headers_repository(
        name = "openbsd_headers_arm64",
        arch = "arm64",
    )

    return module_ctx.extension_metadata(
        root_module_direct_deps = [
            "openbsd_headers_amd64",
            "openbsd_headers_arm64",
            "openbsd_src",
        ],
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

openbsd = module_extension(
    implementation = _openbsd_impl,
    doc = "Provides OpenBSD source headers and C runtime metadata.",
)
