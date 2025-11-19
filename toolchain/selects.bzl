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
        tool_repo = "@llvm-toolchain-minimal-%s-darwin-arm64//" % LLVM_VERSION
    elif exec_cpu == "x86_64":
        tool_repo = "@llvm-toolchain-minimal-%s-linux-amd64//" % LLVM_VERSION
    else:
        tool_repo = "@llvm-toolchain-minimal-%s-linux-arm64//" % LLVM_VERSION

    # Even though `tool_map` is exec-configured, this `select` happens under the target configuration.
    # That's because Bazel resolves the select before applying the exec transition, but if these targets
    # point at further aliases that use `select`, those will resolve according to the exec platform.
    # See https://github.com/bazelbuild/bazel/issues/27623#issuecomment-3529439585 for more details.
    return select({
        "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_macos_setting": tool_repo + ":tools_with_libtool",
        "//conditions:default": tool_repo + ":default_tools",
    })