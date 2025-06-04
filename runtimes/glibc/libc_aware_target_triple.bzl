load("//constraints/libc:libc_versions.bzl", _libc_versions = "LIBCS")
load("//platforms:common.bzl", _libc_supported_targets = "LIBC_SUPPORTED_TARGETS")

# For use with zig tools that consume parse zig targets triples
# Zig target triples only, not LLVM
def libc_aware_target_triple():
    target = {}
    for (target_os, target_cpu) in _libc_supported_targets:
        target["//platforms/config/libc_aware:{}_{}".format(target_os, target_cpu)] = "{}-{}-gnu.2.28".format(target_cpu, target_os)

        for libc_version in _libc_versions:
            target["//platforms/config/libc_aware:{}_{}_{}".format(target_os, target_cpu, libc_version)] = "{}-{}-{}".format(target_cpu, target_os, libc_version)

    return select(target)
