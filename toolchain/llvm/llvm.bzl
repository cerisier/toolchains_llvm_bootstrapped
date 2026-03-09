load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@bazel_skylib//rules/directory:directory.bzl", "directory")
load("@bazel_skylib//rules/directory:subdirectory.bzl", "subdirectory")
load("@llvm//runtimes:copy_to_resource_directory.bzl", "copy_to_resource_directory")
load("@llvm//runtimes:module_map.bzl", "include_path", "module_map")
load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//:directory.bzl", "headers_directory")
load("//toolchain:selects.bzl", "platform_extra_binary")

def declare_llvm_targets(*, suffix = ""):
    headers_directory(
        name = "builtin_headers",
        # Grab whichever version-specific dir is there.
        path = native.glob(["lib/clang/*"], exclude_directories = 0)[0],
        visibility = ["//visibility:public"],
    )

    # Convenient exports
    native.exports_files(native.glob(["bin/*"]))

    native_binary(
        name = "header-parser",
        src = platform_extra_binary("bin/header-parser"),
        out = "prebuilts/bin/header-parser" + suffix,
    )

    native_binary(
        name = "prebuilt-clang++",
        src = "bin/clang++" + suffix,
        out = "prebuilts/bin/clang++" + suffix,
    )

    cc_tool(
        name = "header_parser",
        src = ":header-parser",
        data = [
            ":builtin_headers",
            ":prebuilt-clang++",
        ],
        allowlist_include_directories = [":builtin_headers"],
    )

    cc_args(
        name = "resource_dir",
        actions = [
            "@rules_cc//cc/toolchains/actions:compile_actions",
            "@rules_cc//cc/toolchains/actions:link_actions",
        ],
        allowlist_include_directories = [
            ":builtin_headers",
        ],
        args = [
            "-resource-dir",
            "{resource_dir}",
        ],
        data = [
            ":resource_directory",
        ],
        format = {
            "resource_dir": ":resource_directory",
        },
        visibility = ["//visibility:public"],
    )

    # TODO(zbarsky): If we could specify the paths to these via env vars, we wouldn't need to copy things around.
    native_binary(
        name = "static-library-validator",
        src = platform_extra_binary("bin/static-library-validator"),
        out = "prebuilts/bin/static-library-validator" + suffix,
    )

    native_binary(
        name = "llvm-nm",
        src = "bin/llvm-nm" + suffix,
        out = "prebuilts/bin/llvm-nm" + suffix,
    )

    native_binary(
        name = "c++filt",
        src = "bin/c++filt" + suffix,
        out = "prebuilts/bin/c++filt" + suffix,
    )

    cc_tool(
        name = "static_library_validator",
        src = ":static-library-validator",
        data = [
            ":c++filt",
            ":llvm-nm",
        ],
    )

    COMMON_TOOLS = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": ":clang",
        "@rules_cc//cc/toolchains/actions:c_compile": ":clang",
        "@rules_cc//cc/toolchains/actions:objc_compile": ":clang",
        "@llvm//toolchain:cpp_compile_actions_without_header_parsing": ":clang++",
        "@rules_cc//cc/toolchains/actions:cpp_header_parsing": ":header_parser",
        "@rules_cc//cc/toolchains/actions:link_actions": ":lld",
        "@rules_cc//cc/toolchains/actions:objcopy_embed_data": ":llvm-objcopy",
        "@rules_cc//cc/toolchains/actions:dwp": ":llvm-dwp",
        "@rules_cc//cc/toolchains/actions:strip": ":llvm-strip",
        "@rules_cc//cc/toolchains/actions:validate_static_library": ":static_library_validator",
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
        name = "llvm-dwp",
        src = "bin/llvm-dwp" + suffix,
    )

    cc_tool(
        name = "llvm-strip",
        src = "bin/llvm-strip" + suffix,
    )

    copy_to_resource_directory(
        name = "resource_directory",
        hdrs = [":builtin_headers"],
        srcs = {
            "@llvm//runtimes/compiler-rt:clang_rt.builtins.static": "libclang_rt.builtins",
        } | select({
            "@llvm//config:ubsan_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.ubsan_standalone.static": "libclang_rt.ubsan_standalone",
                "@llvm//runtimes/compiler-rt:clang_rt.ubsan_standalone_cxx.static": "libclang_rt.ubsan_standalone_cxx",
            },
            "@llvm//config:cfi_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.cfi.static": "libclang_rt.cfi",
                "@llvm//runtimes/compiler-rt:clang_rt.cfi_diag.static": "libclang_rt.cfi_diag",
                "@llvm//runtimes/compiler-rt:clang_rt.ubsan_standalone.static": "libclang_rt.ubsan_standalone",
                "@llvm//runtimes/compiler-rt:clang_rt.ubsan_standalone_cxx.static": "libclang_rt.ubsan_standalone_cxx",
                "@llvm//runtimes/compiler-rt:clang_rt.cfi_ignorelist": "share/cfi_ignorelist.txt",
            },
            "@llvm//config:msan_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.msan.static": "libclang_rt.msan",
                "@llvm//runtimes/compiler-rt:clang_rt.msan_cxx.static": "libclang_rt.msan_cxx",
            },
            "@llvm//config:dfsan_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.dfsan.static": "libclang_rt.dfsan",
                "@llvm//runtimes/compiler-rt:clang_rt.dfsan_abilist": "share/dfsan_abilist",
            },
            "@llvm//config:nsan_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.nsan.static": "libclang_rt.nsan",
            },
            "@llvm//config:safestack_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.safestack.static": "libclang_rt.safestack",
            },
            "@llvm//config:rtsan_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.rtsan.static": "libclang_rt.rtsan",
            },
            "@llvm//config:tysan_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.tysan.static": "libclang_rt.tysan",
            },
            "@llvm//config:tsan_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.tsan.static": "libclang_rt.tsan",
                "@llvm//runtimes/compiler-rt:clang_rt.tsan_cxx.static": "libclang_rt.tsan_cxx",
            },
            "@llvm//config:asan_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.asan_cxx.static": "libclang_rt.asan_cxx",
                "@llvm//runtimes/compiler-rt:clang_rt.asan_static.static": "libclang_rt.asan_static",
                "@llvm//runtimes/compiler-rt:clang_rt.asan.static": "libclang_rt.asan",
                "@llvm//runtimes/compiler-rt:clang_rt.asan.shared": "libclang_rt.asan",
            },
            "@llvm//config:lsan_enabled": {
                "@llvm//runtimes/compiler-rt:clang_rt.lsan.static": "libclang_rt.lsan",
            },
            "//conditions:default": {},
        }),
        visibility = ["//visibility:public"],
    )

    include_path(
        name = "macos_target_headers",
        srcs = [
            ":resource_directory",
            "@macos_sdk//sysroot",
        ],
    )

    # This must match //toolchain:linux_toolchain_args
    include_path(
        name = "linux_target_headers",
        srcs = [
            ":resource_directory",
            "@llvm//runtimes/libcxx:libcxx_headers_include_search_directory",
            "@llvm//runtimes/libcxx:libcxxabi_headers_include_search_directory",
            "@kernel_headers//:kernel_headers_directory",
            "@llvm//sanitizers:sanitizers_headers_include_search_directory",
        ] + select({
            "@llvm//platforms/config:musl": [
                "@llvm//runtimes/musl:musl_headers_include_search_directory",
            ],
            "@llvm//platforms/config:gnu": [
                "@llvm//runtimes/glibc:glibc_headers_include_search_directory",
            ],
        }),
    )

    # this must match //toolchain:windows_toolchain_args
    include_path(
        name = "windows_target_headers",
        srcs = [
            ":resource_directory",
            "@llvm//runtimes/libcxx:libcxx_headers_include_search_directory",
            "@llvm//runtimes/libcxx:libcxxabi_headers_include_search_directory",
            "@mingw//:mingw_generated_headers_crt_directory",
            "@mingw//:mingw_w64_headers_include_directory",
            "@mingw//:mingw_w64_headers_crt_directory",
            "@mingw//:mingw_w64_winpthreads_include_directory",
        ],
    )

    include_path(
        name = "wasm_target_headers",
        srcs = [
            ":resource_directory",
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
        visibility = ["//visibility:public"],
    )
