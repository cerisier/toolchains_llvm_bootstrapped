def configure_builder_for_runtimes(builder, runtime_stage, linkmode = "static", sanitizers = True):
    # The problem is that compiler-rt and start libs can only be compiled with
    # a specific set of flags and compilation mode. It is not safe to let the user
    # interfere with them using default command line flags.
    # TODO: Expose a build setting to extend those flags.
    builder.set("copt", [])
    builder.set("cxxopt", [])
    builder.set("linkopt", [])
    builder.set("host_copt", [])
    builder.set("host_cxxopt", [])
    builder.set("host_linkopt", [])

    # We are compiling runtimes without any kind of other dependencies.
    builder.set(
        Label("//toolchain:runtime_stage"),
        runtime_stage,
    )

    # TODO(cerisier): Why constraint here ?
    builder.set(
        Label("//toolchain:source"),
        "prebuilt",
    )

    builder.set(
        Label("//runtimes:linkmode"),
        linkmode,
    )

    if sanitizers == False:
        builder.set(
            Label("//config:ubsan"),
            False,
        )
        builder.set(
            Label("//config:msan"),
            False,
        )
        builder.set(
            Label("//config:asan"),
            False,
        )
        builder.set(
            Label("//config/bootstrap:ubsan"),
            False,
        )
        builder.set(
            Label("//config/bootstrap:msan"),
            False,
        )
        builder.set(
            Label("//config/bootstrap:asan"),
            False,
        )

    return builder
