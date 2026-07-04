load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//toolchain/bootstrap:transition_settings.bzl", "SANITIZER_FLAGS")

_COMMON_COPTS = [
    "-DNDEBUG",
    "-U_FORTIFY_SOURCE",
    "-D_FORTIFY_SOURCE=0",
    "-DHAVE_POSIX_MEMALIGN",
    "-fPIC",
    "-flto",
    "-fno-builtin-memalign",
    "-fno-stack-protector",
    "-Oz",
    "-g0",
    "-Wno-language-extension-token",
]

_CXXOPTS = [
    "-D_LIBCPP_ABI_NAMESPACE=__InternalSymbolizer",
    "-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS",
    "-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS",
    "-ULLVM_ENABLE_THREADS",
    "-DLLVM_ENABLE_THREADS=0",
    "-fno-exceptions",
    "-fno-rtti",
    "-Wno-global-constructors",
]

def _transition_settings(runtime_stage, configure_libcxxabi, force_libcxx_headers):
    result = {
        "//command_line_option:copt": _COMMON_COPTS,
        "//command_line_option:cxxopt": _CXXOPTS,
        "//config:internal_symbolizer": force_libcxx_headers,
        "//config:libcxxabi_internal_symbolizer": configure_libcxxabi,
        "//toolchain:runtime_stage": runtime_stage,
        "@llvm-project//third-party:llvm_enable_zstd": False,
    }
    for sanitizer in SANITIZER_FLAGS:
        result[sanitizer] = False
    return result

def _symbolizer_transition_impl(_settings, _attr):
    return _transition_settings("complete", False, True)

def _libcxx_transition_impl(_settings, _attr):
    return _transition_settings("stage1_hosted", True, False)

_TRANSITION_OUTPUTS = [
    "//command_line_option:copt",
    "//command_line_option:cxxopt",
    "//config:internal_symbolizer",
    "//config:libcxxabi_internal_symbolizer",
    "//toolchain:runtime_stage",
    "@llvm-project//third-party:llvm_enable_zstd",
] + SANITIZER_FLAGS

_symbolizer_transition = transition(
    implementation = _symbolizer_transition_impl,
    inputs = [],
    outputs = _TRANSITION_OUTPUTS,
)

_libcxx_transition = transition(
    implementation = _libcxx_transition_impl,
    inputs = [],
    outputs = _TRANSITION_OUTPUTS,
)

def _link_files(targets):
    archives = {}
    objects = {}
    for target in targets:
        for linker_input in target[CcInfo].linking_context.linker_inputs.to_list():
            for library in linker_input.libraries:
                archive = library.pic_static_library or library.static_library
                if archive:
                    archives[archive.path] = archive
                    continue
                for object_file in library.pic_objects or library.objects:
                    objects[object_file.path] = object_file
    return archives.values(), objects.values()

def _cc_internal_symbolizer_object_impl(ctx):
    if len(ctx.attr.target_triple) != 1:
        fail("target_triple must contain exactly one value")

    archives, objects = _link_files(
        ctx.attr.symbolizer +
        ctx.attr.libcxx +
        ctx.attr.libcxxabi,
    )
    inputs = archives + objects
    if not inputs:
        fail("internal symbolizer dependencies do not contain linkable files")

    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )
    compiler = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.cpp_link_executable,
    )

    bitcode = ctx.actions.declare_file(ctx.label.name + ".bc")
    api_list = ",".join(ctx.attr.global_symbols)
    target_triple = ctx.attr.target_triple[0]
    link_args = ctx.actions.args()
    link_args.add_all([
        "-target",
        target_triple,
        "-fuse-ld=lld",
        "-flto",
        "-nostdlib",
        "-shared",
        "-Wl,--lto-emit-llvm",
        "-Wl,--lto-newpm-passes=internalize",
        "-Xlinker",
        "--plugin-opt=-internalize-public-api-list=" + api_list,
    ])
    link_args.add_all(
        ctx.attr.global_symbols,
        format_each = "-Wl,--export-dynamic-symbol=%s",
    )
    link_args.add("-Wl,--whole-archive")
    link_args.add_all(archives)
    link_args.add("-Wl,--no-whole-archive")
    link_args.add_all(objects)
    link_args.add_all(["-o", bitcode])
    ctx.actions.run(
        executable = compiler,
        arguments = [link_args],
        inputs = inputs,
        outputs = [bitcode],
        execution_requirements = {"supports-path-mapping": "1"},
        mnemonic = "InternalizeSymbolizerBitcode",
        tools = cc_toolchain.all_files,
        toolchain = CC_TOOLCHAIN_TYPE,
    )

    compile_args = ctx.actions.args()
    compile_args.add_all([
        "-target",
        target_triple,
        "-x",
        "ir",
        "-c",
        "-fno-lto",
        "-Oz",
        "-g0",
        "-fPIC",
        bitcode,
        "-o",
        ctx.outputs.out,
    ])
    ctx.actions.run(
        executable = compiler,
        arguments = [compile_args],
        inputs = [bitcode],
        outputs = [ctx.outputs.out],
        execution_requirements = {"supports-path-mapping": "1"},
        mnemonic = "CompileInternalSymbolizerObject",
        tools = cc_toolchain.all_files,
        toolchain = CC_TOOLCHAIN_TYPE,
    )

    return [DefaultInfo(files = depset([ctx.outputs.out]))]

cc_internal_symbolizer_object = rule(
    implementation = _cc_internal_symbolizer_object_impl,
    attrs = {
        "global_symbols": attr.string_list(mandatory = True),
        "libcxx": attr.label(
            cfg = _libcxx_transition,
            mandatory = True,
            providers = [CcInfo],
        ),
        "libcxxabi": attr.label(
            cfg = _libcxx_transition,
            mandatory = True,
            providers = [CcInfo],
        ),
        "out": attr.output(mandatory = True),
        "symbolizer": attr.label(
            cfg = _symbolizer_transition,
            mandatory = True,
            providers = [CcInfo],
        ),
        "target_triple": attr.string_list(mandatory = True),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
