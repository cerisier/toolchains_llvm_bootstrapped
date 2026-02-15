# A Bazel-friendly fully hermetic LLVM cross-compilation toolchain

[![CI](https://github.com/cerisier/toolchains_llvm_bootstrapped/actions/workflows/ci.yaml/badge.svg)](https://github.com/cerisier/toolchains_llvm_bootstrapped/actions/workflows/ci.yaml)

> ⚠️ **Warning:** While this project is being used in production across numerous companies/projects, we are still building out some components and its behavior may change, especially around some of the configuration options (sanitizers, PIE and other link modes, etc.)

# Bazel-LLVM Ecosystem

1. **Hermetic cross-compiling `cc_toolchain`**
   We assemble LLVM with Bazeled runtimes/libc stacks to provide a zero-sysroot, hermetic C/C++ cross toolchain for many exec/target combinations (Linux glibc/musl, Windows MinGW, macOS, wasm; more coming).
2. **Bazeled LLVM targets**
   We expose Bazel targets for LLVM binaries and libraries. Some come from the upstream `@llvm-project` Bazel overlay, and we also provide missing coverage with our own BUILD files, including `compiler-rt`, `libc++`, `libc++abi`, `libunwind`, and sanitizer runtimes.
3. **WIP crossenv package targets for outside-Bazel use**
   We expose Bazel targets that package the same toolchain pieces as portable artifacts, so the ecosystem can be leveraged outside Bazel too (work in progress).

# 1) Hermetic Bazel `cc_toolchain`

## Quick Start

Add this to your `MODULE.bazel`:

```starlark
bazel_dep(name = "toolchains_llvm_bootstrapped", version = "0.5.7")

register_toolchains("@toolchains_llvm_bootstrapped//toolchain:all")
```

See https://github.com/cerisier/toolchains_llvm_bootstrapped/releases/latest

This registers all toolchains declared by this module for all supported targets.

## Description

This toolchain brings a zero-sysroot, fully hermetic C/C++ cross-compilation flow to Bazel based on LLVM.

Cross-compilation works out of the box, including with sanitizers, and requires no additional configuration.  
Remote execution also works out of the box since the toolchain is fully hermetic.

### How does it work?

Cross-compilation usually requires two main components:

1. **A cross-compiler and cross-linker** capable of generating and linking binaries for the target platform.
2. **Target-specific headers and libraries** such as CRT files, libc (glibc, musl, etc.), C++ standard library, compiler runtimes, and optional components like sanitizers.

Usually, this is done by providing a sysroot per target platform.

This ecosystem simplifies the process by cross-compiling all target-specific components from source, then compiling/linking user programs against those components in Bazel.

## Advanced Usage

### Registering a subset of all toolchains

Use the toolchain module extension:

```starlark
toolchain = use_extension("@toolchains_llvm_bootstrapped//extensions:toolchain.bzl", "toolchain")

toolchain.exec(arch = "x86_64", os = "linux")
toolchain.exec(arch = "aarch64", os = "linux")
toolchain.target(arch = "x86_64", os = "linux")
toolchain.target(arch = "aarch64", os = "linux")

use_repo(toolchain, "llvm_toolchains")

register_toolchains("@llvm_toolchains//:all")
```

This registers the cross-product of the specified exec and target platforms.

If you need finer control, register individual toolchain targets. You can list them with:

### Cgo compatibility
TODO: write about this

### Usage with Rust
TODO: write about this

```sh
bazel query 'kind(toolchain, @toolchains_llvm_bootstrapped//toolchain:all)'
```

## Supported platforms

✅ Currently supports cross-compilation between all combinations of the following platforms:

| To ↓ / From → | macOS aarch64 | Linux aarch64 | Linux x86_64 | Windows x86_64 |
|---------------|---------------|---------------|--------------|----------------|
| **aarch64-apple-darwin** | ✅ | ✅ | ✅ | ✅ |
| **x86_64-apple-darwin**  | ✅ | ✅ | ✅ | ✅ |
| **aarch64-linux-gnu ¹**  | ✅ | ✅ | ✅ | ✅ |
| **x86_64-linux-gnu ¹**   | ✅ | ✅ | ✅ | ✅ |
| **aarch64-linux-musl**   | ✅ | ✅ | ✅ | ✅ |
| **x86_64-linux-musl**    | ✅ | ✅ | ✅ | ✅ |
| **aarch64-windows-gnu ²**| ✅ | ✅ | ✅ | ✅ |
| **x86_64-windows-gnu ²** | ✅ | ✅ | ✅ | ✅ |
| **wasm32-unknown-unknown** | ✅ | ✅ | ✅ | ✅ |
| **wasm64-unknown-unknown** | ✅ | ✅ | ✅ | ✅ |

¹ See "GNU C Library" section for glibc version selection.

² See "Windows" section.

### musl

Only static linking against the latest version of musl is supported for now.

To target musl:
`--platforms @toolchains_llvm_bootstrapped//platforms:linux_aarch64_musl`

> By default, binaries are fully statically linked (no dynamic linker at all).

### GNU C Library (glibc) versions

Compiling and linking dynamically against specific glibc versions is supported.
By default, the earliest glibc version that supports your target is used (2.28 in most cases).

To target a specific version, use:
`--platforms @toolchains_llvm_bootstrapped//platforms:linux_x86_64_gnu.2.28`

Behind the scenes, code is compiled with headers for the selected glibc and linked against compatible stubs.

This ensures your program runs on systems with that glibc version or newer without using newer symbols.

### Windows

Windows is currently supported via MinGW-w64 + UCRT.
MSVCRT-based MinGW and native MSVC targets are not yet supported.

### macOS notes

Cross-compiling to macOS from any host is supported.

By default, the official macOS SDK is downloaded from Apple CDN and used hermetically.
We use a cross-platform reimplementation of `pkgutil` to unpack SDK packages, which works on all hosts.

### Other platforms

In theory, this toolchain can target all LLVM-supported targets.
We prioritize adding support based on demand.

# 2) Bazeled LLVM targets

This module exposes LLVM and runtime projects as first-class Bazel repos, so you can depend on them directly.

### Consume via `use_extension(...)`

Add this to your `MODULE.bazel`:

```starlark
bazel_dep(name = "toolchains_llvm_bootstrapped", version = "0.3.1")

llvm = use_extension("@toolchains_llvm_bootstrapped//extensions:llvm.bzl", "llvm")
use_repo(llvm, "llvm-project")
```

Then consume targets from `@llvm-project` and the runtime repos in BUILD files:

```starlark
cc_binary(
    name = "llvm_driver",
    data = ["@llvm-project//llvm:llvm.stripped"],
)

cc_shared_library(
    name = "clang",
    deps = ["@llvm-project//clang:libclang"],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "runtime_bundle",
    deps = [
        "@toolchains_llvm_bootstrapped//runtimes/compiler-rt:clang_rt.builtins.static",
        "@toolchains_llvm_bootstrapped//runtimes/compiler-rt:clang_rt.asan.static",
        "@toolchains_llvm_bootstrapped//runtimes/libcxx:libcxx.static",
        "@toolchains_llvm_bootstrapped//runtimes/libcxxabi:libcxxabi.static",
        "@toolchains_llvm_bootstrapped//runtimes/libunwind:libunwind.static",
    ],
)
```

# 3) Crossenv packages for use outside Bazel (WIP)

This is actively in progress. The goal is to produce working crossenv packages that mirror the Bazel toolchain contents so they can be reused by other build systems outside Bazel.

Current packaging targets include:

- `//prebuilt/llvm:for_linux_amd64_musl`
- `//prebuilt/llvm:for_linux_arm64_musl`
- `//prebuilt/llvm:for_macos_arm64`
- `//prebuilt/llvm:for_windows_amd64`
- `//prebuilt/llvm:for_windows_arm64`

These targets are what release workflows use to produce `.tar.zst` artifacts today. The final crossenv UX and packaging layout are still being refined.

## Roadmap

See https://github.com/cerisier/toolchains_llvm_bootstrapped/milestone/1

## Prior art

https://andrewkelley.me/post/zig-cc-powerful-drop-in-replacement-gcc-clang.html We were heavily inspired by (and rely on) the work of [Andrew Kelley](https://github.com/andrewrk) on the [zig](https://github.com/ziglang/zig) programming language compiler.

https://github.com/llvm/llvm-project which provides Bazel build definitions for many LLVM targets and the multicall/busybox machinery that is key to our small download sizes.

https://github.com/bazel-contrib/toolchains_llvm which provides a cross-compilation toolchain based on user-provided `sysroot`.

https://github.com/uber/hermetic_cc_toolchain which provides a Bazel cross-compilation toolchain built around the `zig` binary and its `cc` subcommand.

https://github.com/dzbarsky/static-clang which provides stripped subsets of LLVM binaries for lighter dependencies, as well as a starting point for missing LLVM target BUILD file authoring (`compiler-rt`, etc.).

## Thanks

None of this would have been possible without the support of [zml.ai](https://zml.ai/) for whom this toolchain was initially created. They are building a **high performance inference suite** and this is by far the most impressive Bazel project I've worked on.

A particular thank you to [@steeve](https://github.com/steeve), the founder of [zml.ai](https://zml.ai) for planting the idea and providing guidance and support.

Special mention for [@dzbarsky](https://github.com/dzbarsky), [@fmeum](https://github.com/fmeum), [@keith](https://github.com/keith), [@armandomontanez](https://github.com/armandomontanez) and the whole [bazelbuild/rules_cc](https://github.com/bazelbuild/rules_cc) team at Google for being supportive and reactive.

## In memory of

This project is dedicated to the memory of my beloved cat "Koutchi" aka "Garçon" who was everything to me.
To my little star dust <3

![IMG_1840 2](https://github.com/user-attachments/assets/333760d2-d2e1-4e69-9a20-6c3ead575b5e)
