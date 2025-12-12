load("@tar.bzl", "tar")

def extra_bins_release(name):
    BINS = [
        "@glibc-stubs-generator//:glibc-stubs-generator",
        "@libstdcxx-stubs-generator//:libstdc++-stubs-generator"
    ]

    native.genrule(
        name = "{}_mtree".format(name),
        srcs = BINS,
        cmd = """\
cat <<EOF > $(@)
bin/glibc-stubs-generator uid=0 gid=0 time=1672560000 mode=0755 type=file content=$(location @glibc-stubs-generator//:glibc-stubs-generator)
bin/libstdcxx-stubs-generator uid=0 gid=0 time=1672560000 mode=0755 type=file content=$(location @libstdcxx-stubs-generator//:libstdc++-stubs-generator)
EOF
""",
        outs = [
            "{}.mtree".format(name),
        ],
    )

    tar(
        name = name,
        srcs = BINS,
        args = [
            "--options",
            "zstd:compression-level=22",
        ],
        compress = "zstd",
        mtree = "{}_mtree".format(name),
    )
