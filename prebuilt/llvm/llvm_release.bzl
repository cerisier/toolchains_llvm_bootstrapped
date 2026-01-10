
load("@tar.bzl", "tar", "mtree_spec", "mtree_mutate")
load("@llvm-project//:vars.bzl", "LLVM_VERSION_MAJOR")
load("//prebuilt:mtree.bzl", "mtree")

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
        "@llvm-project//clang:clang.stripped": "bin/clang" + bin_suffix,
        "@llvm-project//lld:lld.stripped": "bin/lld" + bin_suffix,
        "@llvm-project//llvm:llvm-ar.stripped": "bin/llvm-ar" + bin_suffix,
        "@llvm-project//llvm:llvm-as.stripped": "bin/llvm-as" + bin_suffix,
        "@llvm-project//llvm:llvm-libtool-darwin.stripped": "bin/llvm-libtool-darwin" + bin_suffix,
        "@llvm-project//llvm:llvm-nm.stripped": "bin/llvm-nm" + bin_suffix,
        "@llvm-project//llvm:llvm-objcopy.stripped": "bin/llvm-objcopy" + bin_suffix,
        # "@llvm-project//llvm-cov:llvm-cov",
        # "@llvm-project//llvm-dwp:llvm-dwp",
        # "@llvm-project//llvm-objdump:llvm-objdump",
        # "@llvm-project//llvm-profdata:llvm-profdata",
        "@llvm-project//compiler-rt:asan_ignorelist": "lib/clang/{llvm_major}/share/asan_ignorelist.txt",
        "@llvm-project//compiler-rt:msan_ignorelist": "lib/clang/{llvm_major}/share/msan_ignorelist.txt",
    }

    mtree(
        name = name + "_bins_mtree",
        files = bin_files,
        symlinks = {
            "bin/clang-{llvm_major}" + bin_suffix: "clang" + bin_suffix,
            "bin/clang++" + bin_suffix: "clang" + bin_suffix,
            "bin/clang-cl" + bin_suffix: "clang" + bin_suffix,
            "bin/clang-cpp" + bin_suffix: "clang" + bin_suffix,
            "bin/ld.lld" + bin_suffix: "lld" + bin_suffix,
            "bin/ld64.lld" + bin_suffix: "lld" + bin_suffix,
            "bin/lld-link" + bin_suffix: "lld" + bin_suffix,
            "bin/wasm-ld" + bin_suffix: "lld" + bin_suffix,
            "bin/llvm-dlltool" + bin_suffix: "llvm-ar" + bin_suffix,
            "bin/llvm-ranlib" + bin_suffix: "llvm-ar"+ bin_suffix,
            "bin/llvm-install-name-tool" + bin_suffix: "llvm-objcopy" + bin_suffix,
            "bin/llvm-bitcode-strip" + bin_suffix: "llvm-objcopy" + bin_suffix,
            "bin/llvm-strip" + bin_suffix: "llvm-objcopy" + bin_suffix,
            # TODO(zbarsky): Consider adding these?
            "bin/clang-tidy" + bin_suffix: "empty",
            "bin/clang-format" + bin_suffix: "empty",
            "bin/clangd" + bin_suffix: "empty",
            "bin/llvm-symbolizer" + bin_suffix: "empty",
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
