"""Test targets for Clang header modules."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")

def header_modules_test_targets():
    """Declares the test targets for Clang header modules.

    Header modules are only supported with the Starlark implementation of the
    C++ rules, so no targets are declared with Bazel versions that don't
    provide it.
    """
    if not bazel_features.cc.supports_starlarkified_toolchains:
        return

    cc_library(
        name = "counter",
        srcs = ["counter.cc"],
        hdrs = ["counter.h"],
    )

    cc_library(
        name = "double_counter",
        hdrs = ["double_counter.h"],
        deps = [":counter"],
    )

    cc_test(
        name = "main_test",
        srcs = ["main_test.cc"],
        deps = [":double_counter"],
    )

    # Targets with system includes work without compiled modules for them:
    # system headers are declared as textual headers in the toolchain's module
    # map and are parsed textually even in `-fmodules` builds.

    cc_library(
        name = "textual_greeter",
        srcs = ["greeter.cc"],
        hdrs = ["greeter.h"],
    )

    cc_test(
        name = "greeter_textual_test",
        srcs = ["greeter_main.cc"],
        deps = [":textual_greeter"],
    )
