# LLVM cross compilation toolchain for Bazel

[![CI](https://github.com/cerisier/toolchains_llvm_bootstrapped/actions/workflows/ci.yaml/badge.svg)](https://github.com/cerisier/toolchains_llvm_bootstrapped/actions/workflows/ci.yaml)

> ⚠️ **Warning:** This project is still experimental and its behaviour may change.

## Description

This toolchain brings a zero sysroot, fully hermetic C/C++ cross compilation toolchain to Bazel based on LLVM.

Cross-compilation works out of the box, including with sanitizers, and requires no additional configuration. <br />
Remote execution also works out of the box since the toolchain is fully hermetic.

### How does it work ?

Cross compilation usually requires 2 main components:
1. **A cross-compiler and cross-linker** capable of generating and linking binaries for the target platform.
2. **Target-specific headers and libraries** such as the C runtime (CRT files), libc (glibc, musl, etc.), C++ standard library (libstdc++, libc++), compiler runtimes (libgcc, compiler-rt), and optional components like profilers or sanitizers.

Usually, this is done by providing a sysroot for each target platform that contains all the target-specific components that match that of the deployment target.

This toolchain simplifies the process by cross-compiling all the target-specific components from source, and then cross-compiling and cross-linking user programs against those.

## Usage

Add this to your `MODULE.bazel`:

```starlark
bazel_dep(name = "toolchains_llvm_bootstrapped", version = "0.3.1")

register_toolchains(
    "@toolchains_llvm_bootstrapped//toolchain:all",
)
```

See https://github.com/cerisier/toolchains_llvm_bootstrapped/releases/latest

This will register all toolchains declared by this module for all supported targets.

If you wish to register only a subset of all possible toolchains, use the `@toolchains_llvm_bootstrapped//toolchain/extension:llvm.bzl` module extension like so:

```sh
llvm_toolchains = use_extension("@toolchains_llvm_bootstrapped//toolchain/extension:llvm.bzl", "llvm")

llvm_toolchains.exec(arch = "x86_64", os = "linux")
llvm_toolchains.exec(arch = "aarch64", os = "linux")
llvm_toolchains.target(arch = "x86_64", os = "linux")
llvm_toolchains.target(arch = "aarch64", os = "linux")

use_repo(llvm_toolchains, "llvm_toolchains")

register_toolchains("@llvm_toolchains//:all")
```

This will register the cross-product of the specified exec and target platforms.

If you wish to be more selective than that, you can use `register_toolchain` calls on specific tolchain targets. The list can be obtained like so:
```sh
bazel query 'kind(toolchain, @toolchains_llvm_bootstrapped//toolchain:all)'
```

## Supported platforms

✅ Currently supports cross-compilation between all combinations of the following platforms:

| To ↓ / From → | macOS aarch64 | Linux aarch64 | Linux x86_64 | Windows aarch64 | Windows x86_64 |
|---------------|---------------|--------------|---------------|--------------|-----------------|
| **aarch64-apple-darwin** | ✅ | 🚧 In Progress | 🚧 In Progress | 🚧 In Progress | 🚧 In Progress |
| **x86_64-apple-darwin**  | ✅ | 🚧 In Progress | 🚧 In Progress | 🚧 In Progress | 🚧 In Progress |
| **aarch64-linux-gnu ¹**    | ✅ | ✅ | ✅ | ✅ | ✅ |
| **x86_64-linux-gnu ¹**     | ✅ | ✅ | ✅ | ✅ | ✅ |
| **aarch64-linux-musl**    | ✅ | ✅ | ✅ | ✅ | ✅ |
| **x86_64-linux-musl**     | ✅ | ✅ | ✅ | ✅ | ✅ |
| **aarch64-windows-gnu ²**    | ✅ | ✅ | ✅ | ✅ | ✅ |
| **x86_64-windows-gnu ²**     | ✅ | ✅ | ✅ | ✅ | ✅ |
| **wasm32-unknown-unknown**  | ✅ | ✅ | ✅ | ✅ | ✅ |
| **wasm64-unknown-unknown**  | ✅ | ✅ | ✅ | ✅ | ✅ |

¹ See "GNU C Library" section for glibc version selection.

² See "Windows" section.

### musl

Only static linking against the latest version of musl is supported for now.

To target musl:
`--platforms @toolchains_llvm_bootstrapped//platforms:linux_aarch64_musl`

> By default, the binary will be fully statically link (no dynamic linker at all).

### GNU C Library ("glibc") versions

Compiling and linking dynamically against an arbitrary version of the glibc is supported.
By default, the earliest glibc version that supports your target is used (2.28 in most case).

To target a specific version, use:
`--platforms @toolchains_llvm_bootstrapped//platforms:linux_x86_64_gnu.2.28`

Behind the scenes, your code is compiled using the appropriate headers for the
target version, and dynamically linked against a stub glibc that includes only
the symbols available in that version.

This guarantees that your program will run on any system with that exact glibc
version or newer, since it never relies on symbols introduced in later versions.

### Windows

Windows is supported only via MinGW-w64 with UCRT.
MSVCRT-based MinGW and native MSVC targets are not supported.

### macOS notes

🚧 Cross-compiling to macOS from non-macOS hosts is not currently available. <br />
✅ Compilation from macOS to macOS is supported.

By default, the official macOS SDK is downlaoded from apple CDN and used hermetically.

### Other platforms

In theory, this toolchain can target all LLVM-supported targets. We prioritize adding support based on demand.

## Roadmap

See https://github.com/cerisier/toolchains_llvm_bootstrapped/milestone/1

## Prior art

https://andrewkelley.me/post/zig-cc-powerful-drop-in-replacement-gcc-clang.html I was heavily inspired by (and heavily rely on) the work of [Andrew Kelley](https://github.com/andrewrk) on the [zig](https://github.com/ziglang/zig) programming language compiler.

https://github.com/bazel-contrib/toolchains_llvm which provides a cross compilation toolchain based on user-provided `sysroot`.

https://github.com/uber/hermetic_cc_toolchain which prodives a Bazel cross compilation toolchain built around the `zig` binary and it's `cc` subcommand.

https://github.com/dzbarsky/static-clang which provides stripped subset of llvm binaries for lighter dependencies, as well as a starting point for missing llvm targets build file authoring (compiler-rt, etc.).

# Thanks

None of this would have been possible without the support of [zml.ai](https://zml.ai/) for whom this toolchain has initially been created. They are building an **high performance inference suite** and this is by far the most impressive bazel project I've worked on.

A particular thank you to [@steeve](https://github.com/steeve), the founder of [zml.ai](https://zml.ai) for planting the idea and providing guidance and support.

Special thanks to the Bazel community for answering many of my interrogations on the Bazel slack and providing guidance when needed.

Special mention for [@dzbarsky](https://github.com/dzbarsky), [@fmeum](https://github.com/fmeum), [@keith](https://github.com/keith), [@armandomontanez](https://github.com/armandomontanez) and the whole [bazelbuild/rules_cc](https://github.com/bazelbuild/rules_cc) team at Google for being supportive and reactive!

# In memory of

This project is dedicated to the memory of my beloved cat "Koutchi" aka "Garçon" who was everything to me.
To my little star dust <3

![IMG_1840 2](https://github.com/user-attachments/assets/333760d2-d2e1-4e69-9a20-6c3ead575b5e)


