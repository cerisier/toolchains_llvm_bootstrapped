load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _test_shared_library_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    compilation_context, compilation_outputs = cc_common.compile(
        actions = ctx.actions,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        name = ctx.label.name,
        srcs = ctx.files.srcs,
    )
    linking_context, linking_outputs = cc_common.create_linking_context_from_compilation_outputs(
        actions = ctx.actions,
        additional_inputs = ctx.files.additional_linker_inputs,
        cc_toolchain = cc_toolchain,
        compilation_outputs = compilation_outputs,
        disallow_static_libraries = True,
        feature_configuration = feature_configuration,
        name = ctx.label.name,
        user_link_flags = [
            ctx.expand_location(linkopt, targets = ctx.attr.additional_linker_inputs)
            for linkopt in ctx.attr.linkopts
        ],
    )

    library = linking_outputs.library_to_link
    files = [library.dynamic_library]
    if library.interface_library != None:
        files.append(library.interface_library)

    return [
        DefaultInfo(files = depset(files)),
        CcInfo(
            compilation_context = compilation_context,
            linking_context = linking_context,
        ),
    ]

test_shared_library = rule(
    implementation = _test_shared_library_impl,
    attrs = {
        "additional_linker_inputs": attr.label_list(allow_files = True),
        "linkopts": attr.string_list(),
        "srcs": attr.label_list(allow_files = [".c", ".cc"]),
    },
    fragments = ["cpp"],
    provides = [CcInfo],
    toolchains = use_cpp_toolchain(),
)

def _interface_library_test_impl(ctx):
    libraries = []
    for linker_input in ctx.attr.library[CcInfo].linking_context.linker_inputs.to_list():
        libraries.extend(linker_input.libraries)

    if len(libraries) != 1:
        fail("{} must propagate exactly one library through CcInfo, got {}".format(
            ctx.attr.library.label,
            len(libraries),
        ))

    library = libraries[0]
    if library.dynamic_library == None:
        fail("{} does not propagate a dynamic_library through CcInfo".format(ctx.attr.library.label))
    if library.interface_library == None:
        fail("{} does not propagate an interface_library through CcInfo".format(ctx.attr.library.label))

    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.expand_template(
        is_executable = True,
        output = executable,
        substitutions = {},
        template = ctx.file._test_script,
    )

    dynamic_library = library.dynamic_library
    interface_library = library.interface_library
    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(files = [
                dynamic_library,
                interface_library,
            ]),
        ),
        RunEnvironmentInfo(environment = {
            "DYNAMIC_LIBRARY": dynamic_library.short_path,
            "INTERFACE_LIBRARY": interface_library.short_path,
            "VERSIONED_SYMBOLS": "yes" if ctx.attr.versioned_symbols else "no",
        }),
    ]

interface_library_test = rule(
    implementation = _interface_library_test_impl,
    attrs = {
        "library": attr.label(
            mandatory = True,
            providers = [CcInfo],
        ),
        "versioned_symbols": attr.bool(),
        "_test_script": attr.label(
            allow_single_file = True,
            default = ":verify_interface_library.sh",
        ),
    },
    test = True,
)
