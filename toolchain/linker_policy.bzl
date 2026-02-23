PLATFORM_MACOS_AARCH64 = "macos_aarch64"
PLATFORM_LINUX_X86_64_GNU = "linux_x86_64_gnu"
PLATFORM_LINUX_AARCH64_GNU = "linux_aarch64_gnu"

MACOS_AARCH64_SYSROOT_LABEL = "@macos_sdk//sysroot"
MACOS_AARCH64_MINIMUM_OS_VERSION = "14.0"

# Ordered linker policy entries.
# Entry forms:
#   ("target_triple",)
#   ("arg", <value>)
#   ("runfile_arg", <flag>, <label>, <key>)
#   ("runfile_prefix_arg", <prefix>, <label>, <key>)
#   ("runfile_value", <label>, <key>)
#   ("setenv", <name>, <value>)

_ENTRY_ARITY_BY_KIND = {
    "target_triple": 1,
    "arg": 2,
    "runfile_arg": 4,
    "runfile_prefix_arg": 4,
    "runfile_value": 3,
    "setenv": 3,
}

_LINK_PARTS = {
    "target_triple": [
        ("target_triple",),
    ],
    "fuse_ld_lld": [
        ("arg", "-fuse-ld=lld"),
    ],
    "resource_dir": [
        ("runfile_arg", "-resource-dir", "//runtimes:resource_directory", "resource_dir"),
    ],
    "rtlib_compiler_rt": [
        ("arg", "-rtlib=compiler-rt"),
    ],
    "empty_sysroot": [
        ("arg", "--sysroot=/dev/null"),
    ],
    "stdlib_none": [
        ("arg", "-nostdlib++"),
    ],
    "unwindlib_none": [
        ("arg", "--unwindlib=none"),
    ],
    "crt_search_dir": [
        ("runfile_prefix_arg", "-B", "//runtimes:crt_objects_directory", "crt_objects_directory"),
    ],
    "glibc_library_search_dir": [
        ("runfile_prefix_arg", "-L", "//runtimes/glibc:glibc_library_search_directory", "libc_library_search_path"),
    ],
    "linux_default_link_flags": [
        ("arg", "-Wl,-no-as-needed"),
        ("arg", "-Wl,-z,relro,-z,now"),
    ],
    "linux_default_libs_gnu": [
        ("arg", "-Wl,--push-state"),
        ("arg", "-Wl,--as-needed"),
        ("arg", "-lpthread"),
        ("arg", "-ldl"),
        ("arg", "-Wl,--pop-state"),
    ],
    "macos_default_link_env": [
        ("setenv", "ZERO_AR_DATE", "1"),
    ],
    "macos_sysroot": [
        ("runfile_prefix_arg", "--sysroot=", MACOS_AARCH64_SYSROOT_LABEL, "macos_sysroot"),
    ],
    "macos_minimum_os_version": [
        ("arg", "-mmacosx-version-min=%s" % MACOS_AARCH64_MINIMUM_OS_VERSION),
    ],
    "macos_default_link_flags": [
        ("arg", "-headerpad_max_install_names"),
        ("arg", "-Wl,-no_warn_duplicate_libraries"),
        ("arg", "-Wl,-oso_prefix,."),
    ],
    "macos_default_libs": [
        ("runfile_value", "//runtimes/compiler-rt:clang_rt.builtins.static", "libclang_rt.builtins.a"),
        ("arg", "-lSystem"),
    ],
}

