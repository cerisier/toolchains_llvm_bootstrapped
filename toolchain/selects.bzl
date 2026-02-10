LLVM_VERSION = "21.1.8"

def platform_llvm_binary(binary):
    return select({
        "@toolchains_llvm_bootstrapped//platforms/config:macos_aarch64_prebuilt": "@llvm-toolchain-minimal-%s-darwin-arm64//:bin/%s" % (LLVM_VERSION, binary),
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64_prebuilt": "@llvm-toolchain-minimal-%s-linux-amd64//:bin/%s" % (LLVM_VERSION, binary),
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64_prebuilt": "@llvm-toolchain-minimal-%s-linux-arm64//:bin/%s" % (LLVM_VERSION, binary),
        "@toolchains_llvm_bootstrapped//platforms/config:windows_aarch64_prebuilt": "@llvm-toolchain-minimal-%s-windows-arm64//:bin/%s.exe" % (LLVM_VERSION, binary),
        "@toolchains_llvm_bootstrapped//platforms/config:windows_x86_64_prebuilt": "@llvm-toolchain-minimal-%s-windows-amd64//:bin/%s.exe" % (LLVM_VERSION, binary),
        "@toolchains_llvm_bootstrapped//toolchain:bootstrapped_toolchain": "@toolchains_llvm_bootstrapped//toolchain/bootstrap:" + binary,
    })

def platform_extra_binary(binary):
    return select({
        "@toolchains_llvm_bootstrapped//platforms/config:macos_aarch64": "@toolchain-extra-prebuilts-darwin-arm64//:%s" % binary,
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": "@toolchain-extra-prebuilts-linux-amd64//:%s" % binary,
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": "@toolchain-extra-prebuilts-linux-arm64//:%s" % binary,
        # TODO(zbarsky): should we suffix these with `.exe` in the dist?
        "@toolchains_llvm_bootstrapped//platforms/config:windows_aarch64": "@toolchain-extra-prebuilts-windows-arm64//:%s" % binary,
        "@toolchains_llvm_bootstrapped//platforms/config:windows_x86_64": "@toolchain-extra-prebuilts-windows-amd64//:%s" % binary,
    })

def _tool_repo(exec_os, exec_cpu):
    if exec_os == "macos":
        return "@llvm-toolchain-minimal-%s-darwin-arm64//" % LLVM_VERSION
    elif exec_cpu == "x86_64":
        return "@llvm-toolchain-minimal-%s-%s-amd64//" % (LLVM_VERSION, exec_os)
    else:
        return "@llvm-toolchain-minimal-%s-%s-arm64//" % (LLVM_VERSION, exec_os)

def platform_module_map(exec_os, exec_cpu):
    return _tool_repo(exec_os, exec_cpu) + ":module_map"

def platform_cc_tool_map(exec_os, exec_cpu):
    tool_repo = _tool_repo(exec_os, exec_cpu)

    # Even though `tool_map` is exec-configured, this `select` happens under the target configuration.
    # That's because Bazel resolves the select before applying the exec transition, but if these targets
    # point at further aliases that use `select`, those will resolve according to the exec platform.
    # See https://github.com/bazelbuild/bazel/issues/27623#issuecomment-3529439585 for more details.
    return select({
        "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_macos_setting": tool_repo + ":tools_with_libtool",
        "//conditions:default": tool_repo + ":default_tools",
    })
