load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//runtimes:module_map.bzl", "module_map", "include_path")
load("//toolchain:selects.bzl", "platform_extra_binary")
load("//:directory.bzl", "headers_directory")

def declare_llvm_targets(*, suffix = ""):
    headers_directory(
        name = "builtin_headers",
        # Grab whichever version-specific dir is there.
        path = native.glob(["lib/clang/*"], exclude_directories = 0)[0] + "/include",
    )

    # Convenient exports
    native.exports_files(native.glob(["bin/*"]))

    cc_tool(
        name = "header_parser",
        src = platform_extra_binary("bin/header-parser"),
        data = ["//tools:clang++"],
    )

    COMMON_TOOLS = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": ":clang",
        "@rules_cc//cc/toolchains/actions:c_compile": ":clang",
        "@toolchains_llvm_bootstrapped//toolchain:cpp_compile_actions_without_header_parsing": ":clang++",
        # TODO(zbarsky): Enable afer we release prebuilts
        #"@rules_cc//cc/toolchains/actions:cpp_header_parsing": ":header_parser",
        "@rules_cc//cc/toolchains/actions:cpp_header_parsing": ":clang++",
        "@rules_cc//cc/toolchains/actions:link_actions": ":lld",
        "@rules_cc//cc/toolchains/actions:objcopy_embed_data": ":llvm-objcopy",
        "@rules_cc//cc/toolchains/actions:strip": ":llvm-strip",
    }

    cc_tool_map(
        name = "default_tools",
        tools = COMMON_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-ar",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool_map(
        name = "tools_with_libtool",
        tools = COMMON_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-libtool-darwin",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool(
        name = "clang",
        src = "bin/clang" + suffix,
        data = [
            ":builtin_headers",
        ],
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_pic"],
        allowlist_include_directories = [":builtin_headers"],
    )

    cc_tool(
        name = "clang++",
        src = "bin/clang++" + suffix,
        data = [
            ":builtin_headers",
        ],
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_pic"],
        allowlist_include_directories = [":builtin_headers"],
    )

    cc_tool(
        name = "lld",
        src = "bin/clang++" + suffix,
        data = [
            "bin/ld.lld" + suffix,
            "bin/ld64.lld" + suffix,
            "bin/lld" + suffix,
            "bin/wasm-ld" + suffix,
        ],
    )

    cc_tool(
        name = "llvm-ar",
        src = "bin/llvm-ar" + suffix,
    )

    cc_tool(
        name = "llvm-libtool-darwin",
        src = "bin/llvm-libtool-darwin" + suffix,
    )

    cc_tool(
        name = "llvm-objcopy",
        src = "bin/llvm-objcopy" + suffix,
    )

    cc_tool(
        name = "llvm-strip",
        src = "bin/llvm-strip" + suffix,
    )

    include_path(
        name = "macos_target_headers",
        srcs = [
            ":builtin_headers",
            "@macosx15.4.sdk//:sysroot",
        ],
    )

    # This must match //toolchain:linux_toolchain_args
    include_path(
        name = "linux_target_headers",
        srcs = [
            ":builtin_headers",
            "@toolchains_llvm_bootstrapped//runtimes/libcxx:libcxx_headers_include_search_directory",
            "@toolchains_llvm_bootstrapped//runtimes/libcxx:libcxxabi_headers_include_search_directory",
            "@kernel_headers//:kernel_headers_directory",
        ] + select({
            "@toolchains_llvm_bootstrapped//platforms/config:musl": [
                "@toolchains_llvm_bootstrapped//runtimes/musl:musl_headers_include_search_directory"
            ],
            "@toolchains_llvm_bootstrapped//platforms/config:gnu": [
                "@toolchains_llvm_bootstrapped//runtimes/glibc:glibc_headers_include_search_directory",
            ],
        }),
    )

    # this must match //toolchain:windows_toolchain_args
    include_path(
        name = "windows_target_headers",
        srcs = [
            ":builtin_headers",
            "@toolchains_llvm_bootstrapped//runtimes/libcxx:libcxx_headers_include_search_directory",
            "@toolchains_llvm_bootstrapped//runtimes/libcxx:libcxxabi_headers_include_search_directory",
            "@mingw//:mingw_generated_headers_crt_directory",
            "@mingw//:mingw_w64_headers_include_directory",
            "@mingw//:mingw_w64_headers_crt_directory",
        ],
    )

    include_path(
        name = "wasm_target_headers",
        srcs = [
            ":builtin_headers",
            # TODO(zbarsky): We'll want to add wasi libc headers here.
        ],
    )

    module_map(
        name = "module_map",
        include_path = select({
            "@platforms//os:macos": ":macos_target_headers",
            "@platforms//os:linux": ":linux_target_headers",
            "@platforms//os:windows": ":windows_target_headers",
            "@platforms//os:none": ":wasm_target_headers",
        }),
        visibility = ["@toolchains_llvm_bootstrapped//toolchain:__subpackages__"],
    )
