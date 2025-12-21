load("@bazel_lib//lib:run_binary.bzl", "run_binary")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

def sh_script(name, cmd, **kwargs):
    write_file(
        name = name + "_sh",
        out = name + ".sh",
        content = [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            cmd,
        ],
    )

    sh_binary(
        name = name + "_bin",
        srcs = [name + ".sh"],
    )

    run_binary(
        name = name,
        tool = name + "_bin",
        **kwargs
    )

