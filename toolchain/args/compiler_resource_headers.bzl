load("@rules_cc//cc/toolchains:args.bzl", "cc_args")

_COMPILE_RESOURCE_HEADER_ACTIONS = [
    "@rules_cc//cc/toolchains/actions:clif_match",
    "@rules_cc//cc/toolchains/actions:cpp_compile",
    "@rules_cc//cc/toolchains/actions:cpp_header_parsing",
    "@rules_cc//cc/toolchains/actions:cpp_module_codegen",
    "@rules_cc//cc/toolchains/actions:cpp_module_compile",
    "@rules_cc//cc/toolchains/actions:linkstamp_compile",
    "@rules_cc//cc/toolchains/actions:objcpp_compile",
    "@rules_cc//cc/toolchains/actions:c_compile",
    "@rules_cc//cc/toolchains/actions:preprocess_assemble",
    "@rules_cc//cc/toolchains/actions:objc_compile",
]

def _visibility_kwargs(visibility):
    return {} if visibility == None else {"visibility": visibility}

def declare_clang_compile_resource_headers(
        *,
        name,
        resource_include_directory,
        resource_headers_data = None,
        allowlist_include_directories = None,
        visibility = None):
    """Declares explicit Clang-mode compiler resource headers."""
    if resource_headers_data == None:
        resource_headers_data = resource_include_directory
    if allowlist_include_directories == None:
        allowlist_include_directories = [resource_include_directory]

    cc_args(
        name = name,
        actions = _COMPILE_RESOURCE_HEADER_ACTIONS,
        allowlist_include_directories = allowlist_include_directories,
        # The toolchain supplies the resource headers explicitly so normal and
        # bootstrap compilers have the same ownership model. Disable Clang's
        # implicit entry instead of emitting the same -internal-isystem twice
        # and relying on header-search deduplication.
        # Do not use -resource-dir here: link actions have separate
        # resource-directory semantics, and rules_foreign_cc may combine CC,
        # CFLAGS, and LDFLAGS into one driver invocation.
        args = select({
            # The driver appends -Xclang arguments after the include
            # directories it derives from the sysroot, so the explicit entry
            # ends up after the SDK's /usr/include. That breaks -fmodules
            # builds: the SDK's sys/_types/_ptrdiff_t.h (and friends) then
            # include <stddef.h> expecting Clang's builtin header, but find the
            # SDK's own copy, which circularly includes <_types.h>. Keep the
            # implicit entry, which the driver places before the SDK headers,
            # and let Clang drop the later duplicate.
            "@platforms//os:macos": [
                "-Xclang",
                "-internal-isystem",
                "-Xclang",
                "{resource_include_directory}",
            ],
            "//conditions:default": [
                "-nobuiltininc",
                "-Xclang",
                "-internal-isystem",
                "-Xclang",
                "{resource_include_directory}",
            ],
        }),
        data = [resource_headers_data],
        format = {
            "resource_include_directory": resource_include_directory,
        },
        **_visibility_kwargs(visibility)
    )

def declare_clang_cl_compile_resource_headers(
        *,
        name,
        resource_include_directory,
        allowlist_include_directories = None,
        visibility = None):
    """Declares explicitly ordered clang-cl compiler resource headers."""
    if allowlist_include_directories == None:
        allowlist_include_directories = [resource_include_directory]

    cc_args(
        name = name,
        actions = _COMPILE_RESOURCE_HEADER_ACTIONS,
        allowlist_include_directories = allowlist_include_directories,
        args = [
            # clang-cl inserts implicit resource headers before every /imsvc,
            # unlike Clang mode, which places explicit -isystem paths first.
            # Suppress that entry so toolchain composition can provide:
            # libc++ -> compiler resource headers -> VC/UCRT/Windows SDK.
            "/clang:-nobuiltininc",
            "/imsvc{resource_include_directory}",
        ],
        data = [resource_include_directory],
        format = {
            "resource_include_directory": resource_include_directory,
        },
        **_visibility_kwargs(visibility)
    )
