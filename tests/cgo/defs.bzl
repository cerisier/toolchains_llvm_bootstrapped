load("@rules_go//go:def.bzl", "go_binary")
load("@with_cfg.bzl", "with_cfg")

force_pic_go_binary, _force_pic_go_binary_internal = with_cfg(
    go_binary,
    executable = True,
).set(
    "force_pic",
    True,
).build()
