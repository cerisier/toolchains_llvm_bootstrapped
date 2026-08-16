load("//constraints/windows/abi:abis.bzl", "WINDOWS_TARGET_TRIPLES")

def _llvm_target_triples():
    triples = {
        # TODO: Generate this automatically.
        "@llvm//platforms/config:linux_x86_64_gnu": ["x86_64-linux-gnu"],
        "@llvm//platforms/config:linux_aarch64_gnu": ["aarch64-linux-gnu"],
        "@llvm//platforms/config:linux_riscv64_gnu": ["riscv64-linux-gnu"],
        "@llvm//platforms/config:linux_s390x_gnu": ["s390x-linux-gnu"],
        "@llvm//platforms/config:linux_armv7_gnu": ["armv7-linux-gnueabihf"],
        "@llvm//platforms/config:linux_x86_64_musl": ["x86_64-linux-musl"],
        "@llvm//platforms/config:linux_aarch64_musl": ["aarch64-linux-musl"],
        "@llvm//platforms/config:linux_riscv64_musl": ["riscv64-linux-musl"],
        "@llvm//platforms/config:linux_s390x_musl": ["s390x-linux-musl"],
        "@llvm//platforms/config:linux_armv7_musl": ["armv7-linux-musleabihf"],
        "@llvm//platforms/config:macos_x86_64": ["x86_64-apple-darwin"],
        "@llvm//platforms/config:macos_aarch64": ["aarch64-apple-darwin"],
        "@llvm//platforms/config:none_bpfeb": ["bpfeb"],
        "@llvm//platforms/config:none_bpfel": ["bpfel"],
        "@llvm//platforms/config:none_wasm32": ["wasm32-unknown-unknown"],
        "@llvm//platforms/config:none_wasm64": ["wasm64-unknown-unknown"],
    }

    for (target_cpu, target_abi), target_triple in WINDOWS_TARGET_TRIPLES.items():
        triples["@llvm//platforms/config:windows_{}_{}".format(target_cpu, target_abi)] = [target_triple]

    return triples

LLVM_TARGET_TRIPLE = select(_llvm_target_triples(), no_match_error = "Unsupported platform")
