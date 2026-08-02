"""Tests for portable repository-time LLVM executable paths."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//extensions:llvm_host_tools_paths.bzl", "llvm_host_tools_layout")

def _host_tools_paths_test_impl(ctx):
    env = unittest.begin(ctx)

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
