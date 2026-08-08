"""Tests for architecture-aware libc defaults."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//3rd_party/libc/glibc:helpers.bzl", "glibc_version_config_settings")
load("//constraints/libc:libc_versions.bzl", "resolve_libc")
load("//kernel/extension:libc_kernel_versions.bzl", "libc_kernel_version")

_ORDINARY_LINUX_CPUS = [
    "x86_64",
    "aarch64",
    "s390x",
    "armv7",
]

def _architecture_aware_default_libc_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        "gnu.2.33",
        resolve_libc("linux", "riscv64", "unconstrained"),
    )
    asserts.equals(
        env,
        "5.12.19",
        libc_kernel_version("linux", "riscv64", "unconstrained"),
    )

    for target_cpu in _ORDINARY_LINUX_CPUS:
        asserts.equals(
            env,
            "gnu.2.28",
            resolve_libc("linux", target_cpu, "unconstrained"),
        )
        asserts.equals(
            env,
            "4.19.325",
            libc_kernel_version("linux", target_cpu, "unconstrained"),
        )

    # Explicit constraints must not be remapped, even on RISC-V.
    asserts.equals(env, "gnu.2.28", resolve_libc("linux", "riscv64", "gnu.2.28"))
    asserts.equals(env, "musl", resolve_libc("linux", "riscv64", "musl"))

    glibc_2_28_to_2_32 = glibc_version_config_settings([
        "gnu.2.28",
        "gnu.2.29",
        "gnu.2.30",
        "gnu.2.31",
        "gnu.2.32",
    ])
    glibc_2_33 = glibc_version_config_settings(["gnu.2.33"])
    riscv_unconstrained = "@llvm//platforms/config:linux_riscv64_unconstrained"

    asserts.equals(env, False, riscv_unconstrained in glibc_2_28_to_2_32)
    asserts.equals(env, True, riscv_unconstrained in glibc_2_33)
    for target_cpu in _ORDINARY_LINUX_CPUS:
        unconstrained = "@llvm//platforms/config:linux_{}_unconstrained".format(target_cpu)
        asserts.equals(env, True, unconstrained in glibc_2_28_to_2_32)
        asserts.equals(env, False, unconstrained in glibc_2_33)

    return unittest.end(env)

architecture_aware_default_libc_test = unittest.make(
    _architecture_aware_default_libc_test_impl,
)
