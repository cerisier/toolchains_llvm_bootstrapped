"""Tests for the frozen Layer 1 MSVC configuration matrix."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":validation.bzl", "validate_msvc_configuration")

def _validate(**kwargs):
    defaults = {
        "disabled_features": [],
        "enabled_features": ["dynamic_link_msvcrt"],
        "is_legacy_msvcrt": False,
        "is_libcxx": True,
        "is_msvc_abi": True,
        "unsupported_features": ["asan", "fission", "thin_lto", "ubsan"],
    }
    defaults.update(kwargs)
    return validate_msvc_configuration(**defaults)

def _validation_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, None, _validate())
    asserts.equals(env, None, _validate(
        enabled_features = ["static_link_msvcrt"],
        disabled_features = ["dynamic_link_msvcrt"],
    ))
    asserts.equals(env, None, _validate(
        is_msvc_abi = False,
        is_legacy_msvcrt = True,
        is_libcxx = False,
    ))
    asserts.equals(
        env,
        "MSVC ABI requires //constraints/windows/crt:ucrt; legacy msvcrt is MinGW-only",
        _validate(is_legacy_msvcrt = True),
    )
    asserts.equals(
        env,
        "Layer 1 MSVC ABI requires //constraints/cxxstdlib:libcxx",
        _validate(is_libcxx = False),
    )
    asserts.equals(
        env,
        "MSVC ABI requires exactly one retail CRT mode: enable dynamic_link_msvcrt or static_link_msvcrt",
        _validate(
            enabled_features = [],
            disabled_features = ["dynamic_link_msvcrt"],
        ),
    )
    asserts.equals(
        env,
        "MSVC ABI Layer 1 does not support feature(s): asan, thin_lto",
        _validate(enabled_features = ["thin_lto", "dynamic_link_msvcrt", "asan"]),
    )
    asserts.equals(
        env,
        "MSVC ABI Layer 1 does not support feature(s): asan, ubsan",
        _validate(enabled_build_settings = ["ubsan", "asan"]),
    )
    return unittest.end(env)

validation_test = unittest.make(_validation_test_impl)
