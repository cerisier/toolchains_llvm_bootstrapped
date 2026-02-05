
load("@tar.bzl", "tar", "mtree_spec", "mtree_mutate")
load("@llvm-project//:vars.bzl", "LLVM_VERSION_MAJOR")
load("//prebuilt:mtree.bzl", "mtree")
#load("//tools:defs.bzl", "TOOLCHAIN_BINARIES")

# TODO(zbarsky): Remove thise after we release
TOOLCHAIN_BINARIES = [
    "c++filt",
    "clang",
    "clang++",
    "clang-cl",
    "clang-cpp",
    "clang-scan-deps",
    "dsymutil",
    "lld",
    "ld.lld",
    "ld64.lld",
    "lld-link",
    "wasm-ld",
    "llvm-ar",
    "llvm-cgdata",
    "llvm-cxxfilt",
    "llvm-debuginfod-find",
    "llvm-dwp",
    "llvm-dlltool",
    "llvm-gsymutil",
    "llvm-ifs",
    "llvm-libtool-darwin",
    "llvm-lipo",
    "llvm-ml",
    "llvm-mt",
    "llvm-nm",
    "llvm-ranlib",
    "llvm-objcopy",
    "llvm-install-name-tool",
    "llvm-bitcode-strip",
    "llvm-objdump",
    "llvm-rc",
    "windres",
    "llvm-readobj",
    "readelf",
    "llvm-size",
    "llvm-strip",
    "llvm-symbolizer",
    "addr2line",
    # "clang-tidy",
    # "clang-format",
    # "clangd",
    # "llvm-profdata",
    # "llvm-cov",
    "otool",
    "sancov",
]

def llvm_release(name, bin_suffix = ""):
    mtree_spec(
        name = name + "_builtin_headers_mtree_",
        srcs = [
            "@llvm-project//clang:builtin_headers_files",
        ],
        tags = ["manual"],
    )

    mtree_mutate(
        name = name + "_builtin_headers_mtree",
        mtree = name + "_builtin_headers_mtree_",
        strip_prefix = "clang/lib/Headers",
        package_dir = "lib/clang/{}/include".format(LLVM_VERSION_MAJOR),
        tags = ["manual"],
    )

    bin_files = {
        "@llvm-project//llvm:llvm.stripped": "bin/llvm" + bin_suffix,
        "@llvm-project//compiler-rt:asan_ignorelist": "lib/clang/{llvm_major}/share/asan_ignorelist.txt",
        "@llvm-project//compiler-rt:msan_ignorelist": "lib/clang/{llvm_major}/share/msan_ignorelist.txt",
    }

    mtree(
        name = name + "_bins_mtree",
        files = bin_files,
        symlinks = {
            "bin/" + binary + bin_suffix: "llvm" + bin_suffix
            for binary in ["clang-{llvm_major}"] + TOOLCHAIN_BINARIES
        } | {
            # TODO(zbarsky): Consider adding these once LLVM multicall supports them.
            "bin/" + binary + bin_suffix: "empty"
            for binary in [
                "clang-tidy",
                "clang-format",
                "clangd",
            ]
        },
        format = {
            "llvm_major": LLVM_VERSION_MAJOR,
        },
        tags = ["manual"],
    )

    native.genrule(
        name = name + "_mtree",
        srcs = [
            name + "_bins_mtree",
            name + "_builtin_headers_mtree",
        ],
        cmd = """\
            cat $(SRCS) > $(@)
        """,
        outs = [
            name + "_mtree_spec.mtree",
        ],
        tags = ["manual"],
    )

    tar(
        name = name,
        srcs = bin_files.keys() + [
            "@llvm-project//clang:builtin_headers_files",
        ],
        args = [
            "--options",
            "zstd:compression-level=22",
        ],
        compress = "zstd",
        mtree = name + "_mtree",
        tags = ["manual"],
    )
