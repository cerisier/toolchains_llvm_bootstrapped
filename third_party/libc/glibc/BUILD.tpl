load("@bazel_skylib//lib:selects.bzl", "selects")
load("@toolchains_llvm_bootstrapped//third_party/libc/glibc:helpers.bzl", "glibc_includes")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_static_library.bzl", "cc_stage2_static_library")
load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_object.bzl", "cc_stage2_object")
load("@toolchains_llvm_bootstrapped//toolchain/args:targets.bzl", "TARGETS")

alias(
    name = "gnu_libc_headers",
    actual = "@glibc//:gnu_libc_headers",
)

alias(
    name = "kernel_headers",
    actual = "@kernel_headers//:kernel_headers",
)

HDRS = glob([
    "csu/**",
    "debug/**/*.h",
    "elf/**/*.h",
    "include/**/*.h",
    "io/**/*.h",
    "locale/**/*.h",
    "misc/**/*.h",
    "posix/**/*.h",
    "signal/**/*.h",
    "stdlib/**/*.h",
    "string/**/*.h",
    "sysdeps/**/*.h",
    "time/**/*.h",
] + [
    "bits/types/__sigset_t.h",
    "bits/types/struct_sched_param.h",
    "bits/waitstatus.h",
    "bits/stat.h",
    "bits/libc-header-start.h",
    "bits/stdint-intn.h",
    "bits/waitflags.h",
    "bits/byteswap.h",
    "bits/long-double.h",
    "bits/typesizes.h",
    "bits/uintn-identity.h",
    "bits/floatn-common.h",
    "bits/signum-generic.h",
    "bits/pthreadtypes.h",
    "bits/stdlib-bsearch.h",
    "bits/select.h",
])

cc_stage2_library(
    name = "glibc_init",
    copts = [
        # Normally, we would pass -nostdinc, but since we pass -nostdlibinc
        # from the stage2 toolchain args regarless, having them both cause a
        # warning about -nostdlibinc being ignored, so we duplicate the
        # -nostdlibinc and add -nobuiltininc to avoid the warning.
        #
        # -nostdinc = -nostdlibinc -nobuiltininc
        "-nostdlibinc",
        "-nobuiltininc",
    ],
    srcs = ["csu/init.c"],
    visibility = ["//visibility:public"],
)

cc_stage2_library(
    name = "glibc_abi_note",
    srcs = [
        "@toolchains_llvm_bootstrapped//third_party/libc/glibc/csu:abi-note-2.31.S",
    ],
    copts = [
        # Normally, we would pass -nostdinc, but since we pass -nostdlibinc
        # from the stage2 toolchain args regarless, having them both cause a
        # warning about -nostdlibinc being ignored, so we duplicate the
        # -nostdlibinc and add -nobuiltininc to avoid the warning.
        #
        # -nostdinc = -nostdlibinc -nobuiltininc
        "-nostdlibinc",
        "-nobuiltininc",
        "-Wa,--noexecstack",
    ],
    local_defines = [
        "_LIBC_REENTRANT",
        "MODULE_NAME=libc",
        "TOP_NAMESPACE=glibc",
        "ASSEMBLER",
    ],
    hdrs = HDRS,
    includes = [
        "csu",
    ] + select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": glibc_includes("x86_64"),
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": glibc_includes("aarch64"),
    }),
    visibility = ["//visibility:public"],
)

cc_stage2_library(
    name = "glibc_start",
    srcs = select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": ["sysdeps/x86_64/start.S"],
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": ["sysdeps/aarch64/start.S"],
    }, no_match_error = "Unsupported platform"),
    copts = [
        # Normally, we would pass -nostdinc, but since we pass -nostdlibinc
        # from the stage2 toolchain args regarless, having them both cause a
        # warning about -nostdlibinc being ignored, so we duplicate the
        # -nostdlibinc and add -nobuiltininc to avoid the warning.
        #
        # -nostdinc = -nostdlibinc -nobuiltininc
        "-nostdlibinc",
        "-nobuiltininc",
        "-Wno-nonportable-include-path",
        "-Wa,--noexecstack",
        "-include",
        "$(location include/libc-modules.h)",
        "-DMODULE_NAME=libc",
        "-include",
        "$(location include/libc-symbols.h)",
    ],
    local_defines = [
        "_LIBC_REENTRANT",
        "MODULE_NAME=libc",
        "PIC",
        "SHARED",
        "TOP_NAMESPACE=glibc",
        "ASSEMBLER",
    ],
    additional_compiler_inputs = [
        "include/libc-modules.h",
        "include/libc-symbols.h",
    ],
    hdrs = HDRS,
    includes = select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": glibc_includes("x86_64"),
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": glibc_includes("aarch64"),
    }),
    implementation_deps = [
        ":kernel_headers",
        ":gnu_libc_headers",
    ],
    visibility = ["//visibility:public"],
)

cc_stage2_library(
    name = "glibc_Scrt1",
    deps = [":glibc_start", ":glibc_init", ":glibc_abi_note"],
    visibility = ["//visibility:public"],
)

cc_stage2_object(
    name = "glibc_Scrt1.object",
    srcs = [":glibc_start", ":glibc_init", ":glibc_abi_note"],
    copts = [
        "-target",
    ] + TARGETS,
    out = "Scrt1.o",
    visibility = ["//visibility:public"],
)


