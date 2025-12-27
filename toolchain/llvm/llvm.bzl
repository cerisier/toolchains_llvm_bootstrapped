load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//:directory.bzl", "headers_directory")

def declare_llvm_targets(*, suffix = ""):
    headers_directory(
        name = "builtin_headers",
        path = "lib/clang/21/include",
    )

    # Convenient exports
    native.exports_files(native.glob(["bin/*"]))

    COMMON_TOOLS = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": ":clang",
        "@rules_cc//cc/toolchains/actions:c_compile": ":clang",
        "@rules_cc//cc/toolchains/actions:cpp_compile_actions": ":clang++",
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
