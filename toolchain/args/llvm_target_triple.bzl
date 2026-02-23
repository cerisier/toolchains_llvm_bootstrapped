load(
    "//toolchain:linker_policy.bzl",
    "PLATFORM_LINUX_AARCH64_GNU",
    "PLATFORM_LINUX_X86_64_GNU",
    "PLATFORM_MACOS_AARCH64",
    "target_triple_for_platform",
)

LLVM_TARGET_TRIPLE = select({
    #TODO: Generate this automatically
    "@llvm//platforms/config:linux_x86_64_gnu": [target_triple_for_platform(PLATFORM_LINUX_X86_64_GNU)],
    "@llvm//platforms/config:linux_aarch64_gnu": [target_triple_for_platform(PLATFORM_LINUX_AARCH64_GNU)],
    "@llvm//platforms/config:linux_x86_64_musl": ["x86_64-linux-musl"],
    "@llvm//platforms/config:linux_aarch64_musl": ["aarch64-linux-musl"],
    "@llvm//platforms/config:macos_x86_64": ["x86_64-apple-darwin"],
    "@llvm//platforms/config:macos_aarch64": [target_triple_for_platform(PLATFORM_MACOS_AARCH64)],
    "@llvm//platforms/config:windows_x86_64": ["x86_64-w64-windows-gnu"],
    "@llvm//platforms/config:windows_aarch64": ["aarch64-w64-windows-gnu"],
    "@llvm//platforms/config:none_wasm32": ["wasm32-unknown-unknown"],
    "@llvm//platforms/config:none_wasm64": ["wasm64-unknown-unknown"],
}, no_match_error = "Unsupported platform")
