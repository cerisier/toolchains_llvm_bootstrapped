load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")
load(
    "@toolchains_llvm_bootstrapped//runtimes/mingw:crt_sources.bzl",
    "MINGW32_HDRS",
    "MINGW32_SRCS",
    "MINGW32_X86_EXTRA_SRCS",
    "MINGWEX_HDRS",
    "MINGWEX_SRCS",
    "MINGWEX_TEXTUAL_SRCS",
    "MINGWEX_X86_HDRS",
    "MINGWEX_X86_SRCS",
    "MINGWEX_ARM64_SRCS",
    "UUID_SRCS",
    "UCRT_BASE_SRCS",
    "UCRT_BASE_X86_64_ADDITIONAL_SRCS",
)

package(default_visibility = ["//visibility:public"])

write_file(
    name = "libm_dummy_source",
    out = "mingw-w64-crt/_libm_dummy.c",
    content = [
        "static int __attribute__((unused)) __mingw_libm_dummy;",
    ],
)

filegroup(
    name = "mingw32_crt_textual_hdrs",
    srcs = ["mingw-w64-crt/%s" % path for path in MINGW32_HDRS],
)

filegroup(
    name = "mingw32_crt_x86_64_srcs",
    srcs = ["mingw-w64-crt/%s" % path for path in MINGW32_SRCS + MINGW32_X86_EXTRA_SRCS],
)

filegroup(
    name = "mingw32_crt_aarch64_srcs",
    srcs = ["mingw-w64-crt/%s" % path for path in MINGW32_SRCS],
)

filegroup(
    name = "mingwex_crt_base_textual_hdrs",
    srcs = ["mingw-w64-crt/%s" % path for path in MINGWEX_HDRS + MINGWEX_TEXTUAL_SRCS],
)

filegroup(
    name = "mingwex_crt_x86_64_textual_hdrs",
    srcs = [":mingwex_crt_base_textual_hdrs"] + ["mingw-w64-crt/%s" % path for path in MINGWEX_X86_HDRS],
)

filegroup(
    name = "mingwex_crt_aarch64_textual_hdrs",
    srcs = [":mingwex_crt_base_textual_hdrs"],
)

filegroup(
    name = "mingwex_crt_x86_64_srcs",
    srcs = ["mingw-w64-crt/%s" % path for path in MINGWEX_SRCS + MINGWEX_X86_SRCS],
)

filegroup(
    name = "mingwex_crt_aarch64_srcs",
    srcs = ["mingw-w64-crt/%s" % path for path in MINGWEX_SRCS + MINGWEX_ARM64_SRCS],
)

filegroup(
    name = "ucrt_base_crt_x86_64_srcs",
    srcs = ["mingw-w64-crt/%s" % path for path in UCRT_BASE_SRCS + UCRT_BASE_X86_64_ADDITIONAL_SRCS],
)

filegroup(
    name = "ucrt_base_crt_aarch64_srcs",
    srcs = ["mingw-w64-crt/%s" % path for path in UCRT_BASE_SRCS],
)

filegroup(
    name = "moldname_crt_srcs",
    srcs = [":libm_dummy_source"],
)

filegroup(
    name = "mingw_uuid_srcs",
    srcs = ["mingw-w64-crt/%s" % path for path in UUID_SRCS],
)

cc_stage2_library(
    name = "mingw_headers",
    hdrs = glob([
        "mingw-w64-headers/include/**",
        "mingw-w64-headers/crt/**",
    ]) + [
        "mingw-w64-headers/crt/_mingw.h",
        "mingw-w64-headers/crt/sdks/_mingw_ddk.h",
    ],
    includes = [
        "mingw-w64-headers/include",
        "mingw-w64-headers/crt",
    ],
)

cc_stage2_library(
    name = "mingw_crt_headers",
    hdrs = glob([
        "mingw-w64-crt/include/**",
    ]),
    includes = [
        "mingw-w64-crt/include",
    ],
)

expand_template(
    name = "gen_mingw.h.in",
    template = "mingw-w64-headers/crt/_mingw.h.in",
    substitutions = {
        "@DEFAULT_MSVCRT_VERSION@": "0xE00",
        "@DEFAULT_WIN32_WINNT@": "0xa00",
    },
    out = "mingw-w64-headers/crt/_mingw.h",
)

write_file(
    name = "gen_mingw_ddk.h",
    out = "mingw-w64-headers/crt/sdks/_mingw_ddk.h",
    content = [
        "#ifndef _MINGW_DDK_H_",
        "#define _MINGW_DDK_H_",
        "",
        "#endif /* _MINGW_DDK_H_ */",
    ],
)
