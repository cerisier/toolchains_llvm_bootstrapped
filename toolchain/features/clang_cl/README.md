# clang-cl feature protocol

This package contains the downstream rules_cc feature implementations needed
when the C++ driver speaks clang-cl's CL-compatible command-line and response
file protocol. It does not own the Windows MSVC target ABI, Microsoft SDK or
runtime closure, CRT selection, or COFF artifact naming.

The package is intentionally temporary. These implementations should be
upstreamed to rules_cc rather than remain a hermetic-llvm-specific adapter.
When upstreamed, they should live beside the corresponding rules_cc argument
features and select their concrete spelling by compiler (for example, generic
Clang versus clang-cl), instead of preserving this standalone package shape.

Module maps, layering checks, and header parsing are not implemented for this
protocol yet. Their names are temporarily tolerated because the repository's
shared e2e configuration requests `layering_check`; the empty registration is
not a support claim and must be replaced by dialect-correct actions.
