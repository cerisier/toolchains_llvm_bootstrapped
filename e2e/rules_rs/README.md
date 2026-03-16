<!--
Derived from bazelbuild/rules_rust (cross_compile example)
Copyright (c) The Bazel Authors, licensed under Apache-2.0
Modifications © 2025 Corentin Kerisit
-->

# Cross Compilation With `rules_rs`

This fixture mirrors [`e2e/rules_rust`](../rules_rust/README.md), but uses `rules_rs` rule shims and `rules_rs` crate resolution.

The test suite cross-builds the same `hello_world` target for:

* Linux x86_64
* Linux aarch64
* Windows x86_64
* Windows aarch64

Run the fixture with:

```sh
bazel test //...
```

The local `.bazelrc` carries two compatibility flags:

* disable `libtool` as the macOS archiver for `cc-rs`
* enable the LLVM stub `libgcc_s` workaround

See [MODULE.bazel](./MODULE.bazel), [BUILD.bazel](./BUILD.bazel), and [rust_binary_cross_build_test_suite.bzl](./rust_binary_cross_build_test_suite.bzl) for the concrete `rules_rs` setup.
