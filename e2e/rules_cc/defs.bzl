load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@with_cfg.bzl", "with_cfg")

_EXTERNAL_INCLUDE_PATHS_GLIBC_PLATFORM = select({
    "@platforms//cpu:aarch64": [Label("@llvm//platforms:linux_aarch64_gnu.2.34")],
    "@platforms//cpu:x86_64": [Label("@llvm//platforms:linux_x86_64_gnu.2.34")],
    "//conditions:default": [],
})

def _external_include_paths_glibc_headers_test_impl(ctx):
    for header in ctx.attr.glibc_start[CcInfo].compilation_context.direct_headers:
        if header.owner.name == "bits/errno.h":
            fail("{} declares bits/errno.h in hdrs".format(ctx.attr.glibc_start.label))

    executable = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(executable, "#!/usr/bin/env bash\n", is_executable = True)
    return [DefaultInfo(executable = executable)]

external_include_paths_glibc_headers_test = rule(
    implementation = _external_include_paths_glibc_headers_test_impl,
    attrs = {
        "glibc_start": attr.label(
            mandatory = True,
            providers = [CcInfo],
        ),
    },
    test = True,
)

external_include_paths_glibc_alias, _external_include_paths_glibc_alias_internal = with_cfg(
    native.alias,
    extra_providers = [CcInfo],
).set(
    "platforms",
    _EXTERNAL_INCLUDE_PATHS_GLIBC_PLATFORM,
).extend(
    "features",
    ["external_include_paths"],
).extend(
    "host_features",
    ["external_include_paths"],
).build()

ubsan_cc_binary, _ubsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:ubsan"),
    True,
).set(
    Label("@llvm//config:host_ubsan"),
    True,
).build()

cfi_cc_binary, _cfi_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:cfi"),
    True,
).set(
    Label("@llvm//config:host_cfi"),
    True,
).build()

msan_cc_binary, _msan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:msan"),
    True,
).set(
    Label("@llvm//config:host_msan"),
    True,
).build()

dfsan_cc_binary, _dfsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:dfsan"),
    True,
).set(
    Label("@llvm//config:host_dfsan"),
    True,
).build()

fission_cc_binary, _fission_cc_binary_internal = with_cfg(cc_binary).set(
    "compilation_mode",
    "dbg",
).set(
    "fission",
    ["dbg"],
).build()

nsan_cc_binary, _nsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:nsan"),
    True,
).set(
    Label("@llvm//config:host_nsan"),
    True,
).build()

safestack_cc_binary, _safestack_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:safestack"),
    True,
).set(
    Label("@llvm//config:host_safestack"),
    True,
).build()

rtsan_cc_binary, _rtsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:rtsan"),
    True,
).set(
    Label("@llvm//config:host_rtsan"),
    True,
).build()

tysan_cc_binary, _tysan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:tysan"),
    True,
).set(
    Label("@llvm//config:host_tysan"),
    True,
).build()

tsan_cc_binary, _tsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:tsan"),
    True,
).set(
    Label("@llvm//config:host_tsan"),
    True,
).build()

asan_cc_binary, _asan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:asan"),
    True,
).set(
    Label("@llvm//config:host_asan"),
    True,
).build()

lsan_cc_binary, _lsan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:lsan"),
    True,
).set(
    Label("@llvm//config:host_lsan"),
    True,
).build()

xray_cc_binary, _xray_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:xray"),
    True,
).set(
    Label("@llvm//config:host_xray"),
    True,
).build()

fuzzer_cc_binary, _fuzzer_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:fuzzer"),
    True,
).set(
    Label("@llvm//config:ubsan"),
    True,
).set(
    Label("@llvm//config:host_fuzzer"),
    True,
).set(
    Label("@llvm//config:host_ubsan"),
    True,
).build()

fuzzer_asan_cc_binary, _fuzzer_asan_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:fuzzer"),
    True,
).set(
    Label("@llvm//config:host_fuzzer"),
    True,
).set(
    Label("@llvm//config:asan"),
    True,
).set(
    Label("@llvm//config:host_asan"),
    True,
).build()

profile_cc_binary, _profile_cc_binary_internal = with_cfg(cc_binary).set(
    Label("@llvm//config:profile"),
    True,
).set(
    Label("@llvm//config:host_profile"),
    True,
).set(
    Label("@llvm//config:safestack"),
    select({
        "@platforms//os:linux": True,
        "//conditions:default": False,
    }),
).set(
    Label("@llvm//config:host_safestack"),
    select({
        "@platforms//os:linux": True,
        "//conditions:default": False,
    }),
).build()

opt_binary, _opt_binary_internal = with_cfg(cc_binary).set(
    "compilation_mode",
    "opt",
).build()
