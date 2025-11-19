load("@bazel_skylib//rules/directory:directory.bzl", "directory")
load("@bazel_skylib//rules/directory:subdirectory.bzl", "subdirectory")
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")

## 

directory(
    name = "builtin_headers_files",
    srcs = glob(["lib/clang/21/include/**"]),
    visibility = ["//visibility:public"],
)

subdirectory(
    name = "builtin_headers_include_directory",
    path = "lib/clang/21/include",
    parent = ":builtin_headers_files",
    visibility = ["//visibility:public"],
)

##

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
    src = "bin/clang",
    data = [
        ":builtin_headers_include_directory",
    ],
)

cc_tool(
    name = "clang++",
    src = "bin/clang++",
    data = [
        ":builtin_headers_include_directory",
    ],
)

cc_tool(
    name = "lld",
    src = "bin/clang++",
    data = [
        "bin/ld.lld",
        "bin/ld64.lld",
        "bin/lld",
    ],
)

cc_tool(
    name = "llvm-ar",
    src = "bin/llvm-ar",
)

cc_tool(
    name = "llvm-libtool-darwin",
    src = "bin/llvm-libtool-darwin",
)

cc_tool(
    name = "llvm-objcopy",
    src = "bin/llvm-objcopy",
)

cc_tool(
    name = "llvm-strip",
    src = "bin/llvm-strip",
)

##

# Convenient exports
exports_files([
    "bin/clang",
    "bin/clang++",
    "bin/clang-cpp",
    "bin/lld",
    "bin/ld.lld",
    "bin/ld64.lld",
    "bin/wasm-ld",
    "bin/llvm-ar",
    "bin/llvm-as",
    "bin/llvm-libtool-darwin",
    "bin/llvm-nm",
    "bin/llvm-objcopy",
    "bin/llvm-strip",
    # "bin/clang-tidy",
    # "bin/clang-format",
    "bin/clangd",
    # "bin/llvm-symbolizer",
    # "bin/llvm-profdata",
    # "bin/llvm-cov",
    # "bin/llvm-dwp",
    # "bin/llvm-objdump",
])
