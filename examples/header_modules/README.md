# Clang header modules

This example enables Clang header modules for a package: each library's
headers are compiled once into a Clang module (a `.pcm` file), and dependents
import the module instead of re-parsing the headers textually. Requires
Bazel 9+ (the Starlark implementation of the C++ rules).

```starlark
package(features = [
    "header_modules",
    "use_header_modules",
    "layering_check",
])
```

## The C++ standard library

System headers are declared as textual headers in the toolchain's module map,
so they can be included without a compiled module and are simply re-parsed
into every module that includes them (`:greeting_textual`).

For anything beyond small module graphs, add a dependency on the `libcxx`
target (`:greeting`): the public C++ standard library headers are then
compiled once into a Clang module and imported everywhere, which is both
faster and avoids known Clang issues with merging many textually absorbed
copies of the standard library declarations.

```starlark
cc_library(
    name = "greeting",
    srcs = ["greeting.cc"],
    hdrs = ["greeting.h"],
    deps = ["@llvm//toolchain/features/header_modules/libcxx"],
)
```

## Module codegen

Optionally, enable `header_module_codegen` and
`header_modules_codegen_functions` (per target or globally) to additionally
compile each module into an object file that provides the code for inline
functions and template instantiations triggered inside the module, which
importing translation units then no longer emit themselves.

## Caveats

- Compiled modules are shared across a configuration: targets whose language
  options diverge from the configuration-wide defaults (e.g. via per-target
  `copts` such as `-std=` or `-fno-exceptions`) can't load them and need to
  opt out with `features = ["-use_header_modules"]`.
