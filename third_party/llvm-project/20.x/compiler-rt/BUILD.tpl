load("@toolchains_llvm_bootstrapped//toolchain/runtimes:cc_runtime_library.bzl", "cc_runtime_stage0_library")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:cc_runtime_static_library.bzl", "cc_runtime_stage0_static_library")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:cc_stage0_object.bzl", "cc_stage0_object")
load("@toolchains_llvm_bootstrapped//toolchain/args:llvm_target_triple.bzl", "LLVM_TARGET_TRIPLE")
load("@toolchains_llvm_bootstrapped//toolchain/runtimes:cc_unsanitized_library.bzl", "cc_unsanitized_library")
load("@toolchains_llvm_bootstrapped//third_party/llvm-project/20.x/compiler-rt:targets.bzl", "atomic_helper_cc_library")
load("@toolchains_llvm_bootstrapped//third_party/llvm-project/20.x/compiler-rt:filter_builtin_sources.bzl", "filter_builtin_sources")
load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

cc_runtime_stage0_library(
    name = "profile",
    srcs = [
        "lib/profile/GCDAProfiling.c",
        "lib/profile/InstrProfiling.c",
        "lib/profile/InstrProfilingBuffer.c",
        "lib/profile/InstrProfilingFile.c",
        "lib/profile/InstrProfilingInternal.c",
        "lib/profile/InstrProfilingMerge.c",
        "lib/profile/InstrProfilingMergeFile.c",
        "lib/profile/InstrProfilingNameVar.c",
        "lib/profile/InstrProfilingRuntime.cpp",
        "lib/profile/InstrProfilingUtil.c",
        "lib/profile/InstrProfilingValue.c",
        "lib/profile/InstrProfilingVersionVar.c",
        "lib/profile/InstrProfilingWriter.c",
    ] + select({
        "@platforms//os:windows": [
            "lib/profile/InstrProfilingPlatformWindows.c",
            "lib/profile/WindowsMMap.c",
        ],
        "@platforms//os:macos": [
            "lib/profile/InstrProfilingPlatformDarwin.c",
        ],
        "@platforms//os:linux": [
            "lib/profile/InstrProfilingPlatformLinux.c",
        ],
        "//conditions:default": [
            "lib/profile/InstrProfilingPlatformOther.c",
        ],
    }),
    hdrs = [
        "include/profile/instr_prof_interface.h",
        "include/profile/InstrProfData.inc",
        "lib/profile/InstrProfiling.h",
        "lib/profile/InstrProfilingInternal.h",
        "lib/profile/InstrProfilingPort.h",
        "lib/profile/InstrProfilingUtil.h",
        "lib/profile/WindowsMMap.h",
    ],
    includes = [
        "include",
        "lib/profile",
    ],
    implementation_deps = select({
        "@platforms//os:macos": [],
        "@platforms//os:linux": [
            # TODO(cerisier): Provide only a subset of linux UAPI headers for musl.
            # https://github.com/cerisier/toolchains_llvm_bootstrapped/issues/146
            "@kernel_headers//:kernel_headers",
        ],
        "@platforms//os:windows": [],
        "@platforms//os:none": [],
    }) + select({
        "@toolchains_llvm_bootstrapped//platforms/config:musl": [
            "@musl_libc//:musl_libc_headers",
        ],
        "@toolchains_llvm_bootstrapped//platforms/config:gnu": [
            "@glibc//:gnu_libc_headers",
        ],
        "@platforms//os:macos": [
            # on macOS we implicitly use SDK provided headers
        ],
        "@platforms//os:windows": [
            "@mingw//:mingw_headers",
        ],
        "@platforms//os:none": [],
    }),
    local_defines = [
        "COMPILER_RT_HAS_ATOMICS",
    ] + select({
        "@platforms//os:windows": [],
        "//conditions:default": [
            "COMPILER_RT_HAS_FCNTL_LCK",
            "COMPILER_RT_HAS_FLOCK",
            "COMPILER_RT_HAS_UNAME",
        ],
    }),
)

