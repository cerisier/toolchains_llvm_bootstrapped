load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_static_library.bzl", "cc_stage2_static_library")
load("@toolchains_llvm_bootstrapped//third_party/llvm-project/20.x/compiler-rt:targets.bzl", "atomic_helper_cc_library")
load("@toolchains_llvm_bootstrapped//third_party/llvm-project/20.x/compiler-rt:darwin_excludes.bzl", "filter_excludes")
load("@toolchains_llvm_bootstrapped//third_party/llvm-project/20.x/compiler-rt:filter_builtin_sources.bzl", "filter_builtin_sources")
load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

BUILTINS_GENERIC_SRCS = [
    "lib/builtins/absvdi2.c",
    "lib/builtins/absvsi2.c",
    "lib/builtins/absvti2.c",
    "lib/builtins/adddf3.c",
    "lib/builtins/addsf3.c",
    "lib/builtins/addvdi3.c",
    "lib/builtins/addvsi3.c",
    "lib/builtins/addvti3.c",
    "lib/builtins/apple_versioning.c",
    "lib/builtins/ashldi3.c",
    "lib/builtins/ashlti3.c",
    "lib/builtins/ashrdi3.c",
    "lib/builtins/ashrti3.c",
    "lib/builtins/bswapdi2.c",
    "lib/builtins/bswapsi2.c",
    "lib/builtins/clzdi2.c",
    "lib/builtins/clzsi2.c",
    "lib/builtins/clzti2.c",
    "lib/builtins/cmpdi2.c",
    "lib/builtins/cmpti2.c",
    "lib/builtins/comparedf2.c",
    "lib/builtins/comparesf2.c",
    "lib/builtins/ctzdi2.c",
    "lib/builtins/ctzsi2.c",
    "lib/builtins/ctzti2.c",
    "lib/builtins/divdc3.c",
    "lib/builtins/divdf3.c",
    "lib/builtins/divdi3.c",
    "lib/builtins/divmoddi4.c",
    "lib/builtins/divmodsi4.c",
    "lib/builtins/divmodti4.c",
    "lib/builtins/divsc3.c",
    "lib/builtins/divsf3.c",
    "lib/builtins/divsi3.c",
    "lib/builtins/divti3.c",
    "lib/builtins/extendsfdf2.c",
    "lib/builtins/extendhfsf2.c",
    "lib/builtins/ffsdi2.c",
    "lib/builtins/ffssi2.c",
    "lib/builtins/ffsti2.c",
    "lib/builtins/fixdfdi.c",
    "lib/builtins/fixdfsi.c",
    "lib/builtins/fixdfti.c",
    "lib/builtins/fixsfdi.c",
    "lib/builtins/fixsfsi.c",
    "lib/builtins/fixsfti.c",
    "lib/builtins/fixunsdfdi.c",
    "lib/builtins/fixunsdfsi.c",
    "lib/builtins/fixunsdfti.c",
    "lib/builtins/fixunssfdi.c",
    "lib/builtins/fixunssfsi.c",
    "lib/builtins/fixunssfti.c",
    "lib/builtins/floatdidf.c",
    "lib/builtins/floatdisf.c",
    "lib/builtins/floatsidf.c",
    "lib/builtins/floatsisf.c",
    "lib/builtins/floattidf.c",
    "lib/builtins/floattisf.c",
    "lib/builtins/floatundidf.c",
    "lib/builtins/floatundisf.c",
    "lib/builtins/floatunsidf.c",
    "lib/builtins/floatunsisf.c",
    "lib/builtins/floatuntidf.c",
    "lib/builtins/floatuntisf.c",
    # Generatedby :generic_fp_mode.c
    "lib/builtins/generic_fp_mode.c",
    "lib/builtins/int_util.c",
    "lib/builtins/lshrdi3.c",
    "lib/builtins/lshrti3.c",
    "lib/builtins/moddi3.c",
    "lib/builtins/modsi3.c",
    "lib/builtins/modti3.c",
    "lib/builtins/muldc3.c",
    "lib/builtins/muldf3.c",
    "lib/builtins/muldi3.c",
    "lib/builtins/mulodi4.c",
    "lib/builtins/mulosi4.c",
    "lib/builtins/muloti4.c",
    "lib/builtins/mulsc3.c",
    "lib/builtins/mulsf3.c",
    "lib/builtins/multi3.c",
    "lib/builtins/mulvdi3.c",
    "lib/builtins/mulvsi3.c",
    "lib/builtins/mulvti3.c",
    "lib/builtins/negdf2.c",
    "lib/builtins/negdi2.c",
    "lib/builtins/negsf2.c",
    "lib/builtins/negti2.c",
    "lib/builtins/negvdi2.c",
    "lib/builtins/negvsi2.c",
    "lib/builtins/negvti2.c",
    "lib/builtins/os_version_check.c",
    "lib/builtins/paritydi2.c",
    "lib/builtins/paritysi2.c",
    "lib/builtins/parityti2.c",
    "lib/builtins/popcountdi2.c",
    "lib/builtins/popcountsi2.c",
    "lib/builtins/popcountti2.c",
    "lib/builtins/powidf2.c",
    "lib/builtins/powisf2.c",
    "lib/builtins/subdf3.c",
    "lib/builtins/subsf3.c",
    "lib/builtins/subvdi3.c",
    "lib/builtins/subvsi3.c",
    "lib/builtins/subvti3.c",
    "lib/builtins/trampoline_setup.c",
    "lib/builtins/truncdfhf2.c",
    "lib/builtins/truncdfsf2.c",
    "lib/builtins/truncsfhf2.c",
    "lib/builtins/ucmpdi2.c",
    "lib/builtins/ucmpti2.c",
    "lib/builtins/udivdi3.c",
    "lib/builtins/udivmoddi4.c",
    "lib/builtins/udivmodsi4.c",
    "lib/builtins/udivmodti4.c",
    "lib/builtins/udivsi3.c",
    "lib/builtins/udivti3.c",
    "lib/builtins/umoddi3.c",
    "lib/builtins/umodsi3.c",
    "lib/builtins/umodti3.c",

    # Not Fuchsia and not a bare-metal build.
    "lib/builtins/emutls.c",
    "lib/builtins/enable_execute_stack.c",
    "lib/builtins/eprintf.c",

    # Not sure whether we want atomic in this or separately.
    "lib/builtins/atomic.c",

    # Needed by libunwind for C++ with exceptions.
    "lib/builtins/gcc_personality_v0.c",

    # Not Fuchsia.
    "lib/builtins/clear_cache.c",
]