PLATFORM_POLICIES = {
    PLATFORM_MACOS_AARCH64: struct(
        constraints = ["@platforms//os:macos", "@platforms//cpu:aarch64"],
        target_triple = "aarch64-apple-darwin",
        sysroot_label = MACOS_AARCH64_SYSROOT_LABEL,
        minimum_os_version = MACOS_AARCH64_MINIMUM_OS_VERSION,
        parts = [
            "macos_default_link_env",
            "target_triple",
            "fuse_ld_lld",
            "resource_dir",
            "rtlib_compiler_rt",
            "macos_sysroot",
            "macos_minimum_os_version",
            "macos_default_link_flags",
        ],
    ),
    PLATFORM_LINUX_X86_64_GNU: struct(
        constraints = ["@platforms//os:linux", "@platforms//cpu:x86_64"],
        target_triple = "x86_64-linux-gnu",
        parts = [
            "target_triple",
            "fuse_ld_lld",
            "resource_dir",
            "rtlib_compiler_rt",
            "empty_sysroot",
            "stdlib_none",
            "unwindlib_none",
            "linux_default_link_flags",
            "crt_search_dir",
            "glibc_library_search_dir",
            "linux_default_libs_gnu",
        ],
    ),
    PLATFORM_LINUX_AARCH64_GNU: struct(
        constraints = ["@platforms//os:linux", "@platforms//cpu:aarch64"],
        target_triple = "aarch64-linux-gnu",
        parts = [
            "target_triple",
            "fuse_ld_lld",
            "resource_dir",
            "rtlib_compiler_rt",
            "empty_sysroot",
            "stdlib_none",
            "unwindlib_none",
            "linux_default_link_flags",
            "crt_search_dir",
            "glibc_library_search_dir",
            "linux_default_libs_gnu",
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

def _validate_entry(entry, context):
    if len(entry) < 1:
        fail("%s: link policy entry must be non-empty" % context)

    kind = entry[0]
    expected_arity = _ENTRY_ARITY_BY_KIND.get(kind)
    if expected_arity == None:
        fail("%s: unknown link policy entry kind: %s" % (context, kind))
    if len(entry) != expected_arity:
        fail("%s: '%s' entry expects arity %d, got %d" % (context, kind, expected_arity, len(entry)))

def _expand_part_names(part_names, context):
    entries = []
    for part_name in part_names:
        part_entries = _LINK_PARTS.get(part_name)
        if part_entries == None:
            fail("%s: unknown link policy part: %s" % (context, part_name))
        for entry in part_entries:
            _validate_entry(entry, "%s/%s" % (context, part_name))
            entries.append(entry)
    return entries

def _append_data(data, seen_data, label):
    if not seen_data.get(label):
        seen_data[label] = True
        data.append(label)

def _add_format(format_map, key, label):
    existing = format_map.get(key)
    if existing != None and existing != label:
        fail("Conflicting format mapping for key '%s': '%s' vs '%s'" % (key, existing, label))
    format_map[key] = label

def _entries_to_contract_directives(entries, policy):
    directives = []
    for entry in entries:
        kind = entry[0]

        if kind == "target_triple":
            directives.append(("arg", "-target"))
            directives.append(("arg", policy.target_triple))
        elif kind == "arg":
            directives.append(("arg", entry[1]))
        elif kind == "runfile_arg":
            directives.append(("arg", entry[1]))
            directives.append(("runfile", entry[2]))
        elif kind == "runfile_prefix_arg":
            directives.append(("runfile_prefix", entry[1], entry[2]))
        elif kind == "runfile_value":
            directives.append(("runfile", entry[1]))
        elif kind == "setenv":
            directives.append(("setenv", entry[1], entry[2]))

    return directives

def _entries_to_cc_spec(entries, policy):
    args = []
    data = []
    format_map = {}
    env = {}
    seen_data = {}

    for entry in entries:
        kind = entry[0]

        if kind == "target_triple":
            args.extend(["-target", policy.target_triple])
        elif kind == "arg":
            args.append(entry[1])
        elif kind == "runfile_arg":
            args.append(entry[1])
            args.append("{%s}" % entry[3])
            _append_data(data, seen_data, entry[2])
            _add_format(format_map, entry[3], entry[2])
        elif kind == "runfile_prefix_arg":
            args.append("%s{%s}" % (entry[1], entry[3]))
            _append_data(data, seen_data, entry[2])
            _add_format(format_map, entry[3], entry[2])
        elif kind == "runfile_value":
            args.append("{%s}" % entry[2])
            _append_data(data, seen_data, entry[1])
            _add_format(format_map, entry[2], entry[1])
        elif kind == "setenv":
            env[entry[1]] = entry[2]

    return struct(
        args = args,
        data = data,
        format = format_map,
        env = env,
    )

_CC_LINK_SPEC_PARTS_BY_NAME = {
    "resource_dir": struct(
        platform = PLATFORM_LINUX_X86_64_GNU,
        parts = ["resource_dir"],
    ),
    "crt_search_directory": struct(
        platform = PLATFORM_LINUX_X86_64_GNU,
        parts = ["crt_search_dir"],
    ),
    "fuse_ld": struct(
        platform = PLATFORM_LINUX_X86_64_GNU,
        parts = ["fuse_ld_lld"],
    ),
    "empty_sysroot_flags": struct(
        platform = PLATFORM_LINUX_X86_64_GNU,
        parts = ["empty_sysroot"],
    ),
    "rtlib_compiler_rt": struct(
        platform = PLATFORM_LINUX_X86_64_GNU,
        parts = ["rtlib_compiler_rt"],
    ),
    "stdlib": struct(
        platform = PLATFORM_LINUX_X86_64_GNU,
        parts = ["stdlib_none"],
    ),
    "unwindlib_none": struct(
        platform = PLATFORM_LINUX_X86_64_GNU,
        parts = ["unwindlib_none"],
    ),
    "linux_default_link_flags": struct(
        platform = PLATFORM_LINUX_X86_64_GNU,
        parts = ["linux_default_link_flags"],
    ),
    "linux_default_libs_gnu": struct(
        platform = PLATFORM_LINUX_X86_64_GNU,
        parts = [
            "glibc_library_search_dir",
            "linux_default_libs_gnu",
        ],
    ),
    "macos_default_link_flags": struct(
        platform = PLATFORM_MACOS_AARCH64,
        parts = [
            "macos_default_link_env",
            "macos_default_link_flags",
        ],
    ),
    "macos_default_libs": struct(
        platform = PLATFORM_MACOS_AARCH64,
        parts = ["macos_default_libs"],
    ),
}

_PLATFORM_ENTRIES_BY_PLATFORM = {
    platform: _expand_part_names(policy.parts, "platform %s" % platform)
    for platform, policy in PLATFORM_POLICIES.items()
}

def _build_cc_link_spec_entries():
    entries_by_name = {}
    for spec_name, spec in _CC_LINK_SPEC_PARTS_BY_NAME.items():
        if PLATFORM_POLICIES.get(spec.platform) == None:
            fail("cc_link_spec %s references unknown platform %s" % (spec_name, spec.platform))
        entries_by_name[spec_name] = _expand_part_names(spec.parts, "cc_link_spec %s" % spec_name)
    return entries_by_name

_CC_LINK_SPEC_ENTRIES_BY_NAME = _build_cc_link_spec_entries()

def linker_contract_directives(platform):
    policy = PLATFORM_POLICIES.get(platform)
    if policy == None:
        fail("Unsupported platform for linker contract directives: %s" % platform)
    return _entries_to_contract_directives(_PLATFORM_ENTRIES_BY_PLATFORM[platform], policy)

def cc_link_spec(spec_name):
    spec = _CC_LINK_SPEC_PARTS_BY_NAME.get(spec_name)
    if spec == None:
        fail("Unknown cc link spec: %s" % spec_name)

    policy = PLATFORM_POLICIES[spec.platform]
    return _entries_to_cc_spec(_CC_LINK_SPEC_ENTRIES_BY_NAME[spec_name], policy)
