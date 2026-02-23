load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

_TREE_ROOT_TOKEN = "__LLVM_LINKER_TREE__"

MACOS_AARCH64_CONSTRAINTS = [
    "@platforms//os:macos",
    "@platforms//cpu:aarch64",
]

LINUX_X86_64_CONSTRAINTS = [
    "@platforms//os:linux",
    "@platforms//cpu:x86_64",
]

LINUX_AARCH64_CONSTRAINTS = [
    "@platforms//os:linux",
    "@platforms//cpu:aarch64",
]

def _normalize_subpath(path):
    if path.startswith("/"):
        fail("tree input destination must be a relative path, got: %s" % path)
    parts = [part for part in path.split("/") if part]
    if not parts:
        fail("tree input destination cannot be empty")
    for part in parts:
        if part == "." or part == "..":
            fail("tree input destination must not contain '.' or '..': %s" % path)
    return "/".join(parts)

def _rewrite_arg(arg, prefix_rewrites, suffix_rewrites):
    value = arg

    for prefix in ["--sysroot=", "-L", "-B"]:
        if value.startswith(prefix) and len(value) > len(prefix):
            rewritten = _rewrite_path(value[len(prefix):], prefix_rewrites, suffix_rewrites)
            return prefix + rewritten

    return _rewrite_path(value, prefix_rewrites, suffix_rewrites)

def _rewrite_path(path, prefix_rewrites, suffix_rewrites):
    best = None
    for source in prefix_rewrites.keys():
        if path == source or path.startswith(source + "/"):
            if best == None or len(source) > len(best):
                best = source

    if best != None:
        suffix = path[len(best):]
        return prefix_rewrites[best] + suffix

    best_suffix = None
    for suffix in suffix_rewrites.keys():
        if path == suffix or path.endswith("/" + suffix):
            if best_suffix == None or len(suffix) > len(best_suffix):
                best_suffix = suffix
    if best_suffix == None:
        return path

    path_suffix_index = path.rfind(best_suffix)
    path_prefix = path[:path_suffix_index]
    if path_prefix.endswith("/"):
        path_prefix = path_prefix[:-1]
    replacement = suffix_rewrites[best_suffix]
    if path_prefix:
        return replacement
    return replacement

def _collect_tree_inputs(ctx):
    entries = []
    prefix_rewrites = {}
    suffix_rewrites = {}
    inputs = []

    for target, destination in ctx.attr.tree_inputs.items():
        destination = _normalize_subpath(destination)
        files = target.files.to_list()
        if not files:
            fail("tree input %s does not provide files" % target.label)
        for file in files:
            out_subpath = destination
            if len(files) > 1:
                out_subpath = destination + "/" + file.basename
            entries.append((file, out_subpath))
            inputs.append(file)
            rewrite_to = _TREE_ROOT_TOKEN + "/" + out_subpath
            prefix_rewrites[file.path] = rewrite_to
            prefix_rewrites[file.short_path] = rewrite_to

            path_parts = [part for part in file.short_path.split("/") if part]
            max_parts = min(3, len(path_parts))
            for count in range(1, max_parts + 1):
                suffix = "/".join(path_parts[len(path_parts) - count:])
                suffix_rewrites[suffix] = rewrite_to

            suffix_rewrites[file.basename] = rewrite_to

    return entries, prefix_rewrites, suffix_rewrites, inputs

def _serialize_contract(arguments, environment):
    lines = ["# directive<TAB>payload"]

    for name in sorted(environment.keys()):
        lines.append("setenv\t%s\t%s" % (name, environment[name]))

    for argument in arguments:
        if argument:
            lines.append("arg\t%s" % argument)

    return "\n".join(lines) + "\n"

def _manifest_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = ctx.attr.is_linking_dynamic_library,
        runtime_library_search_directories = [],
        user_link_flags = ctx.attr.user_link_flags,
    )

    link_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = ctx.attr.action_name,
        variables = variables,
    )
    link_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = ctx.attr.action_name,
        variables = variables,
    )

    tree_entries, prefix_rewrites, suffix_rewrites, tree_inputs = _collect_tree_inputs(ctx)
    rewritten_args = [_rewrite_arg(arg, prefix_rewrites, suffix_rewrites) for arg in link_args]
    rewritten_env = {
        name: _rewrite_arg(value, prefix_rewrites, suffix_rewrites)
        for name, value in link_env.items()
    }

    _ = tree_entries
    _ = tree_inputs
    ctx.actions.write(
        output = ctx.outputs.out,
        content = _serialize_contract(rewritten_args, rewritten_env),
    )
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

linker_contract_manifest_from_cc_toolchain = rule(
    doc = "Expands cc_toolchain link args and emits a path-rewritten linker contract manifest.",
    implementation = _manifest_impl,
    attrs = {
        "out": attr.output(
            mandatory = True,
        ),
        "tree_inputs": attr.label_keyed_string_dict(
            allow_files = True,
            mandatory = True,
        ),
        "action_name": attr.string(
            default = ACTION_NAMES.cpp_link_executable,
        ),
        "is_linking_dynamic_library": attr.bool(
            default = False,
        ),
        "user_link_flags": attr.string_list(
            default = [],
        ),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def _tree_impl(ctx):
    tree_entries, _, _, tree_inputs = _collect_tree_inputs(ctx)
    out_tree = ctx.actions.declare_directory(ctx.attr.out_tree_name)

    copy_args = ctx.actions.args()
    copy_args.add(out_tree.path)
    for source, destination in tree_entries:
        copy_args.add(source.path)
        copy_args.add(destination)

    ctx.actions.run_shell(
        inputs = depset(tree_inputs),
        outputs = [out_tree],
        arguments = [copy_args],
        command = """set -euo pipefail
out_tree="$1"
shift
mkdir -p "$out_tree"
while [ "$#" -gt 0 ]; do
  src="$1"
  dest_rel="$2"
  shift 2
  dest="$out_tree/$dest_rel"
  mkdir -p "$(dirname "$dest")"
  if [ -d "$src" ]; then
    cp -RL "$src" "$dest"
  else
    cp -L "$src" "$dest"
  fi
done
""",
        mnemonic = "LinkerContractTree",
    )

    return [DefaultInfo(files = depset([out_tree]))]

linker_contract_tree = rule(
    doc = "Copies linker runtime inputs into a stable tree artifact layout.",
    implementation = _tree_impl,
    attrs = {
        "out_tree_name": attr.string(
            mandatory = True,
        ),
        "tree_inputs": attr.label_keyed_string_dict(
            allow_files = True,
            mandatory = True,
        ),
    },
)

def linker_wrapper_config_genrule(
        name,
        out,
        contract_manifest_label,
        contract_tree_label,
        target_compatible_with):
    native.genrule(
        name = name,
        outs = [out],
        cmd = "\n".join([
            "cat > $@ <<'CONFIG'",
            "#include \"tools/internal/linker_wrapper_config.h\"",
            "",
            "namespace llvm_toolchain {",
            "",
            "const char* kLinkerWrapperClangRlocation = \"$(rlocationpath //tools:clang++)\";",
            "const char* kLinkerWrapperContractManifestRlocation = \"$(rlocationpath %s)\";" % contract_manifest_label,
            "const char* kLinkerWrapperContractTreeRlocation = \"$(rlocationpath %s)\";" % contract_tree_label,
            "",
            "}  // namespace llvm_toolchain",
            "CONFIG",
        ]),
        tools = [
            "//tools:clang++",
            contract_manifest_label,
            contract_tree_label,
        ],
        target_compatible_with = target_compatible_with,
    )