BF16_SOURCES = [
    "lib/builtins/extendbfsf2.c",
    "lib/builtins/truncdfbf2.c",
    "lib/builtins/truncxfbf2.c",
    "lib/builtins/truncsfbf2.c",
    "lib/builtins/trunctfbf2.c",
]

# Triple float sources
BUILTINS_GENERIC_TF_SRCS = [
    "lib/builtins/addtf3.c",
    "lib/builtins/comparetf2.c",
    "lib/builtins/divtc3.c",
    "lib/builtins/divtf3.c",
    "lib/builtins/extenddftf2.c",
    "lib/builtins/extendhftf2.c",
    "lib/builtins/extendsftf2.c",
    "lib/builtins/fixtfdi.c",
    "lib/builtins/fixtfsi.c",
    "lib/builtins/fixtfti.c",
    "lib/builtins/fixunstfdi.c",
    "lib/builtins/fixunstfsi.c",
    "lib/builtins/fixunstfti.c",
    "lib/builtins/floatditf.c",
    "lib/builtins/floatsitf.c",
    "lib/builtins/floattitf.c",
    "lib/builtins/floatunditf.c",
    "lib/builtins/floatunsitf.c",
    "lib/builtins/floatuntitf.c",
    "lib/builtins/multc3.c",
    "lib/builtins/multf3.c",
    "lib/builtins/powitf2.c",
    "lib/builtins/subtf3.c",
    "lib/builtins/trunctfdf2.c",
    "lib/builtins/trunctfhf2.c",
    "lib/builtins/trunctfsf2.c",
]

# Avoid duplicate filename warning because of arch specific fp_mode.c
copy_file(
    name = "generic_fpmode.c",
    src = "lib/builtins/fp_mode.c",
    out = "lib/builtins/generic_fp_mode.c",
    allow_symlink = True,
)

# buildifier: disable=constant-glob
filegroup(
    name = "builtins_generic_srcs",
    srcs = filter_excludes(BUILTINS_GENERIC_SRCS) + select({
        "@platforms//os:macos": [
            "lib/builtins/atomic_flag_clear.c",
            "lib/builtins/atomic_flag_clear_explicit.c",
            "lib/builtins/atomic_flag_test_and_set.c",
            "lib/builtins/atomic_flag_test_and_set_explicit.c",
            "lib/builtins/atomic_signal_fence.c",
            "lib/builtins/atomic_thread_fence.c",
        ],
        "//conditions:default": [],
    }),
)