cc_runtime_stage0_static_library(
    name = "clang_rt.profile.static",
    deps = [
        ":profile",
    ],
    visibility = ["//visibility:public"],
)

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
    "lib/builtins/fp_mode.c",
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

# buildifier: disable=constant-glob
filegroup(
    name = "builtins_generic_srcs",
    srcs = BUILTINS_GENERIC_SRCS + select({
        "@platforms//os:macos": [
            "lib/builtins/atomic_flag_clear.c",
            "lib/builtins/atomic_flag_clear_explicit.c",
            "lib/builtins/atomic_flag_test_and_set.c",
            "lib/builtins/atomic_flag_test_and_set_explicit.c",
            "lib/builtins/atomic_signal_fence.c",
            "lib/builtins/atomic_thread_fence.c",
        ],
        "//conditions:default": [],
    }) + select({
        "@platforms//os:none": [],
        "//conditions:default": [
            # Not Fuchsia and not a bare-metal build.
            "lib/builtins/emutls.c",
            "lib/builtins/enable_execute_stack.c",
            "lib/builtins/eprintf.c",
        ],
    }),
)

filegroup(
    name = "builtins_bf16_sources",
    srcs = BF16_SOURCES,
)

filegroup(
    name = "builtins_generic_tf_sources",
    srcs = BUILTINS_GENERIC_TF_SRCS,
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
    srcs = [
        "lib/builtins/divxc3.c",
        "lib/builtins/fixxfdi.c",
        "lib/builtins/fixxfti.c",
        "lib/builtins/fixunsxfdi.c",
        "lib/builtins/fixunsxfsi.c",
        "lib/builtins/fixunsxfti.c",
        "lib/builtins/floatdixf.c", # if not android
        "lib/builtins/floattixf.c",
        "lib/builtins/floatundixf.c",
        "lib/builtins/floatuntixf.c",
        "lib/builtins/mulxc3.c",
        "lib/builtins/powixf2.c",
    ],
)

filter_builtin_sources(
    name = "builtins_x86_64_sources",
    srcs = [
        ":builtins_generic_srcs",
        ":builtins_generic_tf_sources",
        ":builtins_x86_arch_sources",
        ":builtins_x86_80_bit_sources",
        "lib/builtins/x86_64/floatdidf.c",
        "lib/builtins/x86_64/floatdisf.c",
        "lib/builtins/x86_64/floatdixf.c",  # if not ANDROID
    ] + select({
        "@platforms//os:windows": [
            "lib/builtins/x86_64/chkstk.S",
        ],
        "//conditions:default": [
            "lib/builtins/x86_64/floatundidf.S",
            "lib/builtins/x86_64/floatundisf.S",
            "lib/builtins/x86_64/floatundixf.S",  # if not ANDROID
        ],
    }),
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
    ] + select({
        "@platforms//os:windows": [
            "lib/builtins/aarch64/chkstk.S", # if MINGW
        ],
        "//conditions:default": [],
    }),
)

filter_builtin_sources(
    name = "builtins_wasm32_sources",
    srcs = [
        ":builtins_generic_srcs",
        ":builtins_generic_tf_sources",
    ],
)

