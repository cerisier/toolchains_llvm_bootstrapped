load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("//toolchain/runtimes:cc_runtime_shared_library.bzl", "cc_runtime_stage0_shared_library")

def make_glibc_shared_library(
    name,
    lib_name,
    lib_version,
    srcs,
    extra_link_flags = [],
):
    cc_library(
        name = "lib%s" % lib_name,
        copts = [
            # We compile .s (!= .S) files with a lot of -D flags.
            # This is easier than having to duplicate cc_flags with and without
            # assembly preprocessor.
            "-Wno-unused-command-line-argument",
        ],
        srcs = srcs,
    )

    soname = "lib{lib}.so{version}".format(
        lib = lib_name,
        version = "."+lib_version if len(lib_version) > 0 else ""
    )

    cc_runtime_stage0_shared_library(
        name = name,
        deps = ["lib%s" % lib_name],
        additional_linker_inputs = [
            ":all.map",
        ],
        user_link_flags = [
            "-Wl,--version-script=$(location :all.map)",
            "-Wl,-soname,{}".format(soname)
        ] + extra_link_flags,
        shared_lib_name = soname,
        visibility = ["//visibility:public"],
    )

    return name
