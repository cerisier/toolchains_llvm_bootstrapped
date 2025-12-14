
load("@tar.bzl", "tar", "mtree_spec", "mtree_mutate")
load("@llvm-project//:vars.bzl", "LLVM_VERSION_MAJOR")
load("//prebuilt:mtree.bzl", "mtree")

def llvm_release(name):
    mtree_spec(
        name = "builtin_headers_mtree_",
        srcs = [
            "@llvm-project//clang:builtin_headers_files",
        ],
        tags = ["manual"],
    )

    mtree_mutate(
        name = "builtin_headers_mtree",
        mtree = "builtin_headers_mtree_",
        strip_prefix = "clang/lib/Headers",
        package_dir = "lib/clang/{}/include".format(LLVM_VERSION_MAJOR),
        tags = ["manual"],
    )

    bin_files = {
        "@llvm-project//clang:clang.stripped": "bin/clang",
        "@llvm-project//lld:lld.stripped": "bin/lld",
        "@llvm-project//llvm:llvm-ar.stripped": "bin/llvm-ar",
        "@llvm-project//llvm:llvm-as.stripped": "bin/llvm-as",
        "@llvm-project//llvm:llvm-libtool-darwin.stripped": "bin/llvm-libtool-darwin",
        "@llvm-project//llvm:llvm-nm.stripped": "bin/llvm-nm",
        "@llvm-project//llvm:llvm-objcopy.stripped": "bin/llvm-objcopy",
        # "@llvm-project//llvm-cov:llvm-cov",
        # "@llvm-project//llvm-dwp:llvm-dwp",
        # "@llvm-project//llvm-objdump:llvm-objdump",
        # "@llvm-project//llvm-profdata:llvm-profdata",
        "@llvm-project//compiler-rt:asan_ignorelist": "lib/clang/{llvm_major}/share/asan_ignorelist.txt",
        "@llvm-project//compiler-rt:msan_ignorelist": "lib/clang/{llvm_major}/share/msan_ignorelist.txt",
    }

    mtree(
        name = "bins_mtree",
        files = bin_files,
        symlinks = {
            "bin/clang-{llvm_major}": "clang",
            "bin/clang++": "clang",
            "bin/clang-cpp": "clang",
            "bin/ld.lld": "lld",
            "bin/ld64.lld": "lld",
            "bin/wasm-ld": "lld",
            "bin/llvm-dlltool": "llvm-ar",
            "bin/llvm-ranlib": "llvm-ar",
            "bin/llvm-install-name-tool": "llvm-objcopy",
            "bin/llvm-bitcode-strip": "llvm-objcopy",
            "bin/llvm-strip": "llvm-objcopy",
            # TODO(zbarsky): Consider adding these?
            "bin/clang-tidy": "empty",
            "bin/clang-format": "empty",
            "bin/clangd": "empty",
            "bin/llvm-symbolizer": "empty",
        },
        format = {
            "llvm_major": LLVM_VERSION_MAJOR,
        },
        tags = ["manual"],
    )

    native.genrule(
        name = "mtree",
        srcs = [
            ":bins_mtree",
            ":builtin_headers_mtree",
        ],
        cmd = """\
            cat $(SRCS) > $(@)
        """,
        outs = [
            "mtree_spec.mtree",
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
        mtree = ":mtree",
        tags = ["manual"],
    )
