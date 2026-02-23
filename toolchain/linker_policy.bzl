PLATFORM_MACOS_AARCH64 = "macos_aarch64"
PLATFORM_LINUX_X86_64_GNU = "linux_x86_64_gnu"
PLATFORM_LINUX_AARCH64_GNU = "linux_aarch64_gnu"

_VALID_KINDS = {
    "use": True,
    "arg": True,
    "target_triple": True,
    "runfile_arg": True,
    "runfile_prefix_arg": True,
    "runfile_value": True,
    "setenv": True,
}

_OP_LIBRARY = {
    "target_triple": [
        struct(kind = "target_triple"),
    ],
    "fuse_ld_lld": [
        struct(kind = "arg", value = "-fuse-ld=lld"),
    ],
    "resource_dir": [
        struct(kind = "runfile_arg", flag = "-resource-dir", label = "//runtimes:resource_directory", key = "resource_dir"),
    ],
    "rtlib_compiler_rt": [
        struct(kind = "arg", value = "-rtlib=compiler-rt"),
    ],
    "empty_sysroot": [
        struct(kind = "arg", value = "--sysroot=/dev/null"),
    ],
    "stdlib_none": [
        struct(kind = "arg", value = "-nostdlib++"),
    ],
    "unwindlib_none": [
        struct(kind = "arg", value = "--unwindlib=none"),
    ],
    "crt_search_dir": [
        struct(kind = "runfile_prefix_arg", prefix = "-B", label = "//runtimes:crt_objects_directory", key = "crt_objects_directory"),
    ],
    "glibc_library_search_dir": [
        struct(kind = "runfile_prefix_arg", prefix = "-L", label = "//runtimes/glibc:glibc_library_search_directory", key = "libc_library_search_path"),
    ],
    "linux_default_link_flags": [
        struct(kind = "arg", value = "-Wl,-no-as-needed"),
        struct(kind = "arg", value = "-Wl,-z,relro,-z,now"),
    ],
    "linux_default_libs": [
        struct(kind = "arg", value = "-Wl,--push-state"),
        struct(kind = "arg", value = "-Wl,--as-needed"),
        struct(kind = "arg", value = "-lpthread"),
        struct(kind = "arg", value = "-ldl"),
        struct(kind = "arg", value = "-Wl,--pop-state"),
    ],
    "macos_default_link_flags": [
        struct(kind = "arg", value = "-headerpad_max_install_names"),
        struct(kind = "arg", value = "-Wl,-no_warn_duplicate_libraries"),
        struct(kind = "arg", value = "-Wl,-oso_prefix,."),
    ],
    "macos_default_link_env": [
        struct(kind = "setenv", name = "ZERO_AR_DATE", value = "1"),
    ],
    "macos_default_libs": [
        struct(kind = "runfile_value", label = "//runtimes/compiler-rt:clang_rt.builtins.static", key = "libclang_rt.builtins.a"),
        struct(kind = "arg", value = "-lSystem"),
    ],
}

PLATFORM_POLICIES = {
    PLATFORM_MACOS_AARCH64: struct(
        constraints = ["@platforms//os:macos", "@platforms//cpu:aarch64"],
        target_triple = "aarch64-apple-darwin",
        ops = [
            struct(kind = "use", name = "macos_default_link_env"),
            struct(kind = "use", name = "target_triple"),
            struct(kind = "use", name = "fuse_ld_lld"),
            struct(kind = "use", name = "resource_dir"),
            struct(kind = "use", name = "rtlib_compiler_rt"),
            struct(kind = "runfile_prefix_arg", prefix = "--sysroot=", label = "@macos_sdk//sysroot", key = "macos_sysroot"),
            struct(kind = "arg", value = "-mmacosx-version-min=14.0"),
            struct(kind = "use", name = "macos_default_link_flags"),
        ],
    ),
    PLATFORM_LINUX_X86_64_GNU: struct(
        constraints = ["@platforms//os:linux", "@platforms//cpu:x86_64"],
        target_triple = "x86_64-linux-gnu",
        ops = [
            struct(kind = "use", name = "target_triple"),
            struct(kind = "use", name = "fuse_ld_lld"),
            struct(kind = "use", name = "resource_dir"),
            struct(kind = "use", name = "rtlib_compiler_rt"),
            struct(kind = "use", name = "empty_sysroot"),
            struct(kind = "use", name = "stdlib_none"),
            struct(kind = "use", name = "unwindlib_none"),
            struct(kind = "use", name = "linux_default_link_flags"),
            struct(kind = "use", name = "crt_search_dir"),
            struct(kind = "use", name = "glibc_library_search_dir"),
            struct(kind = "use", name = "linux_default_libs"),
        ],
    ),
    PLATFORM_LINUX_AARCH64_GNU: struct(
        constraints = ["@platforms//os:linux", "@platforms//cpu:aarch64"],
        target_triple = "aarch64-linux-gnu",
        ops = [
            struct(kind = "use", name = "target_triple"),
            struct(kind = "use", name = "fuse_ld_lld"),
            struct(kind = "use", name = "resource_dir"),
            struct(kind = "use", name = "rtlib_compiler_rt"),
            struct(kind = "use", name = "empty_sysroot"),
            struct(kind = "use", name = "stdlib_none"),
            struct(kind = "use", name = "unwindlib_none"),
            struct(kind = "use", name = "linux_default_link_flags"),
            struct(kind = "use", name = "crt_search_dir"),
            struct(kind = "use", name = "glibc_library_search_dir"),
            struct(kind = "use", name = "linux_default_libs"),
        ],
    ),
}

