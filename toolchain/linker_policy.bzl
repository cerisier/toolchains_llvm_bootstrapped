PLATFORM_MACOS_AARCH64 = "macos_aarch64"
PLATFORM_LINUX_X86_64_GNU = "linux_x86_64_gnu"
PLATFORM_LINUX_AARCH64_GNU = "linux_aarch64_gnu"
PLATFORM_WINDOWS_X86_64 = "windows_x86_64"

MACOS_AARCH64_SYSROOT_LABEL = "@macos_sdk//sysroot"
MACOS_AARCH64_MINIMUM_OS_VERSION = "14.0"

def _spec(args, data = [], format = {}, env = {}):
    return struct(
        args = args,
        data = data,
        format = format,
        env = env,
    )

_LINKER_ARG_GROUPS = {
    "resource_dir": _spec(
        args = [
            "-resource-dir",
            "{resource_dir}",
        ],
        data = [
            "//runtimes:resource_directory",
        ],
        format = {
            "resource_dir": "//runtimes:resource_directory",
        },
    ),
    "crt_search_directory": _spec(
        args = [
            "-B{crt_objects_directory}",
        ],
        data = [
            "//runtimes:crt_objects_directory",
        ],
        format = {
            "crt_objects_directory": "//runtimes:crt_objects_directory",
        },
    ),
    "fuse_ld": _spec(
        args = ["-fuse-ld=lld"],
    ),
    "empty_sysroot_flags": _spec(
        args = ["--sysroot=/dev/null"],
    ),
    "rtlib_compiler_rt": _spec(
        args = ["-rtlib=compiler-rt"],
    ),
    "stdlib": _spec(
        args = ["-nostdlib++"],
    ),
    "unwindlib_none": _spec(
        args = ["--unwindlib=none"],
    ),
    "linux_default_link_flags": _spec(
        args = [
            "-Wl,-no-as-needed",
            "-Wl,-z,relro,-z,now",
        ],
    ),
    "linux_default_libs_gnu": _spec(
        args = [
            "-L{libc_library_search_path}",
            "-Wl,--push-state",
            "-Wl,--as-needed",
            "-lpthread",
            "-ldl",
            "-Wl,--pop-state",
        ],
        data = [
            "//runtimes/glibc:glibc_library_search_directory",
        ],
        format = {
            "libc_library_search_path": "//runtimes/glibc:glibc_library_search_directory",
        },
    ),
    "linux_default_libs_musl": _spec(
        args = [
            "-L{libc_library_search_path}",
            "-Wl,--push-state",
            "-Wl,--as-needed",
            "-lpthread",
            "-ldl",
            "-Wl,--pop-state",
        ],
        data = [
            "//runtimes/musl:musl_library_search_directory",
        ],
        format = {
            "libc_library_search_path": "//runtimes/musl:musl_library_search_directory",
        },
    ),
    "macos_default_link_flags": _spec(
        args = [
            "-headerpad_max_install_names",
            "-Wl,-no_warn_duplicate_libraries",
            "-Wl,-oso_prefix,.",
        ],
        env = {
            "ZERO_AR_DATE": "1",
        },
    ),
    "macos_default_libs": _spec(
        args = [
            "{libclang_rt.builtins.a}",
            "-lSystem",
        ],
        data = [
            "//runtimes/compiler-rt:clang_rt.builtins.static",
        ],
        format = {
            "libclang_rt.builtins.a": "//runtimes/compiler-rt:clang_rt.builtins.static",
        },
    ),
    "windows_default_libs": _spec(
        args = [
            "-L{mingw_import_library_search_path}",
            "-L{mingw_crt_library_search_path}",
            "-lucrt",
        ],
        data = [
            "//runtimes/mingw:mingw_crt_library_search_directory",
            "//runtimes/mingw:mingw_import_libraries_directory",
        ],
        format = {
            "mingw_crt_library_search_path": "//runtimes/mingw:mingw_crt_library_search_directory",
            "mingw_import_library_search_path": "//runtimes/mingw:mingw_import_libraries_directory",
        },
    ),
}

