_FREEBSD_RELEASE = "15.1-RELEASE"
_FREEBSD_SOURCE_SHA256 = "cf5762da53fd52e1eaf0f9ceee9bf58cbe314c821031d0d9ffa76823185a89e1"
_FREEBSD_SOURCE_URL = "https://download.freebsd.org/releases/amd64/amd64/{}/src.txz".format(_FREEBSD_RELEASE)

_HEADER_ALIASES = {
    "_semaphore.h": "sys/sys/_semaphore.h",
    "aio.h": "sys/sys/aio.h",
    "errno.h": "sys/sys/errno.h",
    "fcntl.h": "sys/sys/fcntl.h",
    "float.h": "machine/float.h",
    "floatingpoint.h": "machine/floatingpoint.h",
    "linker_set.h": "sys/sys/linker_set.h",
    "poll.h": "sys/sys/poll.h",
    "stdarg.h": "sys/sys/stdarg.h",
    "stdatomic.h": "sys/sys/stdatomic.h",
    "stdint.h": "sys/sys/stdint.h",
    "syslog.h": "sys/sys/syslog.h",
    "ucontext.h": "sys/sys/ucontext.h",
}

def _freebsd_source_repository_impl(rctx):
    rctx.download_and_extract(
        url = _FREEBSD_SOURCE_URL,
        sha256 = _FREEBSD_SOURCE_SHA256,
        stripPrefix = "usr/src",
        type = "tar.xz",
    )
    rctx.symlink("sys/{}/include".format(rctx.attr.arch), "machine")
    if rctx.attr.arch == "amd64":
        rctx.symlink("sys/x86/include", "x86")
    for alias, target in _HEADER_ALIASES.items():
        rctx.symlink(target, alias)
    rctx.symlink("sys/rpc/rpcb_prot.h", "include/rpc/rpcb_prot.h")
    rctx.symlink("usr.bin/lex/config.h", "contrib/flex/src/config.h")
    rctx.symlink("usr.bin/lex/initparse.c", "contrib/flex/src/parse.c")
    rctx.symlink("usr.bin/lex/initparse.h", "contrib/flex/src/parse.h")
    rctx.symlink("usr.bin/lex/initscan.c", "contrib/flex/src/scan.c")
    rctx.symlink("usr.bin/lex/initskel.c", "contrib/flex/src/skel.c")
    rctx.patch(rctx.path(rctx.attr._flex_linux_patch))
    rctx.symlink(rctx.path(rctx.attr._rpcgen_compat), "rpcgen_compat.h")
    rctx.symlink(rctx.path(rctx.attr._rpc_types), "rpc/types.h")
    rctx.file(
        "osreldate.h",
        """/* Generated from FreeBSD 15.1-RELEASE sys/sys/param.h. */
#ifdef _KERNEL
#error \"<osreldate.h> cannot be used in the kernel, use <sys/param.h>\"
#else
#undef __FreeBSD_version
#define __FreeBSD_version 1501000
#endif
""",
    )
    freebsd_arch = "aarch64" if rctx.attr.arch == "arm64" else "amd64"
    target_triple = "aarch64-unknown-freebsd15.1" if rctx.attr.arch == "arm64" else "x86_64-unknown-freebsd15.1"
    rctx.file(
        "freebsd_arch.bzl",
        "FREEBSD_ARCH = \"{}\"\nFREEBSD_MACHINE_ARCH = \"{}\"\nFREEBSD_TARGET_TRIPLE = \"{}\"\n".format(
            freebsd_arch,
            rctx.attr.arch,
            target_triple,
        ),
    )
    rctx.symlink(rctx.path(rctx.attr.build_file), "BUILD.bazel")

_freebsd_source_repository = repository_rule(
    implementation = _freebsd_source_repository_impl,
    attrs = {
        "arch": attr.string(mandatory = True),
        "build_file": attr.label(
            allow_single_file = True,
            default = "//3rd_party/freebsd:freebsd.BUILD.bazel",
        ),
        "_rpc_types": attr.label(
            allow_single_file = True,
            default = "//3rd_party/freebsd:rpc/types.h",
        ),
        "_flex_linux_patch": attr.label(
            allow_single_file = True,
            default = "//3rd_party/freebsd:flex-linux.patch",
        ),
        "_rpcgen_compat": attr.label(
            allow_single_file = True,
            default = "//3rd_party/freebsd:rpcgen_compat.h",
        ),
    },
)

def _freebsd_impl(module_ctx):
    _freebsd_source_repository(
        name = "freebsd_src_aarch64",
        arch = "arm64",
    )
    _freebsd_source_repository(
        name = "freebsd_src_x86_64",
        arch = "amd64",
    )

    return module_ctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = [
            "freebsd_src_aarch64",
            "freebsd_src_x86_64",
        ],
        root_module_direct_dev_deps = [],
    )

freebsd = module_extension(
    implementation = _freebsd_impl,
    doc = "Downloads the FreeBSD source tree used to build the FreeBSD runtime.",
)
