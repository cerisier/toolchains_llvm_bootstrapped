<!--
Derived from bazelbuild/rules_rust (cross_compile example)
Copyright (c) The Bazel Authors, licensed under Apache-2.0
Modifications © 2025 Corentin Kerisit
-->

# Cross Compilation

For cross compilation, you have to specify a custom platform to let Bazel know that you are compiling for a different platform than the default host platform.

The example code is setup to cross compile from the following hosts to the the following targets using Rust and the LLVM toolchain:

* {linux, x86_64} -> {linux, aarch64}
* {linux, aarch64} -> {linux, x86_64}
* {darwin, x86_64} -> {linux, x86_64}
* {darwin, x86_64} -> {linux, aarch64}
* {darwin, aarch64 (Apple Silicon)} -> {linux, x86_64}
* {darwin, aarch64 (Apple Silicon)} -> {linux, aarch64}

Cross compilation from Linux to Apple may work, but has not been tested.

You cross-compile by calling the target.

`bazel build //:hello_world_x86_64 --config=rust`

or

`bazel build //:hello_world_aarch64 --config=rust`


You can also build all targets at once:


`bazel build //... --config=rust`

And you can run all test with:

`bazel test //... --config=rust`

The `--config=rust` statement is needed because as of this commit, `cc-rs` doesn't support `libtool` as the archiver, and the rust compilers makes the assumption that if it is running on linux, `libgcc_s` is available.
This config adds the necessary bazel flags to circumvent those issues. See `.bazelrc`.


## Setup

The setup requires three steps, first declare dependencies and toolchains in your MODULE.bazel, second configure LLVM and Rust for cross compilation, and third the configuration of the cross compilation platforms so you can use it binary targets.

### Dependencies Configuration

You add the required rules for cross compilation to your MODULE.bazel as shown below.

```Starlark
# Get latest release from:
# https://github.com/bazelbuild/rules_rust/releases
bazel_dep(name = "rules_rust", version = "0.57.1")

# https://github.com/bazelbuild/platforms/releases
bazel_dep(name = "platforms", version = "0.0.10")

# https://github.com/bazel-contrib/toolchains_llvm
bazel_dep(name = "toolchains_llvm", version = "1.2.0", dev_dependency = True)

# https://github.com/bazelbuild/bazel/blob/master/tools/build_defs/repo/http.bzl
http_archive = use_repo_rule("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
```

## Usage

Suppose you have a simple hello world that is defined in a single main.rs file. Conventionally, you declare a minimum
binary target as shown below.

```Starlark
load("@rules_rust//rust:defs.bzl", "rust_binary")

rust_binary(
    name = "hello_world_host",
    srcs = ["src/main.rs"],
    deps = [],
)
```

Bazel compiles this target to the same platform as the host. To cross-compile the same source file to a different
platform, you simply add one of the platforms previously declared, as shown below.

```Starlark
load("@rules_rust//rust:defs.bzl", "rust_binary")

rust_binary(
    name = "hello_world_x86_64",
    srcs = ["src/main.rs"],
    platform = "//build/platforms:linux-x86_64",
    deps = [],
)

rust_binary(
    name = "hello_world_aarch64",
    srcs = ["src/main.rs"],
    platform = "//build/platforms:linux-aarch64",
    deps = [],
)
```

You then cross-compile by calling the target.

`bazel build //:hello_world_x86_64 --config=rust`

or

`bazel build //:hello_world_aarch64 --config=rust`

You may have to make the target public when see an access error.

However, when you build for multiple targets, it is sensible to group all of them in a filegroup.

```Starlark
filegroup(
    name = "all",
    srcs = [
        ":hello_world_host",
        ":hello_world_x86_64",
        ":hello_world_aarch64",
    ],
    visibility = ["//visibility:public"],
)
```

Then you build for all platforms by calling the filegroup target:

`bazel build //:all --config=rust`
