"""Tests for portable repository-time LLVM executable paths."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//extensions:llvm_host_tools_paths.bzl",
    "llvm_host_tools_archive_target",
    "llvm_host_tools_layout",
)

def _host_tools_paths_test_impl(ctx):
    env = unittest.begin(ctx)

    for os_name, arch, want in [
        ("Linux", "amd64", "linux-amd64-musl"),
        ("Mac OS X", "x86_64", "darwin-amd64"),
        ("macOS", "arm64", "darwin-arm64"),
        ("Windows Server 2025", "amd64", "windows-amd64"),
        ("Windows 11", "aarch64", "windows-arm64"),
    ]:
        asserts.equals(env, want, llvm_host_tools_archive_target(os_name, arch))

    windows = llvm_host_tools_layout("windows-amd64")
    asserts.equals(env, "bin/clang.exe", windows.archive_paths["clang"])
    asserts.equals(env, "bin/ld.lld.exe", windows.archive_paths["ld_lld"])
    asserts.equals(env, "clang", windows.compatibility_paths["clang"])
    asserts.equals(env, "ld.lld", windows.compatibility_paths["ld_lld"])
    asserts.equals(env, "clang.exe", windows.probe_paths["clang"])
    asserts.equals(env, "ld.lld.exe", windows.probe_paths["ld_lld"])
    asserts.equals(env, "bin/clang.exe", windows.root_symlinks["clang"])
    asserts.equals(env, "bin/clang.exe", windows.root_symlinks["clang.exe"])
    asserts.equals(env, "bin/ld.lld.exe", windows.root_symlinks["ld.lld"])
    asserts.equals(env, "bin/ld.lld.exe", windows.root_symlinks["ld.lld.exe"])

    linux = llvm_host_tools_layout("linux-amd64-musl")
    asserts.equals(env, "bin/clang", linux.archive_paths["clang"])
    asserts.equals(env, "bin/ld.lld", linux.archive_paths["ld_lld"])
    asserts.equals(env, "bin/clang", linux.root_symlinks["clang"])
    asserts.equals(env, "bin/clang", linux.root_symlinks["clang.exe"])
    asserts.equals(env, "bin/ld.lld", linux.root_symlinks["ld.lld"])
    asserts.equals(env, "bin/ld.lld", linux.root_symlinks["ld.lld.exe"])

    darwin = llvm_host_tools_layout("darwin-arm64")
    asserts.equals(env, "bin/clang", darwin.root_symlinks["clang.exe"])
    asserts.equals(env, "bin/ld.lld", darwin.root_symlinks["ld.lld.exe"])

    return unittest.end(env)

host_tools_paths_test = unittest.make(_host_tools_paths_test_impl)