LINKER_CONSTRAINTS = {
    platform: policy.constraints
    for platform, policy in PLATFORM_POLICIES.items()
}

TARGET_TRIPLE_BY_PLATFORM = {
    platform: policy.target_triple
    for platform, policy in PLATFORM_POLICIES.items()
}

def target_triple_for_platform(platform):
    triple = TARGET_TRIPLE_BY_PLATFORM.get(platform)
    if triple == None:
        fail("Unsupported platform for target triple: %s" % platform)
    return triple

def macos_sysroot_label():
    return "@macos_sdk//sysroot"

def macos_minimum_os_version_default():
    return "14.0"

def _has_field(op, field):
    return hasattr(op, field)

def _validate_op(op):
    if not _has_field(op, "kind"):
        fail("Link policy op is missing required field 'kind'")
    if not _VALID_KINDS.get(op.kind):
        fail("Unknown link policy op kind: %s" % op.kind)

    if op.kind == "use":
        if not _has_field(op, "name"):
            fail("'use' op must define 'name'")
    elif op.kind == "arg":
        if not _has_field(op, "value"):
            fail("'arg' op must define 'value'")
    elif op.kind == "runfile_arg":
        if not _has_field(op, "flag") or not _has_field(op, "label") or not _has_field(op, "key"):
            fail("'runfile_arg' op must define 'flag', 'label', and 'key'")
    elif op.kind == "runfile_prefix_arg":
        if not _has_field(op, "prefix") or not _has_field(op, "label") or not _has_field(op, "key"):
            fail("'runfile_prefix_arg' op must define 'prefix', 'label', and 'key'")
    elif op.kind == "runfile_value":
        if not _has_field(op, "label") or not _has_field(op, "key"):
            fail("'runfile_value' op must define 'label' and 'key'")
    elif op.kind == "setenv":
        if not _has_field(op, "name") or not _has_field(op, "value"):
            fail("'setenv' op must define 'name' and 'value'")

def _expand_ops(op_entries):
    expanded = []
    for op in op_entries:
        _validate_op(op)
        if op.kind == "use":
            ops = _OP_LIBRARY.get(op.name)
            if ops == None:
                fail("Unknown linker policy op library key: %s" % op.name)
            for lib_op in ops:
                _validate_op(lib_op)
                expanded.append(lib_op)
        else:
            expanded.append(op)
    return expanded

def link_policy_ops(platform):
    policy = PLATFORM_POLICIES.get(platform)
    if policy == None:
        fail("Unsupported link policy platform: %s" % platform)
    return _expand_ops(policy.ops)

def _ops_to_contract_directives(ops, policy):
    directives = []
    for op in ops:
        if op.kind == "arg":
            directives.append(("arg", op.value))
        elif op.kind == "target_triple":
            directives.append(("arg", "-target"))
            directives.append(("arg", policy.target_triple))
        elif op.kind == "runfile_arg":
            directives.append(("arg", op.flag))
            directives.append(("runfile", op.label))
        elif op.kind == "runfile_prefix_arg":
            directives.append(("runfile_prefix", op.prefix, op.label))
        elif op.kind == "runfile_value":
            directives.append(("runfile", op.label))
        elif op.kind == "setenv":
            directives.append(("setenv", op.name, op.value))
        else:
            fail("Unsupported op in contract renderer: %s" % op.kind)
    return directives

