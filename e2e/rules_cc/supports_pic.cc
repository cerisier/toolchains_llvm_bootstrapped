// This file tests the supports_pic capability.

// Without supports_pic, clang will default to -pic-is-pie and will emit a
// R_X86_64_PC32 relocation, which is invalid in a shared library.
//
// With supports_pic, clang will be passed -fPIC because this compiled as
// linkshared=1 and will emit a R_X86_64_GOTPCREL relocation, which is valid.
int a = 42;

// `foo` makes a direct reference to `a`, which is what triggers the relocation.
// The relocation type depends on the PIC/PIE contract.
int foo() {
    return a;
}
