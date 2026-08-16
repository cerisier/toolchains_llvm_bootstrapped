WINDOWS_ABIS = [
    "unconstrained",
    "gnu",
    "gnullvm",
    "msvc",
]

# Constraint defaults apply to every OS. Consumers of this setting must also
# require @platforms//os:windows before interpreting one of these values.
WINDOWS_DEFAULT_ABI = "unconstrained"
WINDOWS_GENERIC_PLATFORM_ABI = "gnu"

WINDOWS_TARGET_TRIPLES = {
    ("x86_64", "unconstrained"): "x86_64-w64-windows-gnu",
    ("x86_64", "gnu"): "x86_64-w64-windows-gnu",
    ("x86_64", "gnullvm"): "x86_64-w64-windows-gnu",
    ("x86_64", "msvc"): "x86_64-pc-windows-msvc",
    ("aarch64", "unconstrained"): "aarch64-w64-windows-gnu",
    ("aarch64", "gnu"): "aarch64-w64-windows-gnu",
    ("aarch64", "gnullvm"): "aarch64-w64-windows-gnu",
    ("aarch64", "msvc"): "aarch64-pc-windows-msvc",
}

WINDOWS_TARGET_TRIPLES_BY_CONFIG = {
    "@llvm//platforms/config:windows_{}_{}".format(target_cpu, target_abi): target_triple
    for (target_cpu, target_abi), target_triple in WINDOWS_TARGET_TRIPLES.items()
}

# The existing Windows C/C++ toolchain is configured with MinGW headers,
# runtimes, GNU driver syntax, and GNU-mode LLD. Rust's gnullvm target uses the
# same LLVM *-windows-gnu target environment, so it is compatible too.
WINDOWS_MINGW_COMPATIBLE_ABIS = [
    "unconstrained",
    "gnu",
    "gnullvm",
]
