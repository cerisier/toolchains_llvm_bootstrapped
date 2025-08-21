load("@rules_cc//cc:defs.bzl", "cc_library")
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
        copts = [
            # Normally, we would pass -nostdinc, but since we pass -nostdlibinc
            # from the stage2 toolchain args regarless, having them both cause a
            # warning about -nostdlibinc being ignored, so we duplicate the
            # -nostdlibinc and add -nobuiltininc to avoid the warning.
            #
            # -nostdinc = -nostdlibinc -nobuiltininc
            "-nostdlibinc",
            "-nobuiltininc",
        ],
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
