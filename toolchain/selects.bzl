LLVM_VERSION = "21.1.4"

def platform_llvm_binary(binary):
    return select({
        "//platforms/config:macos_aarch64": "@llvm-toolchain-minimal-%s-darwin-arm64//:%s" % (LLVM_VERSION, binary),
        "//platforms/config:linux_x86_64": "@llvm-toolchain-minimal-%s-linux-amd64//:%s" % (LLVM_VERSION, binary),
        "//platforms/config:linux_aarch64": "@llvm-toolchain-minimal-%s-linux-arm64//:%s" % (LLVM_VERSION, binary),
    })

def platform_extra_binary(binary):
    return select({
        "//platforms/config:macos_aarch64": "@static-extras-toolchain-artifacts-darwin-arm64//:%s" % binary,
        "//platforms/config:linux_x86_64": "@static-extras-toolchain-artifacts-linux-amd64//:%s" % binary,
        "//platforms/config:linux_aarch64": "@static-extras-toolchain-artifacts-linux-arm64//:%s" % binary,
    })

def platform_llvm_binaries(binaries):
    return select({
        "//platforms/config:macos_aarch64": ["@llvm-toolchain-minimal-%s-darwin-arm64//:%s" % (LLVM_VERSION, binary) for binary in binaries],
        "//platforms/config:linux_x86_64": ["@llvm-toolchain-minimal-%s-linux-amd64//:%s" % (LLVM_VERSION, binary) for binary in binaries],
        "//platforms/config:linux_aarch64": ["@llvm-toolchain-minimal-%s-linux-arm64//:%s" % (LLVM_VERSION, binary) for binary in binaries],
    })

def platform_cc_tool_map(exec_os, exec_cpu):
    if exec_os == "macos":
        tool_map = "@llvm-toolchain-minimal-%s-darwin-arm64//:all_tools" % LLVM_VERSION
    elif exec_cpu == "x86_64":
        tool_map = "@llvm-toolchain-minimal-%s-linux-amd64//:all_tools" % LLVM_VERSION
    else:
        tool_map = "@llvm-toolchain-minimal-%s-linux-arm64//:all_tools" % LLVM_VERSION

    return tool_map