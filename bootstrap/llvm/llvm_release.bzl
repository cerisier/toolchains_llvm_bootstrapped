
load("@tar.bzl", "tar", "mtree_spec", "mtree_mutate")
load("@llvm-project//:vars.bzl", "LLVM_VERSION_MAJOR")

def llvm_release(name):
    BINS = [
        "@llvm-project//clang:clang.stripped",
        "@llvm-project//lld:lld.stripped",
        "@llvm-project//llvm:llvm-ar.stripped",
        "@llvm-project//llvm:llvm-as.stripped",
        "@llvm-project//llvm:llvm-libtool-darwin.stripped",
        "@llvm-project//llvm:llvm-nm.stripped",
        "@llvm-project//llvm:llvm-objcopy.stripped",
    ] + [
        # "@llvm-project//llvm-cov:llvm-cov",
        # "@llvm-project//llvm-dwp:llvm-dwp",
        # "@llvm-project//llvm-objdump:llvm-objdump",
        # "@llvm-project//llvm-profdata:llvm-profdata",
    ]

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

    native.genrule(
        name = "sanitizers_ignorelist_mtree",
        srcs = [
            "@llvm-project//compiler-rt:asan_ignorelist",
            "@llvm-project//compiler-rt:msan_ignorelist",
        ],
        cmd = """\
cat <<EOF > $(@)
lib/clang/{llvm_major}/share/asan_ignorelist.txt uid=0 gid=0 time=1672560000 mode=0644 type=file content=$(location @llvm-project//compiler-rt:asan_ignorelist)
lib/clang/{llvm_major}/share/msan_ignorelist.txt uid=0 gid=0 time=1672560000 mode=0644 type=file content=$(location @llvm-project//compiler-rt:msan_ignorelist)
EOF
""".format(
            llvm_major = LLVM_VERSION_MAJOR,
        ),
        outs = [
            "sanitizers_ignorelist.mtree",
        ],
        tags = ["manual"],
    )

    native.genrule(
        name = "bins_mtree",
        srcs = BINS,
        cmd = """\
cat <<EOF > $(@)
bin/clang uid=0 gid=0 time=1672560000 mode=0755 type=file content=$(location @llvm-project//clang:clang.stripped)
bin/clang-{llvm_major} uid=0 gid=0 time=1672560000 mode=0755 type=link link=clang
bin/clang++ uid=0 gid=0 time=1672560000 mode=0755 type=link link=clang
bin/clang-cpp uid=0 gid=0 time=1672560000 mode=0755 type=link link=clang
bin/lld uid=0 gid=0 time=1672560000 mode=0755 type=file content=$(location @llvm-project//lld:lld.stripped)
bin/ld.lld uid=0 gid=0 time=1672560000 mode=0755 type=link link=lld
bin/ld64.lld uid=0 gid=0 time=1672560000 mode=0755 type=link link=lld
bin/wasm-ld uid=0 gid=0 time=1672560000 mode=0755 type=link link=lld
bin/llvm-ar uid=0 gid=0 time=1672560000 mode=0755 type=file content=$(location @llvm-project//llvm:llvm-ar.stripped)
bin/llvm-as uid=0 gid=0 time=1672560000 mode=0755 type=file content=$(location @llvm-project//llvm:llvm-as.stripped)
bin/llvm-libtool-darwin uid=0 gid=0 time=1672560000 mode=0755 type=file content=$(location @llvm-project//llvm:llvm-libtool-darwin.stripped)
bin/llvm-nm uid=0 gid=0 time=1672560000 mode=0755 type=file content=$(location @llvm-project//llvm:llvm-nm.stripped)
bin/llvm-objcopy uid=0 gid=0 time=1672560000 mode=0755 type=file content=$(location @llvm-project//llvm:llvm-objcopy.stripped)
bin/llvm-strip uid=0 gid=0 time=1672560000 mode=0755 type=link link=llvm-objcopy
bin/clang-tidy uid=0 gid=0 time=1672560000 mode=0755 type=link link=empty
bin/clang-format uid=0 gid=0 time=1672560000 mode=0755 type=link link=empty
bin/clangd uid=0 gid=0 time=1672560000 mode=0755 type=link link=empty
bin/llvm-symbolizer uid=0 gid=0 time=1672560000 mode=0755 type=link link=empty
EOF
""".format(
            llvm_major = LLVM_VERSION_MAJOR,
        ),
        outs = [
            "bins.mtree",
        ],
        tags = ["manual"],
    )

    native.genrule(
        name = "mtree",
        srcs = [
            ":bins_mtree",
            ":builtin_headers_mtree",
            ":sanitizers_ignorelist_mtree",
        ],
        cmd = """\
            cat $(location :sanitizers_ignorelist_mtree) > $(@)
            cat $(location :builtin_headers_mtree) >> $(@)
            cat $(location :bins_mtree) >> $(@)
        """,
        outs = [
            "mtree_spec.mtree",
        ],
        tags = ["manual"],
    )

    tar(
        name = name,
        srcs = BINS + [
            "@llvm-project//clang:builtin_headers_files",
            "@llvm-project//compiler-rt:asan_ignorelist",
            "@llvm-project//compiler-rt:msan_ignorelist",
        ],
        args = [
            "--options",
            "zstd:compression-level=22",
        ],
        compress = "zstd",
        mtree = ":mtree",
        tags = ["manual"],
    )