_PLATFORM_POLICY = {
    PLATFORM_MACOS_AARCH64: struct(
        constraints = ["@platforms//os:macos", "@platforms//cpu:aarch64"],
        target_triple = "aarch64-apple-darwin",
        additional_args = [
            "--sysroot={macos_sysroot}",
            "-mmacosx-version-min=%s" % MACOS_AARCH64_MINIMUM_OS_VERSION,
        ],
        additional_data = [
            MACOS_AARCH64_SYSROOT_LABEL,
        ],
        additional_format = {
            "macos_sysroot": MACOS_AARCH64_SYSROOT_LABEL,
        },
        linker_arg_groups = [
            "fuse_ld",
            "resource_dir",
            "rtlib_compiler_rt",
            "macos_default_link_flags",
            "macos_default_libs",
        ],
    ),
    PLATFORM_LINUX_X86_64_GNU: struct(
        constraints = ["@platforms//os:linux", "@platforms//cpu:x86_64"],
        target_triple = "x86_64-linux-gnu",
        additional_args = [],
        additional_data = [],
        additional_format = {},
        linker_arg_groups = [
            "fuse_ld",
            "resource_dir",
            "rtlib_compiler_rt",
            "empty_sysroot_flags",
            "stdlib",
            "unwindlib_none",
            "linux_default_link_flags",
            "crt_search_directory",
            "linux_default_libs_gnu",
        ],
    ),
    PLATFORM_LINUX_AARCH64_GNU: struct(
        constraints = ["@platforms//os:linux", "@platforms//cpu:aarch64"],
        target_triple = "aarch64-linux-gnu",
        additional_args = [],
        additional_data = [],
        additional_format = {},
        linker_arg_groups = [
            "fuse_ld",
            "resource_dir",
            "rtlib_compiler_rt",
            "empty_sysroot_flags",
            "stdlib",
            "unwindlib_none",
            "linux_default_link_flags",
            "crt_search_directory",
            "linux_default_libs_gnu",
        ],
    ),
}

LINKER_CONSTRAINTS = {
    platform: policy.constraints
    for platform, policy in _PLATFORM_POLICY.items()
}

def target_triple_for_platform(platform):
    policy = _PLATFORM_POLICY.get(platform)
    if policy == None:
        fail("Unsupported platform for target triple: %s" % platform)
    return policy.target_triple

def linker_arg_group(spec_name):
    spec = _LINKER_ARG_GROUPS.get(spec_name)
    if spec == None:
        fail("Unknown cc link spec: %s" % spec_name)
    return spec

def _merge_specs(specs):
    merged_args = []
    merged_data = []
    merged_format = {}
    merged_env = {}
    seen_data = {}

    for spec in specs:
        merged_args.extend(spec.args)
        for label in spec.data:
            if not seen_data.get(label):
                seen_data[label] = True
                merged_data.append(label)
        for key, label in spec.format.items():
            previous = merged_format.get(key)
            if previous != None and previous != label:
                fail("Conflicting format mapping for key '%s': '%s' vs '%s'" % (key, previous, label))
            merged_format[key] = label
        for key, value in spec.env.items():
            previous = merged_env.get(key)
            if previous != None and previous != value:
                fail("Conflicting env mapping for key '%s': '%s' vs '%s'" % (key, previous, value))
            merged_env[key] = value

    return _spec(
        args = merged_args,
        data = merged_data,
        format = merged_format,
        env = merged_env,
    )

def _placeholder(arg):
    start = arg.find("{")
    if start == -1:
        return None
    end = arg.find("}", start + 1)
    if end == -1:
        fail("Unterminated placeholder in argument: %s" % arg)
    if arg.find("{", end + 1) != -1:
        fail("Only one placeholder is supported per argument: %s" % arg)
    key = arg[start + 1:end]
    return (arg[:start], key, arg[end + 1:])

def _spec_to_contract_directives(spec):
    directives = []

    for arg in spec.args:
        placeholder = _placeholder(arg)
        if placeholder == None:
            directives.append(("arg", arg))
            continue

        (prefix, key, suffix) = placeholder
        label = spec.format.get(key)
        if label == None:
            fail("Missing format key for placeholder '%s' in argument '%s'" % (key, arg))
        if suffix:
            fail("Placeholder suffixes are not supported in argument '%s'" % arg)
        if prefix:
            directives.append(("runfile_prefix", prefix, label))
        else:
            directives.append(("runfile", label))

    for name, value in spec.env.items():
        directives.append(("setenv", name, value))

    return directives

def linker_contract_directives(platform):
    policy = _PLATFORM_POLICY.get(platform)
    if policy == None:
        fail("Unsupported platform for linker contract directives: %s" % platform)

    policy_specs = [_LINKER_ARG_GROUPS[name] for name in policy.linker_arg_groups]
    merged_spec = _merge_specs(policy_specs)
    full_spec = _merge_specs([
        _spec(
            args = [
                "-target",
                policy.target_triple,
            ] + policy.additional_args,
            data = policy.additional_data,
            format = policy.additional_format,
        ),
        merged_spec,
    ])

    return _spec_to_contract_directives(full_spec)
