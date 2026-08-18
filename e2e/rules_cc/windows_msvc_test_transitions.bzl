"""Target-platform and CRT transitions for native Windows MSVC tests."""

load("@bazel_skylib//lib:paths.bzl", "paths")

def _windows_msvc_test_transition_impl(settings, attr):
    features = [
        feature
        for feature in settings["//command_line_option:features"]
        if feature not in [
            "-dynamic_link_msvcrt",
            "-static_link_msvcrt",
            "dynamic_link_msvcrt",
            "static_link_msvcrt",
        ]
    ]
    if attr.static_crt:
        features.extend(["-dynamic_link_msvcrt", "static_link_msvcrt"])
    else:
        features.extend(["-static_link_msvcrt", "dynamic_link_msvcrt"])
    return {
        "//command_line_option:compilation_mode": "dbg" if attr.debug else settings["//command_line_option:compilation_mode"],
        "//command_line_option:features": features,
        "//command_line_option:platforms": str(attr.target_platform),
    }

_windows_msvc_test_transition = transition(
    implementation = _windows_msvc_test_transition_impl,
    inputs = [
        "//command_line_option:compilation_mode",
        "//command_line_option:features",
    ],
    outputs = [
        "//command_line_option:compilation_mode",
        "//command_line_option:features",
        "//command_line_option:platforms",
    ],
)

def _windows_msvc_artifacts_impl(ctx):
    output_group_files = []
    for target in ctx.attr.targets:
        if OutputGroupInfo not in target:
            continue
        output_groups = target[OutputGroupInfo]
        output_group_files.extend([
            getattr(output_groups, name, depset())
            for name in ctx.attr.output_groups
        ])
    return [DefaultInfo(
        files = depset(transitive = [
            target[DefaultInfo].files
            for target in ctx.attr.targets
        ] + [
            target[DefaultInfo].default_runfiles.files
            for target in ctx.attr.targets
        ] + output_group_files),
        runfiles = ctx.runfiles().merge_all([
            target[DefaultInfo].default_runfiles
            for target in ctx.attr.targets
        ]),
    )]

windows_msvc_artifacts = rule(
    implementation = _windows_msvc_artifacts_impl,
    attrs = {
        "debug": attr.bool(),
        "output_groups": attr.string_list(),
        "static_crt": attr.bool(),
        "targets": attr.label_list(
            allow_empty = False,
            cfg = _windows_msvc_test_transition,
        ),
        "target_platform": attr.label(mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _windows_msvc_test_impl(ctx):
    target = ctx.attr.target
    default_info = target[DefaultInfo]
    executable = default_info.files_to_run.executable
    if not executable:
        fail("windows_msvc_test target must be executable")

    forwarded_executable = ctx.actions.declare_file(paths.join(
        ctx.label.name,
        executable.basename,
    ))
    ctx.actions.symlink(
        output = forwarded_executable,
        target_file = executable,
        is_executable = True,
    )

    forwarded_files = [forwarded_executable]
    if OutputGroupInfo in target:
        runtime_libraries = getattr(
            target[OutputGroupInfo],
            "runtime_dynamic_libraries",
            depset(),
        ).to_list()
        for runtime_library in runtime_libraries:
            forwarded_library = ctx.actions.declare_file(paths.join(
                ctx.label.name,
                runtime_library.basename,
            ))
            ctx.actions.symlink(
                output = forwarded_library,
                target_file = runtime_library,
            )
            forwarded_files.append(forwarded_library)

    result = [DefaultInfo(
        executable = forwarded_executable,
        files = depset(
            direct = forwarded_files,
            transitive = [default_info.files],
        ),
        runfiles = default_info.default_runfiles.merge(
            ctx.runfiles(forwarded_files),
        ),
    )]
    if RunEnvironmentInfo in target:
        result.append(target[RunEnvironmentInfo])
    return result

windows_msvc_test = rule(
    implementation = _windows_msvc_test_impl,
    attrs = {
        "debug": attr.bool(),
        "static_crt": attr.bool(),
        "target": attr.label(
            allow_single_file = True,
            cfg = "target",
            executable = True,
            mandatory = True,
        ),
        "target_platform": attr.label(mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    cfg = _windows_msvc_test_transition,
    test = True,
)

def _windows_msvc_runtime_optimization_transition_impl(_settings, attr):
    return {
        "//command_line_option:compilation_mode": "opt" if attr.runtime_debug else "dbg",
        "//command_line_option:platforms": str(attr.target_platform),
        "@llvm//config:runtimes_optimization_mode": "debug" if attr.runtime_debug else "optimized",
        "@llvm//toolchain:runtime_stage": "stage0",
    }

_windows_msvc_runtime_optimization_transition = transition(
    implementation = _windows_msvc_runtime_optimization_transition_impl,
    inputs = [],
    outputs = [
        "//command_line_option:compilation_mode",
        "//command_line_option:platforms",
        "@llvm//config:runtimes_optimization_mode",
        "@llvm//toolchain:runtime_stage",
    ],
)

def _windows_msvc_runtime_optimization_probe_impl(ctx):
    if len(ctx.attr.target) != 1:
        fail("runtime optimization transition must produce exactly one target")
    return [ctx.attr.target[0][DefaultInfo]]

windows_msvc_runtime_optimization_probe = rule(
    implementation = _windows_msvc_runtime_optimization_probe_impl,
    attrs = {
        "runtime_debug": attr.bool(),
        "target": attr.label(
            cfg = _windows_msvc_runtime_optimization_transition,
            mandatory = True,
        ),
        "target_platform": attr.label(mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)
