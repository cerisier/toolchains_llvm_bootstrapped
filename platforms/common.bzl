ARCH_ALIASES = {
    "x86_64": ["amd64"],
    "aarch64": ["arm64"],
    "riscv64": [],
    "s390x": [],
    "armv7": [],
    "ppc64le": [],
}

# These targets intentionally provide only a compiler, assembler, and linker.
# They do not imply a hosted C or C++ runtime.
FREESTANDING_TARGETS = [
    ("linux", "ppc64le"),
]

SUPPORTED_TARGETS = [
    ("macos", "x86_64"),
    ("macos", "aarch64"),
    ("linux", "x86_64"),
    ("linux", "aarch64"),
    ("linux", "riscv64"),
    ("linux", "s390x"),
    ("linux", "armv7"),
    ("linux", "ppc64le"),
    ("windows", "x86_64"),
    ("windows", "aarch64"),
    ("none", "bpfeb"),
    ("none", "bpfel"),
    ("none", "wasm32"),
    ("none", "wasm64"),
]

SUPPORTED_EXECS = [
    ("macos", "x86_64"),
    ("macos", "aarch64"),
    ("linux", "x86_64"),
    ("linux", "aarch64"),
    ("windows", "x86_64"),
    ("windows", "aarch64"),
]

LIBC_SUPPORTED_TARGETS = [
    ("linux", "x86_64"),
    ("linux", "aarch64"),
    ("linux", "riscv64"),
    ("linux", "s390x"),
    ("linux", "armv7"),
]
