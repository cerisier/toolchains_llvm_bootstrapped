"""Regression tests for the generated Linux kernel header architecture map."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "@kernel_headers//:linux_kernel_version_map.bzl",
    "LINUX_KERNEL_ARCHS_BY_VERSION",
    "LINUX_KERNEL_VERSION_MAP",
)

def _linux_kernel_archs_by_version_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "4.14.336", LINUX_KERNEL_VERSION_MAP["4.14"])
    asserts.equals(
        env,
        ["arm", "arm64", "s390", "x86"],
        LINUX_KERNEL_ARCHS_BY_VERSION["4.14.336"],
    )
    asserts.equals(
        env,
        ["arm", "arm64", "riscv", "s390", "x86"],
        LINUX_KERNEL_ARCHS_BY_VERSION["4.15.18"],
    )

    asserts.equals(env, "3.6.11", LINUX_KERNEL_VERSION_MAP["3.6"])
    asserts.equals(
        env,
        ["arm", "s390", "x86"],
        LINUX_KERNEL_ARCHS_BY_VERSION["3.6.11"],
    )
    asserts.equals(
        env,
        ["arm", "arm64", "s390", "x86"],
        LINUX_KERNEL_ARCHS_BY_VERSION["3.7.10"],
    )

    return unittest.end(env)

linux_kernel_archs_by_version_test = unittest.make(
    _linux_kernel_archs_by_version_test_impl,
)
