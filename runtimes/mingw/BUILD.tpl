load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")

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
    visibility = ["//visibility:public"],
)

expand_template(
    name = "gen_mingw.h.in",
    template = "mingw-w64-headers/crt/_mingw.h.in",
    substitutions = {
        "@DEFAULT_MSVCRT_VERSION@": "0xE00",
        "@DEFAULT_WIN32_WINNT@": "0xa00",
    },
    out = "mingw-w64-headers/crt/_mingw.h",
    visibility = ["//visibility:public"],
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
    visibility = ["//visibility:public"],
)