filegroup(
    name = "builtins_bf16_sources",
    srcs = filter_excludes(BF16_SOURCES),
)

filegroup(
    name = "builtins_generic_tf_sources",
    srcs = filter_excludes(BUILTINS_GENERIC_TF_SRCS),
)

filegroup(
    name = "builtins_x86_arch_sources",
    srcs = [
        "lib/builtins/cpu_model/x86.c",
        "lib/builtins/i386/fp_mode.c", #if (NOT MSVC)
    ],
)

filegroup(
    name = "builtins_x86_80_bit_sources",
    srcs = filter_excludes([
        "lib/builtins/divxc3.c",
        "lib/builtins/fixxfdi.c",
        "lib/builtins/fixxfti.c",
        "lib/builtins/fixunsxfdi.c",
        "lib/builtins/fixunsxfsi.c",
        "lib/builtins/fixunsxfti.c",
        "lib/builtins/floatdixf.c", # if not android
        "lib/builtins/floattixf.c",
        "lib/builtins/floatundixf.c", # if not win32
        "lib/builtins/floatuntixf.c",
        "lib/builtins/mulxc3.c",
        "lib/builtins/powixf2.c",
    ]),
)

filter_builtin_sources(
    name = "builtins_x86_64_sources",
    srcs = [
        ":builtins_generic_srcs",
        ":builtins_generic_tf_sources",
        ":builtins_x86_arch_sources",
        ":builtins_x86_80_bit_sources",
    ] + filter_excludes([
        "lib/builtins/x86_64/floatdidf.c",
        "lib/builtins/x86_64/floatdisf.c",
        "lib/builtins/x86_64/floatundidf.S", # if not WIN32
        "lib/builtins/x86_64/floatundisf.S", # if not WIN32
        "lib/builtins/x86_64/floatdixf.c",  # if not ANDROID
        "lib/builtins/x86_64/floatundixf.S",  # if not ANDROID and not WIN32
        # "x86_64/chkstk.S" # if WIN32
    ]),
)

filegroup(
    name = "builtins_aarch64_arch_sources",
    srcs = [
        "lib/builtins/cpu_model/aarch64.c",
        "lib/builtins/aarch64/fp_mode.c",
    ],
)

filter_builtin_sources(
    name = "builtins_aarch64_sources",
    srcs = [
        ":builtins_generic_srcs",
        ":builtins_generic_tf_sources",
        ":builtins_aarch64_arch_sources",
        # "aarch64/chkstk.S", # if MINGW
    ],
)

builtins_aarch64_atomic_deps = [
    atomic_helper_cc_library(
        name = "builtins_atomic_helper_{}_{}_{}".format(pat, size, model),
        pat = pat,
        size = size,
        model = model,
    )
    for pat in ["cas", "swp", "ldadd", "ldclr", "ldeor", "ldset"]
    for size in [1, 2, 4, 8, 16]
    for model in [1, 2, 3, 4, 5]
    if pat == "cas" or size != 16
]

cc_stage2_library(
    name = "builtins_aarch64_atomic",
    deps = builtins_aarch64_atomic_deps,
)

