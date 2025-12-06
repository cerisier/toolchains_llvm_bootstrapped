load("@bazel_lib//lib:run_binary.bzl", "run_binary")
load("@toolchains_llvm_bootstrapped//toolchain:selects.bzl", "platform_llvm_binary")

def _generate_def_impl(ctx):
    out = ctx.outputs.out

    args = ctx.actions.args()
    args.add_all(["-E", "-P", "-xc"])
    args.add("-D{}=1".format(ctx.attr.arch_macro))

    include_dirs = [
        # TODO(zbarsky): See if we can remove include_anchor...
        ctx.file.include_anchor.dirname,
        ctx.file.src.dirname,
    ]
    args.add_all(include_dirs, before_each = "-I")

    # ucrtbase-common.def.in:1800:28: warning: missing terminating ' character [-Winvalid-pp-token]
    # 1800 | F_LD64(_o_remainderl) ; Can't use long double functions from the CRT on x86
    args.add("-Wno-invalid-pp-token")

    args.add("-o", out)
    args.add(ctx.file.src)

    inputs = [ctx.file.src, ctx.file.include_anchor] + ctx.files.additional_includes

    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = ctx.executable.tool,
        arguments = [args],
        mnemonic = "MingwGenerateDef",
        execution_requirements = {"supports-path-mapping": "1"},
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

def _collect_definitions(directory):
    mappings = {}

    for path in sorted(native.glob([directory + "/*.def"])):
        name = path[path.rfind("/") + 1:-len(".def")]
        mappings[name] = path

    def_ins = native.glob([directory + "/*.def.in"], allow_empty = True)
    additional_includes = ["mingw-w64-crt/def-include/crt-aliases.def.in"] + def_ins

    for path in def_ins:
        base = path[path.rfind("/") + 1:-len(".def.in")]

        if "-common" in base:
            continue

        out = base + ".def"

        _generate_def(
            name = "generate_def_{}".format(base),
            src = path,
            include_anchor = "mingw-w64-crt/def-include/func.def.in",
            additional_includes = additional_includes,
            tool = "@llvm-project//clang",
            # tool = platform_llvm_binary("bin/clang"),
            arch_macro = select({
                "@platforms//cpu:x86_64": "__x86_64__",
                "@platforms//cpu:aarch64": "__aarch64__",
            }),
            out = out,
        )

        mappings[base] = out

    return mappings

def mingw_import_libraries(name, directory):
    defs = _collect_definitions(directory)
    import_targets = []

    for lib_name, src in defs.items():
        target = "import_lib_" + lib_name
        run_binary(
            name = target,
            srcs = [src],
            outs = ["lib{}.a".format(lib_name)],
            tool = "@llvm-project//llvm:llvm-dlltool",
            #tool = platform_llvm_binary("bin/llvm-dlltool"),
            args = select({
                "@platforms//cpu:x86_64": ["-m", "i386:x86-64"],
                "@platforms//cpu:aarch64": ["-m", "arm64"],
            }) + [
                "-d",
                "$(location %s)" % src,
                "-l",
                "$@",
            ],
        )
        import_targets.append(target)

    native.filegroup(
        name = name,
        srcs = import_targets,
    )
