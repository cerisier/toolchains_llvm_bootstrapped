"""Implementation of the cc_sysroot macro."""

load("@rules_cc//cc/toolchains:args.bzl", "cc_args")

_DEFAULT_SYSROOT_ACTIONS = [
    Label("@rules_cc//cc/toolchains/actions:assembly_actions"),
    Label("@rules_cc//cc/toolchains/actions:c_compile"),
    Label("@rules_cc//cc/toolchains/actions:objc_compile"),
    Label("@rules_cc//cc/toolchains/actions:cpp_compile_actions"),
    Label("@rules_cc//cc/toolchains/actions:link_actions"),
]

def cc_sysroot(*, name, sysroot, actions = _DEFAULT_SYSROOT_ACTIONS, args = [], **kwargs):
    """Creates args for a sysroot.

    Args:
      name: (str) The name of the target
      sysroot: (bazel_skylib's directory rule) The directory that should be the
        sysroot.
      actions: (List[Label]) Actions the `--sysroot` flag should be applied to.
      args: (List[str]) Extra command-line args to add.
      **kwargs: kwargs to pass to cc_args.
    """
    cc_args(
        name = name,
        actions = actions,
        args = ["--sysroot={sysroot}"] + args,
        format = {"sysroot": sysroot},
        **kwargs
    )
