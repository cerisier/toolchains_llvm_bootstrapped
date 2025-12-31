# Bootstrap toolchain

This package holds bazel toolchain definitions whose LLVM toolchain binaries are
compiled from source using the `prebuilt` toolchain.

It is then used to compile user programs as long as `//toolchain:source=bootstrap`
is in the configuration.
