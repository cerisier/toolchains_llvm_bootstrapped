load("@rules_cc//cc:defs.bzl", "CcInfo")

def _cuda_arch_transition_impl(settings, attr):
    if not attr.archs:
        fail("cuda_binary requires a non-empty archs list")

    return {
        arch: {
            "//config:nvidia_compute_capability": arch,
        }
        for arch in attr.archs
    }

_cuda_arch_transition = transition(
    implementation = _cuda_arch_transition_impl,
    inputs = [],
    outputs = ["//config:nvidia_compute_capability"],
)

# NO RDC ONLY
def _cuda_binary_impl(ctx):
    fatbin = ctx.actions.declare_file(ctx.label.name + ".fatbin")
    args = ctx.actions.args()
    args.add("--64")
    args.add("--create=%s" % fatbin.path)

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

cuda_binary = rule(
    implementation = _cuda_binary_impl,
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
