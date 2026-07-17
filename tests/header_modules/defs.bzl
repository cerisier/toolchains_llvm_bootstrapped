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

    # With a dependency on the libcxx target, the C++ standard library headers
    # are instead imported as a compiled module.

    cc_library(
        name = "greeter",
        srcs = ["greeter.cc"],
        hdrs = ["greeter.h"],
        deps = ["@llvm//toolchain/features/header_modules/libcxx"],
    )

    cc_test(
        name = "greeter_test",
        srcs = ["greeter_main.cc"],
        deps = [
            ":greeter",
            "@llvm//toolchain/features/header_modules/libcxx",
        ],
    )

    # With module codegen (matching Google's toolchain), modules are built
    # with local submodule visibility and compiled into object files that
    # provide the template instantiations triggered inside the module, which
    # importing translation units then no longer emit.

    codegen_features = [
        "header_module_codegen",
        "header_modules_codegen_functions",
    ]

    cc_library(
        name = "item_store",
        srcs = ["item_store.cc"],
        hdrs = ["item_store.h"],
        features = codegen_features,
        deps = ["@llvm//toolchain/features/header_modules/libcxx"],
    )

    cc_test(
        name = "item_store_test",
        srcs = ["item_store_main.cc"],
        features = codegen_features,
        deps = [
            ":item_store",
            "@llvm//toolchain/features/header_modules/libcxx",
        ],
    )
