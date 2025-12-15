load("//constraints/libc:libc_versions.bzl", "LIBCS", "DEFAULT_LIBC")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")

# For use with zig tools that consume parse zig targets triples
# Zig target triples only, not LLVM
def libc_aware_target_triple():
    target = {}
    for (target_os, target_cpu) in LIBC_SUPPORTED_TARGETS:
        for libc_version in LIBCS + ["unconstrained"]:
            target_libc_suffix = libc_version if libc_version != "unconstrained" else DEFAULT_LIBC
            target["//platforms/config:{}_{}_{}".format(target_os, target_cpu, libc_version)] = "{}-{}-{}".format(target_cpu, target_os, target_libc_suffix)

    return select(target)
