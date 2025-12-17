load("@bazel_lib//lib:copy_file.bzl", "copy_file")
load("@bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")

# echo 'int main() {}' | bazel run //tools:clang -- -x c - -fuse-ld=lld -v --rtlib=compiler-rt -### --target=<triple> 
TRIPLE_SELECT_DICT = {
    "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": "x86_64-unknown-linux-gnu",
    "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": "aarch64-unknown-linux-gnu",
    "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64_gnu": "x86_64-unknown-linux-gnu",
    "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64_gnu": "aarch64-unknown-linux-gnu",
    "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64_musl": "x86_64-unknown-linux-musl",
    "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64_musl": "aarch64-unknown-linux-musl",
    "@toolchains_llvm_bootstrapped//platforms/config:macos_x86_64": "darwin",
    "@toolchains_llvm_bootstrapped//platforms/config:macos_aarch64": "darwin",
    "@toolchains_llvm_bootstrapped//platforms/config:windows_x86_64": "x86_64-w64-windows-gnu",
    "@toolchains_llvm_bootstrapped//platforms/config:windows_aarch64": "aarch64-w64-windows-gnu",
    "@toolchains_llvm_bootstrapped//platforms/config:none_wasm32": "wasm32-unknown-unknown",
    "@toolchains_llvm_bootstrapped//platforms/config:none_wasm64": "wasm64-unknown-unknown",
}

def copy_to_resource_directory(name, srcs, **kwargs):
    """Copies the given srcs into a resource directory layout under lib/<triple>/.

    Args:
      name: target name producing the output directory (TreeArtifact).
      srcs: dict(label -> basename). Each value is the filename to appear under lib/<triple>/.
      **kwargs: forwarded to copy_to_directory (e.g. tags, testonly, etc).
    """

    # Private staging folder inside the output-dir layout before we rewrite prefixes.
    staging_prefix = "_%s_staging" % name

    staged = []
    for src_label, out_basename in sorted(srcs.items()):
        t = "%s__staged" % (out_basename.replace(".", "_").replace("/", "_"))
        copy_file(
            name = t,
            src = src_label,
            out = "%s/%s" % (staging_prefix, out_basename),
            allow_symlink = True,
            visibility = ["//visibility:private"],
        )
        staged.append(":" + t)

    # Build a select() that rewrites "_<name>_staging/..." to "lib/<triple>/..."
    replace_prefixes_by_cfg = {}
    for cfg, triple in TRIPLE_SELECT_DICT.items():
        replace_prefixes_by_cfg[cfg] = { staging_prefix: "lib/%s" % triple }

    # if "//conditions:default" not in replace_prefixes_by_cfg:
    #     replace_prefixes_by_cfg["//conditions:default"] = { staging_prefix: "lib/unknown-unknown-unknown" }

    copy_to_directory(
        name = name,
        srcs = staged,
        # Keep paths relative to this package (default behavior is root_paths=["."]).
        root_paths = ["."],
        # Final layout rewrite step.
        replace_prefixes = select(replace_prefixes_by_cfg),
        **kwargs
    )

