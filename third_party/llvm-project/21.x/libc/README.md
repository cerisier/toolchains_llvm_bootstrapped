# LLVM libc

This contains a subset of internal headers from the LLVM libc which fall under
the Apache License 2.0  with LLVM Exceptions.

Sadly, starting LLVM 20.1.0, libcxx started depending on internal headers of the
LLVM libc implementation.

For now, I've resorted to not depend on llvm-project source tarball because it is
140MB and decided to go the same way ziglang does: include the subset of headers
required by libcxx.

These will have to be monitored when updating LLVM.