cc_stage2_library(
    name = "builtins",
    includes = ["lib/builtins"],
    srcs = select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": [":builtins_x86_64_sources"],
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": [":builtins_aarch64_sources"],
        "@toolchains_llvm_bootstrapped//platforms/config:macos_aarch64": [":builtins_aarch64_sources"],
    }, no_match_error = """
        Platform not supported for compiler-rt.builtins.
        It is likely that we are just missing the filegroups for that platform.
        Please file an issue.
    """) + [
        "lib/builtins/assembly.h",
        "lib/builtins/fp_extend.h",
        "lib/builtins/fp_lib.h",
        "lib/builtins/fp_mode.h",
        "lib/builtins/fp_trunc.h",
        "lib/builtins/int_endianness.h",
        "lib/builtins/int_lib.h",
        "lib/builtins/int_math.h",
        "lib/builtins/int_to_fp.h",
        "lib/builtins/int_types.h",
        "lib/builtins/int_util.h",
    ] + select({
        "@platforms//cpu:aarch64": [
            "lib/builtins/cpu_model/aarch64.h",
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        (
            # The following additional architectures support float16:
            # - aarch64_be
            # - riscv32
            # - riscv64
            "@platforms//cpu:aarch64",
            "@platforms//cpu:x86_64",
        ): [
            ":builtins_bf16_sources",
        ],
        "//conditions:default": [],
    }),
    copts = [
        "-fno-builtin",
        "-std=c11",
        "-fvisibility=hidden",
        # "-Wbuiltin-declaration-mismatch",
    ] + select({
        "@toolchains_llvm_bootstrapped//config:stage2_optimization_mode_optimized": [
            "-fomit-frame-pointer",
        ],
        "//conditions:default": [],
    }),
    local_defines = selects.with_or({
        (
            # The following additional architectures support float16:
            # - aarch64_be
            # - arm
            # - armeb
            # - hexagon
            # - riscv32
            # - riscv64
            # - spirv
            # - thumb
            # - thumbeb
            "@platforms//cpu:aarch64",
            "@platforms//cpu:x86_64",
        ): [
            "COMPILER_RT_HAS_FLOAT16",
        ],
        "//conditions:default": [],
    }),
    textual_hdrs = [
        "lib/builtins/fp_add_impl.inc",
        "lib/builtins/fp_compare_impl.inc",
        "lib/builtins/fp_div_impl.inc",
        "lib/builtins/fp_extend_impl.inc",
        "lib/builtins/fp_fixint_impl.inc",
        "lib/builtins/fp_fixuint_impl.inc",
        "lib/builtins/fp_mul_impl.inc",
        "lib/builtins/fp_trunc_impl.inc",
        "lib/builtins/int_div_impl.inc",
        "lib/builtins/int_mulo_impl.inc",
        "lib/builtins/int_mulv_impl.inc",
        "lib/builtins/int_to_fp_impl.inc",
        "lib/builtins/cpu_model/cpu_model.h",
    ] + select({
        "@platforms//cpu:aarch64": [
            "lib/builtins/cpu_model/AArch64CPUFeatures.inc",
            "lib/builtins/cpu_model/aarch64/hwcap.inc",
            # "lib/builtins/cpu_model/aarch64/lse_atomics/atomic_helper.inc",
            "lib/builtins/cpu_model/aarch64/lse_atomics/getauxval.inc",
        ],
        "//conditions:default": [],
    }) + select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": [
            "lib/builtins/cpu_model/aarch64/fmv/mrs.inc",
            "lib/builtins/cpu_model/aarch64/fmv/getauxval.inc",
        ],
        "@toolchains_llvm_bootstrapped//platforms/config:macos_aarch64": [
            "lib/builtins/cpu_model/aarch64/fmv/apple.inc",
        ],
        "//conditions:default": [],
    }),
    features = ["-default_compile_flags"],
    linkstatic = True,
    deps = select({
        "@platforms//cpu:aarch64": [
            ":builtins_aarch64_atomic",
        ],
        "//conditions:default": [],
    }),
    implementation_deps = select({
        "@platforms//os:macos": [],
        "@platforms//os:linux": [
            "@kernel_headers//:kernel_headers",
        ],
    }) + select({
        "@toolchains_llvm_bootstrapped//constraints/libc:musl": [
            "@musl_libc//:musl_libc_headers",
        ],
        "@platforms//os:macos": [
            # on macOS we implicitly use SDK provided headers
        ],
        "//conditions:default": [
            "@glibc//:gnu_libc_headers",
        ],
    }),
)

cc_stage2_static_library(
    name = "clang_rt.builtins.static",
    deps = [
        ":builtins",
    ],
    visibility = ["//visibility:public"],
)

CRT_CFLAGS = [
    "-std=c11",
    "-fPIC",
]

CRT_DEFINES = [
    "CRT_HAS_INITFINI_ARRAY",
    "CRT_USE_FRAME_REGISTRY",
]

cc_stage2_library(
    name = "clang_rt.crtbegin",
    srcs = [
        "lib/builtins/crtbegin.c",
    ],
    copts = CRT_CFLAGS,
    local_defines = CRT_DEFINES,
    visibility = ["//visibility:public"],
)

cc_stage2_static_library(
    name = "clang_rt.crtbegin.static",
    deps = [
        ":clang_rt.crtbegin",
    ],
    visibility = ["//visibility:public"],
)

cc_stage2_library(
    name = "clang_rt.crtend",
    srcs = [
        "lib/builtins/crtend.c",
    ],
    copts = CRT_CFLAGS,
    local_defines = CRT_DEFINES,
    visibility = ["//visibility:public"],
)

cc_stage2_static_library(
    name = "clang_rt.crtend.static",
    deps = [
        ":clang_rt.crtend",
    ],
    visibility = ["//visibility:public"],
)
