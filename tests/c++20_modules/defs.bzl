"""Macros shared by the C++20 modules test fixtures."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")

_MODULE_TEST_TAGS = ["cxx20_modules"]
_MODULES_COMPATIBILITY = [] if bazel_features.cc.supports_starlarkified_toolchains else ["@platforms//:incompatible"]

def module_compatibility():
    return _MODULES_COMPATIBILITY

def module_library(
        name,
        copts,
        features = [],
        target_compatible_with = [],
        **kwargs):
    cc_library(
        name = name,
        copts = copts,
        features = ["cpp_modules"] + features,
        target_compatible_with = _MODULES_COMPATIBILITY + target_compatible_with,
        **kwargs
    )

def module_test(
        name,
        copts,
        features = [],
        target_compatible_with = [],
        **kwargs):
    cc_test(
        name = name,
        copts = copts,
        features = ["cpp_modules"] + features,
        tags = _MODULE_TEST_TAGS,
        target_compatible_with = _MODULES_COMPATIBILITY + target_compatible_with,
        **kwargs
    )