filter_builtin_sources(
    name = "builtins_wasm64_sources",
    srcs = [
        ":builtins_generic_srcs",
        ":builtins_generic_tf_sources",
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

cc_runtime_stage0_library(
    name = "builtins_aarch64_atomic",
    deps = builtins_aarch64_atomic_deps,
)

cc_runtime_stage0_library(
    name = "builtins",
    includes = ["lib/builtins"],
    srcs = select({
        "@platforms//cpu:x86_64": [":builtins_x86_64_sources"],
        "@platforms//cpu:aarch64": [":builtins_aarch64_sources"],
        "@platforms//cpu:wasm32": [":builtins_wasm32_sources"],
        "@platforms//cpu:wasm64": [":builtins_wasm64_sources"],
    }, no_match_error = """
        Architecture not supported for compiler-rt.builtins.
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
        "@toolchains_llvm_bootstrapped//config:runtimes_optimization_mode_optimized": [
            "-fomit-frame-pointer",
        ],
        "//conditions:default": [],
    }) + select({
        "@platforms//os:macos": [
            "-Wno-deprecated-declarations",
            # TODO(zbarsky): This is spammy, but we should do a real fix.
            # "-Wno-macro-redefined",
         ],
        "@platforms//os:windows": [
            "-Wno-missing-declarations",
            "-Wno-pragma-pack",
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
        "@toolchains_llvm_bootstrapped//platforms/config:windows_aarch64": [
            "lib/builtins/cpu_model/aarch64/lse_atomics/windows.inc",
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
        "@toolchains_llvm_bootstrapped//platforms/config:windows_aarch64": [
            "lib/builtins/cpu_model/aarch64/fmv/windows.inc",
        ],
        "//conditions:default": [],
    }),
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
            # TODO(cerisier): Provide only a subset of linux UAPI headers for musl.
            # https://github.com/cerisier/toolchains_llvm_bootstrapped/issues/146
            "@kernel_headers//:kernel_headers",
        ],
        "@platforms//os:windows": [],
        "@platforms//os:none": [],
    }) + select({
        "@toolchains_llvm_bootstrapped//platforms/config:musl": [
            "@musl_libc//:musl_libc_headers",
        ],
        "@toolchains_llvm_bootstrapped//platforms/config:gnu": [
            "@glibc//:gnu_libc_headers",
        ],
        "@platforms//os:macos": [
            # on macOS we implicitly use SDK provided headers
        ],
        "@platforms//os:windows": [
            "@mingw//:mingw_headers",
        ],
        "@platforms//os:none": [],
    }),
)

cc_runtime_stage0_static_library(
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

cc_runtime_stage0_library(
    name = "clang_rt.crtbegin",
    srcs = [
        "lib/builtins/crtbegin.c",
    ],
    copts = CRT_CFLAGS,
    local_defines = CRT_DEFINES,
    visibility = ["//visibility:public"],
)

cc_stage0_object(
    name = "crtbegin_object",
    srcs = [
        ":clang_rt.crtbegin",
    ],
    copts = [
        "-target",
    ] + LLVM_TARGET_TRIPLE,
    #TODO(cerisier): Rename to clang_rt.crtbegin.o and expose this with -L.
    #
    # This is because clang driver looks for this instead of crtbegin<ST>.o
    # when --rtlib=compiler-rt is used.
    out = "crtbegin.o",
    visibility = ["//visibility:public"],
)

copy_file(
    name = "crtbeginS_object",
    src = ":crtbegin_object",
    out = "crtbeginS.o",
    allow_symlink = True,
    visibility = ["//visibility:public"],
)

copy_file(
    name = "crtbeginT_object",
    src = ":crtbegin_object",
    out = "crtbeginT.o",
    allow_symlink = True,
    visibility = ["//visibility:public"],
)

cc_runtime_stage0_static_library(
    name = "clang_rt.crtbegin.static",
    deps = [
        ":clang_rt.crtbegin",
    ],
    visibility = ["//visibility:public"],
)

cc_runtime_stage0_library(
    name = "clang_rt.crtend",
    srcs = [
        "lib/builtins/crtend.c",
    ],
    copts = CRT_CFLAGS,
    local_defines = CRT_DEFINES,
    visibility = ["//visibility:public"],
)

cc_stage0_object(
    name = "crtend_object",
    srcs = [
        ":clang_rt.crtend",
    ],
    copts = [
        "-target",
    ] + LLVM_TARGET_TRIPLE,
    #TODO(cerisier): Rename to clang_rt.crtend.o and expose this with -L.
    #
    # This is because clang driver looks for this instead of crtend<ST>.o
    # when --rtlib=compiler-rt is used.
    out = "crtend.o",
    visibility = ["//visibility:public"],
)

copy_file(
    name = "crtendS_object",
    src = ":crtend_object",
    out = "crtendS.o",
    allow_symlink = True,
    visibility = ["//visibility:public"],
)

cc_runtime_stage0_static_library(
    name = "clang_rt.crtend.static",
    deps = [
        ":clang_rt.crtend",
    ],
    visibility = ["//visibility:public"],
)

##### Sanitizers #######

# We want to reset the sanitizer configuration because LLVM builds c++ tools
# and linking those will lead to errors, as the sanitizer libs is not an linker input.
# Making it a linker input would result in cycles, and we probably don't want to rebuild
# a bunch of LLVM code for each different sanitizer configuration anyway.

# Ideally there would be a way to avoid this flag propagating to the exec configuration,
# but for now this is good enough for now.
cc_unsanitized_library(
    name = "llvm_Symbolize",
    # This is not as terrible as it looks - with the remote repo contents cache, Bazel will be able
    # to pull down a single ActionResult containing the description of the repo contents, which is enough
    # to compute AC keys and hopefully get a CAS hit on these deps. So once they're built once, they won't
    # trigger expensive fetches of llvm-project.
    dep = "@llvm-project//llvm:Symbolize",
)

# TODO(zbarsky): It would be nice to not have to jam everything into a single BUILD file
cc_runtime_stage0_library(
    name = "linux_libc_headers",
    deps = [
        # linux UAPI headers are needed even for musl here because sanitizers include <sys/vt.h>
        # TODO(cerisier): Provide only a subset of linux UAPI headers for musl.
        # https://github.com/cerisier/toolchains_llvm_bootstrapped/issues/146
        "@kernel_headers//:kernel_headers",
        # Order matter. Search path should have C++ headers before any lib C headers.
    ] + select({
        "@toolchains_llvm_bootstrapped//platforms/config:musl": [
            "@musl_libc//:musl_libc_headers",
        ],
        "@toolchains_llvm_bootstrapped//platforms/config:gnu": [
            "@glibc//:gnu_libc_headers",
        ],
    }),
)

cc_runtime_stage0_library(
    name = "libcxx_headers",
    deps = select({
        "@platforms//os:macos": [],
        "@platforms//os:linux": [
            "@libcxx//:headers",
            "@libcxxabi//:headers",
            ":linux_libc_headers",
        ],
    }),
)

## Common

SANITIZER_SOURCES_NOTERMINATION = [
  "sanitizer_allocator.cpp",
  "sanitizer_common.cpp",
  "sanitizer_deadlock_detector1.cpp",
  "sanitizer_deadlock_detector2.cpp",
  "sanitizer_errno.cpp",
  "sanitizer_file.cpp",
  "sanitizer_flags.cpp",
  "sanitizer_flag_parser.cpp",
  "sanitizer_fuchsia.cpp",
  "sanitizer_libc.cpp",
  "sanitizer_libignore.cpp",
  "sanitizer_linux.cpp",
  "sanitizer_linux_s390.cpp",
  "sanitizer_mac.cpp",
  "sanitizer_mutex.cpp",
  "sanitizer_netbsd.cpp",
  "sanitizer_platform_limits_freebsd.cpp",
  "sanitizer_platform_limits_linux.cpp",
  "sanitizer_platform_limits_netbsd.cpp",
  "sanitizer_platform_limits_posix.cpp",
  "sanitizer_platform_limits_solaris.cpp",
  "sanitizer_posix.cpp",
  "sanitizer_printf.cpp",
  "sanitizer_procmaps_common.cpp",
  "sanitizer_procmaps_bsd.cpp",
  "sanitizer_procmaps_fuchsia.cpp",
  "sanitizer_procmaps_linux.cpp",
  "sanitizer_procmaps_mac.cpp",
  "sanitizer_procmaps_solaris.cpp",
  "sanitizer_range.cpp",
  "sanitizer_solaris.cpp",
  "sanitizer_stoptheworld_fuchsia.cpp",
  "sanitizer_stoptheworld_mac.cpp",
  "sanitizer_stoptheworld_win.cpp",
  "sanitizer_suppressions.cpp",
  "sanitizer_tls_get_addr.cpp",
  "sanitizer_thread_arg_retval.cpp",
  "sanitizer_thread_registry.cpp",
  "sanitizer_type_traits.cpp",
  "sanitizer_win.cpp",
  "sanitizer_win_interception.cpp",
]

SANITIZER_SOURCES = SANITIZER_SOURCES_NOTERMINATION + [
  "sanitizer_termination.cpp",
]

filegroup(
    name = "sanitizer_sources",
    srcs = ["lib/sanitizer_common/" + f for f in SANITIZER_SOURCES],
)

# Libc functions stubs. These sources should be linked instead of
# SANITIZER_LIBCDEP_SOURCES when sanitizer_common library must not depend on
# libc.
SANITIZER_NOLIBC_SOURCES = [
  "sanitizer_common_nolibc.cpp"
]

SANITIZER_LIBCDEP_SOURCES = [
  "sanitizer_common_libcdep.cpp",
  "sanitizer_allocator_checks.cpp",
  "sanitizer_dl.cpp",
  "sanitizer_linux_libcdep.cpp",
  "sanitizer_mac_libcdep.cpp",
  "sanitizer_posix_libcdep.cpp",
  "sanitizer_stoptheworld_linux_libcdep.cpp",
  "sanitizer_stoptheworld_netbsd_libcdep.cpp",
]

filegroup(
    name = "sanitizer_libcdep_sources",
    srcs = ["lib/sanitizer_common/" + f for f in SANITIZER_LIBCDEP_SOURCES],
)

SANITIZER_COVERAGE_SOURCES = [
  "sancov_flags.cpp",
  "sanitizer_coverage_fuchsia.cpp",
  "sanitizer_coverage_libcdep_new.cpp",
  "sanitizer_coverage_win_sections.cpp",
]

filegroup(
    name = "sanitizer_coverage_sources",
    srcs = ["lib/sanitizer_common/" + f for f in SANITIZER_COVERAGE_SOURCES],
)

SANITIZER_SYMBOLIZER_SOURCES = [
  "sanitizer_allocator_report.cpp",
  "sanitizer_chained_origin_depot.cpp",
  "sanitizer_stack_store.cpp",
  "sanitizer_stackdepot.cpp",
  "sanitizer_stacktrace.cpp",
  "sanitizer_stacktrace_libcdep.cpp",
  "sanitizer_stacktrace_printer.cpp",
  "sanitizer_stacktrace_sparc.cpp",
  "sanitizer_symbolizer.cpp",
  "sanitizer_symbolizer_libbacktrace.cpp",
  "sanitizer_symbolizer_libcdep.cpp",
  "sanitizer_symbolizer_mac.cpp",
  "sanitizer_symbolizer_markup.cpp",
  "sanitizer_symbolizer_markup_fuchsia.cpp",
  "sanitizer_symbolizer_posix_libcdep.cpp",
  "sanitizer_symbolizer_report.cpp",
  "sanitizer_symbolizer_report_fuchsia.cpp",
  "sanitizer_symbolizer_win.cpp",
  "sanitizer_thread_history.cpp",
  "sanitizer_unwind_linux_libcdep.cpp",
  "sanitizer_unwind_fuchsia.cpp",
  "sanitizer_unwind_win.cpp",
]

filegroup(
    name = "sanitizer_symbolizer_sources",
    srcs = ["lib/sanitizer_common/" + f for f in SANITIZER_SYMBOLIZER_SOURCES],
)

# Explicitly list all sanitizer_common headers. Not all of these are
# included in sanitizer_common source files, but we need to depend on
# headers when building our custom unit tests.
SANITIZER_IMPL_HEADERS = [
  "sancov_flags.h",
  "sancov_flags.inc",
  "sanitizer_addrhashmap.h",
  "sanitizer_allocator.h",
  "sanitizer_allocator_checks.h",
  "sanitizer_allocator_combined.h",
  "sanitizer_allocator_dlsym.h",
  "sanitizer_allocator_interface.h",
  "sanitizer_allocator_internal.h",
  "sanitizer_allocator_local_cache.h",
  "sanitizer_allocator_primary32.h",
  "sanitizer_allocator_primary64.h",
  "sanitizer_allocator_report.h",
  "sanitizer_allocator_secondary.h",
  "sanitizer_allocator_size_class_map.h",
  "sanitizer_allocator_stats.h",
  "sanitizer_array_ref.h",
  "sanitizer_asm.h",
  "sanitizer_atomic.h",
  "sanitizer_atomic_clang.h",
  "sanitizer_atomic_msvc.h",
  "sanitizer_bitvector.h",
  "sanitizer_bvgraph.h",
  "sanitizer_chained_origin_depot.h",
  "sanitizer_common.h",
  "sanitizer_common_interceptors.inc",
  "sanitizer_common_interceptors_format.inc",
  "sanitizer_common_interceptors_ioctl.inc",
  "sanitizer_common_interceptors_memintrinsics.inc",
  "sanitizer_common_interface.inc",
  "sanitizer_common_interface_posix.inc",
  "sanitizer_common_syscalls.inc",
  "sanitizer_coverage_interface.inc",
  "sanitizer_dbghelp.h",
  "sanitizer_deadlock_detector.h",
  "sanitizer_deadlock_detector_interface.h",
  "sanitizer_dense_map.h",
  "sanitizer_dense_map_info.h",
  "sanitizer_dl.h",
  "sanitizer_errno.h",
  "sanitizer_errno_codes.h",
  "sanitizer_file.h",
  "sanitizer_flag_parser.h",
  "sanitizer_flags.h",
  "sanitizer_flags.inc",
  "sanitizer_flat_map.h",
  "sanitizer_fuchsia.h",
  "sanitizer_getauxval.h",
  "sanitizer_hash.h",
  "sanitizer_interceptors_ioctl_netbsd.inc",
  "sanitizer_interface_internal.h",
  "sanitizer_internal_defs.h",
  "sanitizer_leb128.h",
  "sanitizer_lfstack.h",
  "sanitizer_libc.h",
  "sanitizer_libignore.h",
  "sanitizer_linux.h",
  "sanitizer_list.h",
  "sanitizer_local_address_space_view.h",
  "sanitizer_lzw.h",
  "sanitizer_mac.h",
  "sanitizer_malloc_mac.inc",
  "sanitizer_mutex.h",
  "sanitizer_placement_new.h",
  "sanitizer_platform.h",
  "sanitizer_platform_interceptors.h",
  "sanitizer_platform_limits_netbsd.h",
  "sanitizer_platform_limits_posix.h",
  "sanitizer_platform_limits_solaris.h",
  "sanitizer_posix.h",
  "sanitizer_procmaps.h",
  "sanitizer_ptrauth.h",
  "sanitizer_quarantine.h",
  "sanitizer_range.h",
  "sanitizer_redefine_builtins.h",
  "sanitizer_report_decorator.h",
  "sanitizer_ring_buffer.h",
  "sanitizer_signal_interceptors.inc",
  "sanitizer_stack_store.h",
  "sanitizer_stackdepot.h",
  "sanitizer_stackdepotbase.h",
  "sanitizer_stacktrace.h",
  "sanitizer_stacktrace_printer.h",
  "sanitizer_stoptheworld.h",
  "sanitizer_suppressions.h",
  "sanitizer_symbolizer.h",
  "sanitizer_symbolizer_markup_constants.h",
  "sanitizer_symbolizer_internal.h",
  "sanitizer_symbolizer_libbacktrace.h",
  "sanitizer_symbolizer_mac.h",
  "sanitizer_symbolizer_markup.h",
  "sanitizer_syscall_generic.inc",
  "sanitizer_syscall_linux_aarch64.inc",
  "sanitizer_syscall_linux_arm.inc",
  "sanitizer_syscall_linux_x86_64.inc",
  "sanitizer_syscall_linux_riscv64.inc",
  "sanitizer_syscall_linux_loongarch64.inc",
  "sanitizer_syscalls_netbsd.inc",
  "sanitizer_thread_registry.h",
  "sanitizer_thread_safety.h",
  "sanitizer_tls_get_addr.h",
  "sanitizer_vector.h",
  "sanitizer_win.h",
  "sanitizer_win_defs.h",
  "sanitizer_win_interception.h",
  "sanitizer_win_thunk_interception.h",

  # Extra missing headers ?
  "sanitizer_type_traits.h",
  "sanitizer_platform_limits_freebsd.h",
  "sanitizer_thread_arg_retval.h",
  "sanitizer_mallinfo.h",
  "sanitizer_glibc_version.h",
  "sanitizer_thread_history.h",
  "sanitizer_solaris.h",
]

filegroup(
    name = "sanitizer_impl_headers",
    srcs = ["lib/sanitizer_common/" + f for f in SANITIZER_IMPL_HEADERS],
)

INTERCEPTION_IMPL_HEADERS = [
    "lib/interception/interception.h",
] + select({
    "@platforms//os:linux": [
        "lib/interception/interception_linux.h",
    ],
    "@platforms//os:macos": [
        "lib/interception/interception_mac.h",
    ],
    "@platforms//os:windows": [
        "lib/interception/interception_win.h",
    ],
})

filegroup(
    name = "interception_impl_headers",
    srcs = INTERCEPTION_IMPL_HEADERS,
)

cc_runtime_stage0_library(
    name = "sanitizer_common",
    srcs = [
        ":sanitizer_sources",
        ":sanitizer_impl_headers",
        ":interception_impl_headers",
    ],
    textual_hdrs = [
        "lib/sanitizer_common/sancov_flags.inc",
        "lib/sanitizer_common/sanitizer_flags.inc",
        "lib/sanitizer_common/sanitizer_signal_interceptors.inc",
        "lib/sanitizer_common/sanitizer_syscall_generic.inc",
    ],
    includes = ["lib"],
    implementation_deps = [
        ":libcxx_headers",
    ],
)

cc_runtime_stage0_library(
    name = "sanitizer_common_libc",
    srcs = [
        ":sanitizer_libcdep_sources",
        ":sanitizer_impl_headers",
    ],
    includes = ["lib"],
    implementation_deps = [
        ":libcxx_headers",
    ],
)

cc_runtime_stage0_library(
    name = "sanitizer_common_coverage",
    srcs = [
        ":sanitizer_coverage_sources",
        ":sanitizer_impl_headers",
    ],
    includes = ["lib"],
    implementation_deps = [
        ":libcxx_headers",
    ],
)

cc_runtime_stage0_library(
    name = "sanitizer_common_symbolizer",
    srcs = [
        ":sanitizer_symbolizer_sources",
        ":sanitizer_impl_headers",
    ],
    includes = ["lib"],
    implementation_deps = [
        ":libcxx_headers",
    ],
)

cc_runtime_stage0_library(
    name = "sanitizer_common_symbolizer_internal",
    srcs = [
        "lib/sanitizer_common/symbolizer/sanitizer_symbolize.cpp",
        ":sanitizer_impl_headers",
    ],
    deps = [
        ":llvm_Symbolize",
    ],
    includes = ["lib"],
    implementation_deps = [
        ":libcxx_headers",
    ],
)

## INTERCEPTION

INTERCEPTION_SOURCES = [
  "interception_linux.cpp",
  "interception_mac.cpp",
  "interception_win.cpp",
  "interception_type_test.cpp",
]

filegroup(
    name = "interception_sources",
    srcs = ["lib/interception/" + f for f in INTERCEPTION_SOURCES],
)

INTERCEPTION_HEADERS = [
  "interception.h",
  "interception_linux.h",
  "interception_mac.h",
  "interception_win.h",
]

filegroup(
    name = "interception_headers",
    srcs = ["lib/interception/" + f for f in INTERCEPTION_HEADERS],
)

cc_runtime_stage0_library(
    name = "interception",
    srcs = [
        ":interception_sources",
        ":interception_headers",
        ":sanitizer_impl_headers",
    ],
    includes = ["lib"],
    implementation_deps = [
        ":libcxx_headers",
    ],
)

## UBSAN

UBSAN_SOURCES = [
  "ubsan_diag.cpp",
  "ubsan_init.cpp",
  "ubsan_flags.cpp",
  "ubsan_handlers.cpp",
  "ubsan_monitor.cpp",
  "ubsan_value.cpp",
]

filegroup(
    name = "ubsan_sources",
    srcs = ["lib/ubsan/" + f for f in UBSAN_SOURCES],
)

UBSAN_STANDALONE_SOURCES = [
  "ubsan_diag_standalone.cpp",
  "ubsan_init_standalone.cpp",
  "ubsan_signals_standalone.cpp",
]

filegroup(
    name = "ubsan_standalone_sources",
    srcs = ["lib/ubsan/" + f for f in UBSAN_STANDALONE_SOURCES],
)

UBSAN_CXXABI_SOURCES = [
  "ubsan_handlers_cxx.cpp",
  "ubsan_type_hash.cpp",
  "ubsan_type_hash_itanium.cpp",
  "ubsan_type_hash_win.cpp"
]

filegroup(
    name = "ubsan_cxxabi_sources",
    srcs = ["lib/ubsan/" + f for f in UBSAN_CXXABI_SOURCES],
)

UBSAN_HEADERS = [
  "ubsan_checks.inc",
  "ubsan_diag.h",
  "ubsan_flags.h",
  "ubsan_flags.inc",
  "ubsan_handlers.h",
  "ubsan_handlers_cxx.h",
  "ubsan_init.h",
  "ubsan_interface.inc",
  "ubsan_monitor.h",
  "ubsan_platform.h",
  "ubsan_signals_standalone.h",
  "ubsan_type_hash.h",
  "ubsan_value.h"
]

filegroup(
    name = "ubsan_headers",
    srcs = ["lib/ubsan/" + f for f in UBSAN_HEADERS],
)

cc_runtime_stage0_library(
    name = "ubsan",
    srcs = [
        ":ubsan_sources",
        ":ubsan_standalone_sources",
        ":ubsan_cxxabi_sources",
        ":ubsan_headers",
    ],
    textual_hdrs = [
        "lib/ubsan/ubsan_checks.inc",
        "lib/ubsan/ubsan_flags.inc",
    ],
    #linkopts = [
    #    # User hook?
    #    "-Wl,-U,___ubsan_default_options",
    #],
    includes = ["lib"],
    deps = [
        ":sanitizer_common",
        ":sanitizer_common_libc",
        ":sanitizer_common_coverage",
        ":sanitizer_common_symbolizer",
        ":sanitizer_common_symbolizer_internal",
        ":interception",
        # if COMPILER_RT_ENABLE_INTERNAL_SYMBOLIZER
        ":llvm_Symbolize",
    ],
    implementation_deps = [
        ":libcxx_headers",
    ],
)

cc_runtime_stage0_static_library(
    name = "ubsan.static",
    deps = [":ubsan"],
    visibility = ["//visibility:public"],
)
