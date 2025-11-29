def _bootstrap_transition_impl(settings, attr):
    return {
        "//toolchain:bootstrap_setting": False,
        "//toolchain:stage1_bootstrap_setting": True,
        # Some flags to make LLVM build sanely.
        "@llvm_zlib//:llvm_enable_zlib": False,
        "@rules_python//python/config_settings:bootstrap_impl": "script",
    }

bootstrap_transition = transition(
    implementation = _bootstrap_transition_impl,
    inputs = [],
    outputs = [
        "//toolchain:bootstrap_setting",
        "//toolchain:stage1_bootstrap_setting",
        "@llvm_zlib//:llvm_enable_zlib",
        "@rules_python//python/config_settings:bootstrap_impl",
    ],
)

def _stage1_binary_impl(ctx):
    actual = ctx.attr.actual[0][DefaultInfo]
    exe = actual.files_to_run.executable

    out = ctx.actions.declare_file(ctx.label.name)

    ctx.actions.symlink(
        target_file = exe,
        output = out,
    )

    return [
        DefaultInfo(
            files = depset([out]),
            executable = out,
            runfiles = actual.default_runfiles,
        )
    ]

stage1_binary = rule(
    implementation = _stage1_binary_impl,
    executable = True,
    attrs = {
        "actual": attr.label(
            cfg = bootstrap_transition,
            allow_single_file = True,
            mandatory = True,
        ),
    },
)

def _relative_subpath(path, prefix):
    prefix = prefix.rstrip("/")
    marker = prefix + "/"
    index = path.find(marker)
    if index == -1:
        fail("Could not find '{}' inside '{}'".format(prefix, path))
    return path[index + len(marker):]

def _stage1_directory_impl(ctx):
    actual = ctx.attr.actual[0][DefaultInfo]
    files = actual.files.to_list()

    destination = ctx.attr.destination.rstrip("/")
    if not destination:
        fail("stage1_directory.destination must not be empty")
    out = ctx.actions.declare_directory(destination)

    args = ctx.actions.args()
    args.add(out.path)
    for f in files:
        args.add(f.path)
        args.add(_relative_subpath(f.short_path, ctx.attr.strip_prefix))

    ctx.actions.run_shell(
        inputs = files,
        outputs = [out],
        command = """
set -euo pipefail
out="$1"
shift 1
rm -rf "$out"
while [ "$#" -gt 1 ]; do
  src="$1"
  rel="$2"
  shift 2
  dst="$out/$rel"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
done
if [ "$#" -ne 0 ]; then
  echo "stage1_directory received an incomplete src/rel pair" >&2
  exit 1
fi
""",
        arguments = [args],
    )

    runfiles = ctx.runfiles(files = [out])

    return [
        DefaultInfo(
            files = depset([out]),
            data_runfiles = runfiles,
            default_runfiles = runfiles,
        ),
    ]

stage1_directory = rule(
    implementation = _stage1_directory_impl,
    attrs = {
        "actual": attr.label(
            cfg = bootstrap_transition,
            mandatory = True,
        ),
        "strip_prefix": attr.string(mandatory = True),
        "destination": attr.string(mandatory = True),
    },
)
