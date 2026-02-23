PLATFORM_MACOS_AARCH64 = "macos_aarch64"
PLATFORM_LINUX_X86_64_GNU = "linux_x86_64_gnu"
PLATFORM_LINUX_AARCH64_GNU = "linux_aarch64_gnu"

_OP_LIBRARY = {
    "target_triple": [
        {"kind": "target_triple"},
    ],
    "fuse_ld_lld": [
        {"kind": "arg", "value": "-fuse-ld=lld"},
    ],
    "resource_dir": [
        {
            "kind": "runfile_arg",
            "flag": "-resource-dir",
            "label": "//runtimes:resource_directory",
            "key": "resource_dir",
        },
    ],
    "rtlib_compiler_rt": [
        {"kind": "arg", "value": "-rtlib=compiler-rt"},
    ],
    "empty_sysroot": [
        {"kind": "arg", "value": "--sysroot=/dev/null"},
    ],
    "stdlib_none": [
        {"kind": "arg", "value": "-nostdlib++"},
    ],
    "unwindlib_none": [
        {"kind": "arg", "value": "--unwindlib=none"},
    ],
    "crt_search_dir": [
        {
            "kind": "runfile_prefix_arg",
            "prefix": "-B",
            "label": "//runtimes:crt_objects_directory",
            "key": "crt_objects_directory",
        },
    ],
    "glibc_library_search_dir": [
        {
            "kind": "runfile_prefix_arg",
            "prefix": "-L",
            "label": "//runtimes/glibc:glibc_library_search_directory",
            "key": "libc_library_search_path",
        },
    ],
    "linux_default_link_flags": [
        {"kind": "arg", "value": "-Wl,-no-as-needed"},
        {"kind": "arg", "value": "-Wl,-z,relro,-z,now"},
    ],
    "linux_default_libs": [
        {"kind": "arg", "value": "-Wl,--push-state"},
        {"kind": "arg", "value": "-Wl,--as-needed"},
        {"kind": "arg", "value": "-lpthread"},
        {"kind": "arg", "value": "-ldl"},
        {"kind": "arg", "value": "-Wl,--pop-state"},
    ],
    "macos_default_link_flags": [
        {"kind": "arg", "value": "-headerpad_max_install_names"},
        {"kind": "arg", "value": "-Wl,-no_warn_duplicate_libraries"},
        {"kind": "arg", "value": "-Wl,-oso_prefix,."},
    ],
    "macos_default_link_env": [
        {"kind": "setenv", "name": "ZERO_AR_DATE", "value": "1"},
    ],
    "macos_default_libs": [
        {
            "kind": "runfile_value",
            "label": "//runtimes/compiler-rt:clang_rt.builtins.static",
            "key": "libclang_rt.builtins.a",
        },
        {"kind": "arg", "value": "-lSystem"},
    ],
}

PLATFORM_POLICIES = {
    PLATFORM_MACOS_AARCH64: {
        "constraints": ["@platforms//os:macos", "@platforms//cpu:aarch64"],
        "target_triple": "aarch64-apple-darwin",
        "ops": [
            {"use": "macos_default_link_env"},
            {"use": "target_triple"},
            {"use": "fuse_ld_lld"},
            {"use": "resource_dir"},
            {"use": "rtlib_compiler_rt"},
            {
                "kind": "runfile_prefix_arg",
                "prefix": "--sysroot=",
                "label": "@macos_sdk//sysroot",
                "key": "macos_sysroot",
            },
            {"kind": "arg", "value": "-mmacosx-version-min=14.0"},
            {"use": "macos_default_link_flags"},
        ],
    },
    PLATFORM_LINUX_X86_64_GNU: {
        "constraints": ["@platforms//os:linux", "@platforms//cpu:x86_64"],
        "target_triple": "x86_64-linux-gnu",
        "ops": [
            {"use": "target_triple"},
            {"use": "fuse_ld_lld"},
            {"use": "resource_dir"},
            {"use": "rtlib_compiler_rt"},
            {"use": "empty_sysroot"},
            {"use": "stdlib_none"},
            {"use": "unwindlib_none"},
            {"use": "linux_default_link_flags"},
            {"use": "crt_search_dir"},
            {"use": "glibc_library_search_dir"},
            {"use": "linux_default_libs"},
        ],
    },
    PLATFORM_LINUX_AARCH64_GNU: {
        "constraints": ["@platforms//os:linux", "@platforms//cpu:aarch64"],
        "target_triple": "aarch64-linux-gnu",
        "ops": [
            {"use": "target_triple"},
            {"use": "fuse_ld_lld"},
            {"use": "resource_dir"},
            {"use": "rtlib_compiler_rt"},
            {"use": "empty_sysroot"},
            {"use": "stdlib_none"},
            {"use": "unwindlib_none"},
            {"use": "linux_default_link_flags"},
            {"use": "crt_search_dir"},
            {"use": "glibc_library_search_dir"},
            {"use": "linux_default_libs"},
        ],
    },
}

LINKER_CONSTRAINTS = {
    platform: policy["constraints"]
    for platform, policy in PLATFORM_POLICIES.items()
}