def _ops_to_cc_spec(ops, policy):
    args = []
    data = []
    format_map = {}
    env = {}
    seen_data = {}

    for op in ops:
        if op.kind == "arg":
            args.append(op.value)
        elif op.kind == "target_triple":
            args.extend(["-target", policy.target_triple])
        elif op.kind == "runfile_arg":
            if op.flag:
                args.append(op.flag)
            args.append("{%s}" % op.key)
            _append_data(data, seen_data, op.label)
            _add_format(format_map, op.key, op.label)
        elif op.kind == "runfile_prefix_arg":
            args.append("%s{%s}" % (op.prefix, op.key))
            _append_data(data, seen_data, op.label)
            _add_format(format_map, op.key, op.label)
        elif op.kind == "runfile_value":
            args.append("{%s}" % op.key)
            _append_data(data, seen_data, op.label)
            _add_format(format_map, op.key, op.label)
        elif op.kind == "setenv":
            env[op.name] = op.value
        else:
            fail("Unsupported op in cc renderer: %s" % op.kind)

    return struct(
        args = args,
        data = data,
        format = format_map,
        env = env,
    )

def _append_data(data, seen_data, label):
    if not seen_data.get(label):
        seen_data[label] = True
        data.append(label)

def _add_format(format_map, key, label):
    existing = format_map.get(key)
    if existing != None and existing != label:
        fail("Conflicting format mapping for key '%s': '%s' vs '%s'" % (key, existing, label))
    format_map[key] = label

def linker_contract_directives(platform):
    policy = PLATFORM_POLICIES.get(platform)
    if policy == None:
        fail("Unsupported platform for linker contract directives: %s" % platform)
    return _ops_to_contract_directives(link_policy_ops(platform), policy)

def _cc_spec_for_platform_uses(platform, uses):
    policy = PLATFORM_POLICIES[platform]
    use_ops = [struct(kind = "use", name = name) for name in uses]
    return _ops_to_cc_spec(_expand_ops(use_ops), policy)

def cc_spec_resource_dir():
    return _cc_spec_for_platform_uses(PLATFORM_LINUX_X86_64_GNU, ["resource_dir"])

def cc_spec_crt_search_directory():
    return _cc_spec_for_platform_uses(PLATFORM_LINUX_X86_64_GNU, ["crt_search_dir"])

def cc_spec_fuse_ld():
    return _cc_spec_for_platform_uses(PLATFORM_LINUX_X86_64_GNU, ["fuse_ld_lld"])

def cc_spec_empty_sysroot_flags():
    return _cc_spec_for_platform_uses(PLATFORM_LINUX_X86_64_GNU, ["empty_sysroot"])

def cc_spec_rtlib_compiler_rt():
    return _cc_spec_for_platform_uses(PLATFORM_LINUX_X86_64_GNU, ["rtlib_compiler_rt"])

def cc_spec_stdlib():
    return _cc_spec_for_platform_uses(PLATFORM_LINUX_X86_64_GNU, ["stdlib_none"])

def cc_spec_unwindlib_none():
    return _cc_spec_for_platform_uses(PLATFORM_LINUX_X86_64_GNU, ["unwindlib_none"])

def cc_spec_linux_default_link_flags():
    return _cc_spec_for_platform_uses(PLATFORM_LINUX_X86_64_GNU, ["linux_default_link_flags"])

def cc_spec_linux_default_libs_gnu():
    return _cc_spec_for_platform_uses(PLATFORM_LINUX_X86_64_GNU, [
        "glibc_library_search_dir",
        "linux_default_libs",
    ])

def cc_spec_macos_default_link_flags():
    return _cc_spec_for_platform_uses(PLATFORM_MACOS_AARCH64, [
        "macos_default_link_env",
        "macos_default_link_flags",
    ])

def cc_spec_macos_default_libs():
    return _cc_spec_for_platform_uses(PLATFORM_MACOS_AARCH64, ["macos_default_libs"])
