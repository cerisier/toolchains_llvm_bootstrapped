load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

"""
Helper functions for defining targets.
"""
def atomic_helper_cc_library(name, pat, size, model):

    unique_filename = "lse_{}_{}_{}".format(pat, size, model)

    # cc_library will always produce an archive file containing lse.o.
    # Because those end up in a static library, cc_static_library will complain
    # that the archive has lse.o specified multiple times.
    copy_file(
        name = unique_filename,
        src = "lib/builtins/aarch64/lse.S",
        out = "{}.S".format(unique_filename),
        allow_symlink = True,
    )

    cc_library(
        name = name,
        srcs = [unique_filename],
        local_defines = [
            "L_{}".format(pat),
            "SIZE={}".format(size),
            "MODEL={}".format(model),
        ],
        hdrs = [
            "lib/builtins/assembly.h",
        ],
        includes = ["lib/builtins"],
    )
    return name
