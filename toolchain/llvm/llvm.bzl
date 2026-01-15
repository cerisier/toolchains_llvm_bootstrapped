load("@bazel_lib//lib:expand_template.bzl", "expand_template")
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("@rules_cc//cc/toolchains:actions.bzl", "cc_action_type_set")
load("//runtimes:module_map.bzl", "module_map", "include_path")
load("//toolchain:exec_stage0_binary.bzl", "exec_stage0_binary")
load("//:directory.bzl", "headers_directory")

def declare_llvm_targets(*, suffix = ""):
    headers_directory(
        name = "builtin_headers",
        # Grab whichever version-specific dir is there.
        path = native.glob(["lib/clang/*"], exclude_directories = 0)[0] + "/include",
    )

    # Convenient exports
    native.exports_files(native.glob(["bin/*"]))

    # TODO(zbarsky): We may be able to avoid all this and exec clang directly.
    # but keep this for now so we can have an example of a stage0_binary which will be useful later.
    expand_template(
        name = "expand_header_parser",
        template = "@toolchains_llvm_bootstrapped//tools/internal:header_parser.cc",
        out = "header_parser.cc",
        substitutions = {
            "{CLANG_EXEC_PATH}": "$(execpath :bin/clang++)",
        },
        data = [
            ":bin/clang++",
        ],
    )

    exec_stage0_binary(
        name = "header_parser",
        srcs = ["header_parser.cc"],
        data = [
            ":bin/clang++" + suffix
        ],
        deps = select({
            "@platforms//os:linux": [
                "@toolchains_llvm_bootstrapped//runtimes/musl:musl_Scrt1",
                "@toolchains_llvm_bootstrapped//runtimes/musl:musl_libc",
                "@musl_libc//:musl_libc_headers",
            ],
            "//conditions:default": [],
        }),
    )

    cc_tool(
        name = "header_parser_tool",
        src = ":header_parser",
    )

    native.alias(
        name = "maybe_header_parser",
        actual = select({
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_none": ":clang++",
            "@toolchains_llvm_bootstrapped//toolchain:runtimes_stage1": ":clang++",
            "@toolchains_llvm_bootstrapped//conditions:default": ":header_parser_tool",
        }),
    )


    cc_action_type_set(
        name = "cpp_compile_actions_without_header_parsing",
        # See https://github.com/bazelbuild/rules_cc/blob/6dd2ef1fefbca004da449578c00d8ffb91a459ca/cc/toolchains/actions/BUILD#L224
        actions = [
            "@rules_cc//cc/toolchains/actions:linkstamp_compile",
            "@rules_cc//cc/toolchains/actions:cpp_compile",
            "@rules_cc//cc/toolchains/actions:cpp_module_compile",
            "@rules_cc//cc/toolchains/actions:cpp_module_codegen",
            "@rules_cc//cc/toolchains/actions:lto_backend",
            "@rules_cc//cc/toolchains/actions:clif_match",
            "@rules_cc//cc/toolchains/actions:objcpp_compile",
        ],
    )

    COMMON_TOOLS = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": ":clang",
        "@rules_cc//cc/toolchains/actions:c_compile": ":clang",
        ":cpp_compile_actions_without_header_parsing": ":clang++",
        "@rules_cc//cc/toolchains/actions:cpp_header_parsing": ":maybe_header_parser",
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
