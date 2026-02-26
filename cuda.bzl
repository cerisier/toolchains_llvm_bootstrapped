load("@rules_cc//cc:defs.bzl", "CcInfo")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

def _cuda_arch_transition_impl(settings, attr):
    if not attr.archs:
        fail("cuda_binary requires a non-empty archs list")

    return {
        arch: {
            "//config:nvidia_compute_capability": arch,
            "//command_line_option:platforms": "//platforms:none_nvptx64",
        }
        for arch in attr.archs
    }

_cuda_arch_transition = transition(
    implementation = _cuda_arch_transition_impl,
    inputs = [],
    outputs = [
        "//config:nvidia_compute_capability",
        "//command_line_option:platforms",
    ],
)

# NO RDC ONLY
def _cuda_fatbinary_impl(ctx):
    fatbin = ctx.actions.declare_file(ctx.label.name + ".fatbin")
    args = ctx.actions.args()
    args.add("--64")
    args.add("--create=%s" % fatbin.path)
    args.add("--compress-all")

    fatbin_inputs = []
    sm_pic_objects = {}

    for arch in sorted(ctx.split_attr.deps.keys()):
        sm = arch.removeprefix("sm_")
        if sm not in sm_pic_objects:
            sm_pic_objects[sm] = []

        for dep in ctx.split_attr.deps[arch]:
            #TODO(cerisier): Avoid .to_list() in a loop here.
            for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
                for library_to_link in linker_input.libraries:
                    pic_objects = library_to_link.pic_objects
                    sm_pic_objects[sm].append(depset(pic_objects))

    for sm in sorted(sm_pic_objects.keys()):
        if not sm_pic_objects[sm]:
            continue

        pic_objects = depset(transitive = sm_pic_objects[sm])
        fatbin_inputs.append(pic_objects)
        args.add_all(
            pic_objects,
            format_each = "--image3=kind=elf,sm=%s,file=%%s" % sm,
        )

    fatbin_inputs = depset(transitive = fatbin_inputs)

    if not fatbin_inputs:
        fail("cuda_binary requires deps that produce at least one cubin file")

    ctx.actions.run(
        mnemonic = "CudaFatbin",
        progress_message = "Creating fatbin %s" % fatbin.short_path,
        executable = ctx.executable._fatbinary,
        inputs = fatbin_inputs,
        outputs = [fatbin],
        arguments = [args],
    )

    return [DefaultInfo(files = depset([fatbin]))]

cuda_fatbinary = rule(
    implementation = _cuda_fatbinary_impl,
    attrs = {
        "deps": attr.label_list(
            cfg = _cuda_arch_transition,
        ),
        "archs": attr.string_list(),
        "_fatbinary": attr.label(
            default = Label("@cuda_sdk//:fatbinary"),
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
    },
)
def _dev(label): return label + "__cuda_dev"
def _fatbin(label): return label + "__fatbin"

def cuda_library(
        name,
        srcs = [],
        hdrs = [],
        deps = [],
        archs = [],
        copts = [],
        **kwargs,
):
    # Device-only compilation for this node.
    cc_library(
        name = _dev(name),
        srcs = srcs,
        hdrs = hdrs,
        deps = deps,
    )

    # Fatbin for this node (consumes device graph transitively).
    # Deps are transitioned to @llvm//platforms:.
    cuda_fatbinary(
        name = _fatbin(name),
        deps = [_dev(name)],
        archs = archs,
    )

    # Host-only compilation for this node, includes fatbin.
    cc_library(
        name = name,
        srcs = srcs,
        hdrs = hdrs,
        deps = deps,
        copts = copts + [
            "--cuda-path=$(location @cuda_sdk//:cuda_path)",
            "--offload-host-only",
            "-Xclang", "-fcuda-include-gpubinary",
            "-Xclang", "$(execpath :%s)" % _fatbin(name),
        ],
        additional_compiler_inputs = [
            "@cuda_sdk//:cuda_path",
            _fatbin(name),
        ],
        **kwargs
    )
