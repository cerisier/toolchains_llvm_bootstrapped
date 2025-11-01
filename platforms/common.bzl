ARCH_ALIASES = {
    "x86_64": ["amd64"],
    "aarch64": ["arm64"],
}

SUPPORTED_TARGETS = [
    ("linux", "x86_64"),
    ("linux", "aarch64"),
    ("macos", "x86_64"),
    ("macos", "aarch64"),
]

SUPPORTED_EXECS = [
    ("linux", "x86_64"),
    ("linux", "aarch64"),
    ("macos", "aarch64"),
]

LIBC_SUPPORTED_TARGETS = [
    ("linux", "x86_64"),
    ("linux", "aarch64"),
]
