load("@bazel_lib//lib:run_binary.bzl", "run_binary")

def stub_library(name, out = None, visibility = None):
    out = out or "lib%s.a" % name
    run_binary(
        name = name,
        outs = [out],
        tool = "//tools:llvm-ar",
        args = ["rc", "$@"],
        visibility = visibility,
    )

