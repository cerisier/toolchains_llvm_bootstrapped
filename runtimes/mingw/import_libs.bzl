load("@bazel_lib//lib:run_binary.bzl", "run_binary")

def _sanitize_label(segment):
    result = []
    for idx in range(len(segment)):
        c = segment[idx:idx + 1].lower()
        if (("a" <= c) and (c <= "z")) or (("0" <= c) and (c <= "9")):
            result.append(c)
        else:
            result.append("_")
    value = "".join(result)
    if not value:
        fail("Cannot sanitize empty label segment")
    if ("0" <= value[0]) and (value[0] <= "9"):
        value = "_" + value
    return value

_ARCH_MACROS = {
    "x86_64": "__x86_64__",
    "aarch64": "__aarch64__",
}

_SKIP_DEF_SUBSTRINGS = [
    "-common",
]

_SKIP_DEF_BASENAMES = {
    "crt-aliases.def.in": True,
}

def _generate_def_impl(ctx):
    out = ctx.outputs.out
    args = ctx.actions.args()
    args.add_all(["-E", "-P", "-xc"])
    args.add("-D{}=1".format(ctx.attr.arch_macro))

    include_dirs = [
        ctx.file.include_anchor.dirname,
        ctx.file.src.dirname,
    ]
    for include_dir in include_dirs:
        args.add("-I", include_dir)

    # ucrtbase-common.def.in:1800:28: warning: missing terminating ' character [-Winvalid-pp-token]
    # 1800 | F_LD64(_o_remainderl) ; Can't use long double functions from the CRT on x86
    args.add("-Wno-invalid-pp-token")

    args.add("-o", out.path)
    args.add(ctx.file.src.path)

    inputs = [ctx.file.src, ctx.file.include_anchor] + ctx.files.additional_includes

    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = ctx.executable.tool,
        arguments = [args],
        mnemonic = "MingwGenerateDef",
    )

_generate_def = rule(
    implementation = _generate_def_impl,
    attrs = {
        "src": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "include_anchor": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "additional_includes": attr.label_list(
            allow_files = True,
        ),
        "arch_macro": attr.string(mandatory = True),
        "tool": attr.label(
            executable = True,
            allow_files = True,
            cfg = "exec",
            mandatory = True,
        ),
        "out": attr.output(mandatory = True),
    },
)

def _ensure_processed_def(path, arch):
    if arch not in _ARCH_MACROS:
        fail("Unsupported architecture {} for {}".format(arch, path))

    base = path.rsplit("/", 1)[1][:-len(".def.in")]
    out = "generated-defs/{}/{}.def".format(arch, base)
    target = "generate_def_{}_{}".format(arch, _sanitize_label(base))
    macro = _ARCH_MACROS[arch]

    if not native.existing_rule(target):
        directory = path.rsplit("/", 1)[0]
        additional_includes = [
            f
            for f in native.glob(["%s/*.def.in" % directory], allow_empty = True)
            if f != path
        ]
        _generate_def(
            name = target,
            src = path,
            include_anchor = "mingw-w64-crt/def-include/func.def.in",
            additional_includes = [
                "mingw-w64-crt/def-include/crt-aliases.def.in",
            ] + additional_includes,
            tool = ":clang_for_def",
            arch_macro = macro,
            out = out,
        )
    return out

def _collect_definitions(preferred_dirs, arch):
    mappings = {}
    for directory in preferred_dirs:
        for path in sorted(native.glob(["%s/*.def" % directory], allow_empty = True)):
            name = path.rsplit("/", 1)[1][:-4]
            key = _sanitize_label(name)
            if key not in mappings:
                mappings[key] = struct(
                    name = name,
                    src = path,
                )
        for path in sorted(native.glob(["%s/*.def.in" % directory], allow_empty = True)):
            base = path.rsplit("/", 1)[1]
            skip = False
            for substr in _SKIP_DEF_SUBSTRINGS:
                if substr in base:
                    skip = True
                    break
            if skip:
                continue
            if base in _SKIP_DEF_BASENAMES:
                continue
            processed = _ensure_processed_def(path, arch)
            name = path.rsplit("/", 1)[1][:-len(".def.in")]
            key = _sanitize_label(name)
            if key not in mappings:
                mappings[key] = struct(
                    name = name,
                    src = processed,
                )
    return mappings

def define_mingw_imports(name, dlltool_flags, directories):
    defs = _collect_definitions(directories, name)
    import_targets = []

    for key in sorted(defs.keys()):
        info = defs[key]
        out = "import-libs/{}/lib{}.a".format(name, info.name)
        target = "import_lib_{}_{}".format(name, key)
        run_binary(
            name = target,
            srcs = [info.src],
            outs = [out],
            tool = ":dlltool",
            args = dlltool_flags + [
                "-d",
                "$(location %s)" % info.src,
                "-l",
                "$@",
            ],
            visibility = ["//visibility:public"],
        )
        import_targets.append(target)

    native.filegroup(
        name = "mingw_import_libraries_{}".format(name),
        srcs = import_targets,
        visibility = ["//visibility:public"],
    )
