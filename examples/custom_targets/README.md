# Custom Targets Example

This example demonstrates how to request a reduced set of LLVM toolchains via the
`@toolchains_llvm_bootstrapped` module extension. The `MODULE.bazel` file shows
how to declare `llvm.target` and `llvm.exec` tags and register the resulting
repository of toolchains before building the simple `cc_binary` in this folder.
