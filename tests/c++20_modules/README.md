# C++20 modules tests

This package exercises the C++20 named-module support exposed by the hermetic
LLVM toolchain and the rule-based `rules_cc` toolchain API.

The suite covers:

- direct module imports;
- transitive imports between separate `cc_library` targets;
- module implementation units;
- multiple module interface units in one target;
- module partitions;
- global module fragments with textual headers;
- generated module interface sources;
- libc++'s `import std;`; and
- a user module that imports and re-exports `std`.

The suite requires Bazel 9 or newer. Bazel 8 can analyze and compile module
interface units, but does not propagate the generated BMI to consumers, so the
repository's Bazel 8 CI leg excludes targets tagged `cxx20_modules`.

All module targets and consumers must use compatible Clang language and code
generation options because those options form part of the BMI compatibility
signature. The package therefore applies shared compile-option lists to both
sides of each general C++20 test. The libc++ fixtures explicitly select C++23
on their consumers to match `//runtimes/libcxx:std_module`; the std module
target itself receives its module-specific mode and diagnostics through the
`libcxx_std_module` toolchain feature.

The libc++ `std` module tests have no OS-specific compatibility restriction. On
macOS, dependency scanning and BMI compilation use the configured SDK sysroot.
On every platform, `std.cppm` uses the hermetic libc++ headers rather than
toolchain-host headers.