TARGET_TRIPLE_BY_PLATFORM = {
    platform: policy["target_triple"]
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

def _expand_ops(op_entries):
    expanded = []
    for entry in op_entries:
        use_name = entry.get("use")
        if use_name != None:
            ops = _OP_LIBRARY.get(use_name)
            if ops == None:
                fail("Unknown linker policy op library key: %s" % use_name)
            expanded.extend(ops)
        else:
            expanded.append(entry)
    return expanded

def link_policy_ops(platform):
    policy = PLATFORM_POLICIES.get(platform)
    if policy == None:
        fail("Unsupported link policy platform: %s" % platform)
    return _expand_ops(policy["ops"])

def _ops_to_contract_directives(ops, policy):
    directives = []
    for op in ops:
        kind = op["kind"]
        if kind == "arg":
            directives.append(("arg", op["value"]))
        elif kind == "target_triple":
            directives.append(("arg", "-target"))
            directives.append(("arg", policy["target_triple"]))
        elif kind == "runfile_arg":
            directives.append(("arg", op["flag"]))
            directives.append(("runfile", op["label"]))
        elif kind == "runfile_prefix_arg":
            directives.append(("runfile_prefix", op["prefix"], op["label"]))
        elif kind == "runfile_value":
            directives.append(("runfile", op["label"]))
        elif kind == "setenv":
            directives.append(("setenv", op["name"], op["value"]))
        else:
            fail("Unknown link policy op kind for contract renderer: %s" % kind)
    return directives

def _ops_to_cc_spec(ops, policy):
    args = []
    data = []
    format_map = {}
    env = {}
    seen_data = {}

    for op in ops:
        kind = op["kind"]
        if kind == "arg":
            args.append(op["value"])
        elif kind == "target_triple":
            args.extend(["-target", policy["target_triple"]])
        elif kind == "runfile_arg":
            if op["flag"]:
                args.append(op["flag"])
            args.append("{%s}" % op["key"])
            _append_data(data, seen_data, op["label"])
            _add_format(format_map, op["key"], op["label"])
        elif kind == "runfile_prefix_arg":
            args.append("%s{%s}" % (op["prefix"], op["key"]))
            _append_data(data, seen_data, op["label"])
            _add_format(format_map, op["key"], op["label"])
        elif kind == "runfile_value":
            args.append("{%s}" % op["key"])
            _append_data(data, seen_data, op["label"])
            _add_format(format_map, op["key"], op["label"])
        elif kind == "setenv":
            env[op["name"]] = op["value"]
        else:
            fail("Unknown link policy op kind for cc renderer: %s" % kind)

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

def cc_spec_resource_dir():
    policy = PLATFORM_POLICIES[PLATFORM_LINUX_X86_64_GNU]
    return _ops_to_cc_spec(_expand_ops([{"use": "resource_dir"}]), policy)

def cc_spec_crt_search_directory():
    policy = PLATFORM_POLICIES[PLATFORM_LINUX_X86_64_GNU]
    return _ops_to_cc_spec(_expand_ops([{"use": "crt_search_dir"}]), policy)

def cc_spec_fuse_ld():
    policy = PLATFORM_POLICIES[PLATFORM_LINUX_X86_64_GNU]
    return _ops_to_cc_spec(_expand_ops([{"use": "fuse_ld_lld"}]), policy)

def cc_spec_empty_sysroot_flags():
    policy = PLATFORM_POLICIES[PLATFORM_LINUX_X86_64_GNU]
    return _ops_to_cc_spec(_expand_ops([{"use": "empty_sysroot"}]), policy)

def cc_spec_rtlib_compiler_rt():
    policy = PLATFORM_POLICIES[PLATFORM_LINUX_X86_64_GNU]
    return _ops_to_cc_spec(_expand_ops([{"use": "rtlib_compiler_rt"}]), policy)

def cc_spec_stdlib():
    policy = PLATFORM_POLICIES[PLATFORM_LINUX_X86_64_GNU]
    return _ops_to_cc_spec(_expand_ops([{"use": "stdlib_none"}]), policy)

def cc_spec_unwindlib_none():
    policy = PLATFORM_POLICIES[PLATFORM_LINUX_X86_64_GNU]
    return _ops_to_cc_spec(_expand_ops([{"use": "unwindlib_none"}]), policy)

def cc_spec_linux_default_link_flags():
    policy = PLATFORM_POLICIES[PLATFORM_LINUX_X86_64_GNU]
    return _ops_to_cc_spec(_expand_ops([{"use": "linux_default_link_flags"}]), policy)

def cc_spec_linux_default_libs_gnu():
    policy = PLATFORM_POLICIES[PLATFORM_LINUX_X86_64_GNU]
    return _ops_to_cc_spec(_expand_ops([
        {"use": "glibc_library_search_dir"},
        {"use": "linux_default_libs"},
    ]), policy)

def cc_spec_macos_default_link_flags():
    policy = PLATFORM_POLICIES[PLATFORM_MACOS_AARCH64]
    return _ops_to_cc_spec(_expand_ops([
        {"use": "macos_default_link_env"},
        {"use": "macos_default_link_flags"},
    ]), policy)

def cc_spec_macos_default_libs():
    policy = PLATFORM_POLICIES[PLATFORM_MACOS_AARCH64]
    return _ops_to_cc_spec(_expand_ops([{"use": "macos_default_libs"}]), policy)
