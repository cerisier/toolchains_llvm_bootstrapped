load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")

def crt_object(name, out, visibility, **kwargs):
    cc_stage2_library(
        name = name + "_lib",
        **kwargs
    )

    native.filegroup(
        name = name + "_file",
        srcs = [name + "_lib"],
        output_group = "compilation_outputs",
    )

    copy_file(
        name = name,
        src = name + "_file",
        out = out,
        visibility = visibility,
    )