cc_stage2_static_library(
    name = "glibc_Scrt1.static",
    deps = [":glibc_Scrt1"],
    visibility = ["//visibility:public"],
)

# pub fn compilerRtOptMode(comp: Compilation) std.builtin.OptimizeMode {
#     if (comp.debug_compiler_runtime_libs) {
#         return comp.root_mod.optimize_mode;
#     }
#     const target = comp.root_mod.resolved_target.result;
#     switch (comp.root_mod.optimize_mode) {
#         .Debug, .ReleaseSafe => return target_util.defaultCompilerRtOptimizeMode(target),
#         .ReleaseFast => return .ReleaseFast,
#         .ReleaseSmall => return .ReleaseSmall,
#     }
# }

# pub fn defaultCompilerRtOptimizeMode(target: std.Target) std.builtin.OptimizeMode {
#     if (target.cpu.arch.isWasm() and target.os.tag == .freestanding) {
#         return .ReleaseSmall;
#     } else {
#         return .ReleaseFast;
#     }
# }

cc_stage2_library(
    # glibc_c_nonshared
    name = "c_nonshared",
    copts = [
        "-std=gnu11",
        "-fgnu89-inline",
        "-fmerge-all-constants",
        "-frounding-math",
        "-Wno-unsupported-floating-point-opt", # For targets that don't support -frounding-math.
        "-fno-common",
        "-fmath-errno",
        "-ftls-model=initial-exec",
        "-Wno-ignored-attributes",
        "-Qunused-arguments",

        "-Wno-nonportable-include-path",

        "-include",
        "$(location include/libc-modules.h)",
        "-include",
        "$(location include/libc-symbols.h)",
    ],
    local_defines = [
        "NO_INITFINI",
        "_LIBC_REENTRANT",
        "MODULE_NAME=libc",
        # "PIC",
        "LIBC_NONSHARED=1",
        "TOP_NAMESPACE=glibc",
    ] + select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": [
            "CAN_USE_REGISTER_ASM_EBP",
        ],
        "//conditions:default": [],
    }),
    #TODO: glibc_includes with glob
    hdrs = HDRS,
    includes = [
        "csu",
    ] + select({
        "@toolchains_llvm_bootstrapped//platforms/config:linux_x86_64": glibc_includes("x86_64"),
        "@toolchains_llvm_bootstrapped//platforms/config:linux_aarch64": glibc_includes("aarch64"),
    }),
    srcs = [
        # From stdlib/Makefile
        "@toolchains_llvm_bootstrapped//third_party/libc/glibc/stdlib:atexit.c",
        "@toolchains_llvm_bootstrapped//third_party/libc/glibc/stdlib:at_quick_exit.c",
        # From nptl/Makefile
        "@toolchains_llvm_bootstrapped//third_party/libc/glibc/nptl:pthread_atfork.c",
        # From debug/Makefile
        "debug/stack_chk_fail_local.c",
    ] + selects.with_or({
        (
            # For now the minimum version of all supported platforms is glibc 2.28
            "@toolchains_llvm_bootstrapped//constraints/libc:unconstrained",
            "@toolchains_llvm_bootstrapped//constraints/libc:gnu.2.28",
            "@toolchains_llvm_bootstrapped//constraints/libc:gnu.2.29",
            "@toolchains_llvm_bootstrapped//constraints/libc:gnu.2.30",
            "@toolchains_llvm_bootstrapped//constraints/libc:gnu.2.31",
            "@toolchains_llvm_bootstrapped//constraints/libc:gnu.2.32",
        ): [
            # libc_nonshared.a redirected stat functions to xstat until glibc 2.33,
            # when they were finally versioned like other symbols.

            # From io/Makefile
            "io/stat.c",
            "io/fstat.c",
            "io/lstat.c",
            "io/stat64.c",
            "io/fstat64.c",
            "io/lstat64.c",
            "io/fstatat.c",
            "io/fstatat64.c",
            "io/mknodat.c",
            "io/mknod.c",

            # if libc <= 2.32 but also <= 2.33
            # From csu/Makefile
            "@toolchains_llvm_bootstrapped//third_party/libc/glibc/csu:elf-init-2.31.c",
        ],
        "@toolchains_llvm_bootstrapped//constraints/libc:gnu.2.33": [
            # if libc <= 2.32 but also <= 2.33
            # __libc_start_main used to require statically linked init/fini callbacks
            # until glibc 2.34 when they were assimilated into the shared library.
            "@toolchains_llvm_bootstrapped//third_party/libc/glibc/csu:elf-init-2.31.c",
        ],
        "//conditions:default": [],
    }),
    additional_compiler_inputs = [
        "include/libc-modules.h",
        "include/libc-symbols.h",
    ],
    implementation_deps = select({
        "@platforms//os:macos": [],
        "@platforms//os:linux": [
            ":kernel_headers",
        ],
    }) + [
        ":gnu_libc_headers",
    ],
    visibility = ["//visibility:public"],
)

cc_stage2_static_library(
    name = "c_nonshared.static",
    deps = [
        ":c_nonshared",
    ],
    visibility = ["//visibility:public"],
)
