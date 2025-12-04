TARGETS = select({
    #TODO: Generate this automatically
    "@toolchains_llvm_bootstrapped//platforms/config/libc_aware:linux_x86_64": ["x86_64-linux-gnu"],
    "@toolchains_llvm_bootstrapped//platforms/config/libc_aware:linux_aarch64": ["aarch64-linux-gnu"],
    "@toolchains_llvm_bootstrapped//platforms/config/libc_aware:linux_x86_64_gnu": ["x86_64-linux-gnu"],
    "@toolchains_llvm_bootstrapped//platforms/config/libc_aware:linux_aarch64_gnu": ["aarch64-linux-gnu"],
    "@toolchains_llvm_bootstrapped//platforms/config/libc_aware:linux_x86_64_musl": ["x86_64-linux-musl"],
    "@toolchains_llvm_bootstrapped//platforms/config/libc_aware:linux_aarch64_musl": ["aarch64-linux-musl"],
    "@toolchains_llvm_bootstrapped//platforms/config:macos_x86_64": ["x86_64-apple-darwin"],
    "@toolchains_llvm_bootstrapped//platforms/config:macos_aarch64": ["aarch64-apple-darwin"],
    "@toolchains_llvm_bootstrapped//platforms/config:none_wasm32": ["wasm32-unknown-unknown"],
    "@toolchains_llvm_bootstrapped//platforms/config:none_wasm64": ["wasm64-unknown-unknown"],
}, no_match_error = "Unsupported platform")
