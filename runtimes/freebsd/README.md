# FreeBSD runtime

The `freebsd` module extension downloads the FreeBSD 15.1-RELEASE source
archive. Native `rules_cc` targets build the AArch64 and x86-64 CRT objects,
`libc`, `libsys`, `libm`, `libgcc_s`, and `ld-elf.so.1`. The toolchain builds
libc++, libc++abi, and libunwind from the selected LLVM source. The compile and
link actions support remote execution; no prebuilt FreeBSD sysroot or FreeBSD
build script is a compile or link input.

The public targets are:

- `//runtimes/freebsd:headers`
- `//runtimes/freebsd:libc`
- `//runtimes/freebsd:libsys`
- `//runtimes/freebsd:dynamic_loader`
- `//runtimes/freebsd:sysroot`

From `e2e/cross_compilation`, build the AArch64 and x86-64 C and C++ programs
with:

```sh
bazel build --config=remote \
  :hello_freebsd_aarch64 :main_freebsd_aarch64 \
  :hello_freebsd_x86_64 :main_freebsd_x86_64
```

The manual QEMU test runs on Apple Silicon macOS and requires
`qemu-system-aarch64` plus AArch64 EDK2 firmware:

```sh
bazel test --config=remote --nocache_test_results \
  :freebsd_aarch64_qemu_test
```

The test finds Homebrew QEMU automatically. `QEMU_SYSTEM_AARCH64` and
`QEMU_EFI_AARCH64` override the executable and firmware paths.

The FreeBSD BASIC-CI image provides the FreeBSD kernel, `tar`, and `chroot`.
The test chroots into `//runtimes/freebsd:sysroot`, then runs the C and C++
programs with the `ld-elf.so.1`, `libc.so.7`, and `libsys.so.7` built from the
downloaded FreeBSD source archive. The BASIC-CI userspace is not a compile or
link input.
