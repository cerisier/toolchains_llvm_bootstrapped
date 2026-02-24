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

def _cuda_binary_impl(ctx):
    fatbin = ctx.actions.declare_file(ctx.label.name + ".fatbin")
    args = ctx.actions.args()
    args.add("--64")
    args.add("--create=%s" % fatbin.path)

    fatbin_inputs = []

    for arch in sorted(ctx.split_attr.deps.keys()):
        sm = arch.removeprefix("sm_")
        for dep in ctx.split_attr.deps[arch]:
            for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
                for library_to_link in linker_input.libraries:
                    for file in library_to_link.pic_objects:
                        fatbin_inputs.append(file)
                        args.add("--image3=kind=elf,sm=%s,file=%s" % (sm, file.path))

    # Keep as fallback/reference if we ever need archive extraction again.
    # extracted_dirs = []
    # direct_files = []
    # archive_index = 0
    # for arch in sorted(ctx.split_attr.deps.keys()):
    #     sm = arch.removeprefix("sm_")
    #     for dep in ctx.split_attr.deps[arch]:
    #         for file in dep[DefaultInfo].files.to_list():
    #             if file.extension == "a":
    #                 extract_dir = ctx.actions.declare_directory("%s_%s_%d.objects" % (ctx.label.name, arch, archive_index))
    #                 archive_index += 1
    #
    #                 extract_args = ctx.actions.args()
    #                 extract_args.add("x")
    #                 extract_args.add("--output=%s" % extract_dir.path)
    #                 extract_args.add(file.path)
    #
    #                 ctx.actions.run(
    #                     mnemonic = "CudaExtractArchive",
    #                     progress_message = "Extracting CUDA archive %s" % file.short_path,
    #                     executable = ctx.executable._llvm_ar,
    #                     inputs = [file],
    #                     outputs = [extract_dir],
    #                     arguments = [extract_args],
    #                 )
    #
    #                 extracted_dirs.append((sm, extract_dir))
    #             else:
    #                 direct_files.append((sm, file))
    #
    # for sm, extract_dir in extracted_dirs:
    #     fatbin_inputs.append(extract_dir)
    #     args.add_all(
    #         [extract_dir],
    #         format_each = "--image3=kind=elf,sm=%s,file=%%s" % sm,
    #     )
    #
    # for sm, file in direct_files:
    #     fatbin_inputs.append(file)
    #     args.add("--image3=kind=elf,sm=%s,file=%s" % (sm, file.path))

    if not fatbin_inputs:
        fail("cuda_binary requires deps that produce at least one cubin file")

    ctx.actions.run(
        mnemonic = "CudaFatbin",
        progress_message = "Creating fatbin %s" % fatbin.short_path,
        executable = ctx.executable._fatbinary,
        inputs = depset(fatbin_inputs),
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
        # Keep as fallback/reference if we need archive extraction again.
        # "_llvm_ar": attr.label(
        #     default = Label("//tools:llvm-ar"),
        #     executable = True,
        #     cfg = "exec",
        # ),
    },
)
