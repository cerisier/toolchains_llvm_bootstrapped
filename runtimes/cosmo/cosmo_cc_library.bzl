load("@toolchains_llvm_bootstrapped//toolchain/stage2:cc_stage2_library.bzl", "cc_stage2_library")


NO_MAGIC_COPTS = [
    "-ffreestanding",
	"-fno-stack-protector",
	"-fwrapv",
	"-fno-sanitize=all",
	"-fpatchable-function-entry=0,0",
]

##########################################

DEFAULT_CCFLAGS = [
    "-Wall",
	#"-Werror",
	"-fno-omit-frame-pointer",
	"-frecord-gcc-switches",
]

DEFAULT_COPTS = [
	"-fno-ident",
	"-fno-common",
	#"-fno-gnu-unique",
	"-fstrict-aliasing",
	"-fstrict-overflow",
	"-fno-semantic-interposition",
] + select({
    "@platforms//cpu:x86_64": [
        "-mno-red-zone",
	    "-mno-tls-direct-seg-refs",
    ],
    "@platforms//cpu:aarch64": [
        "-ffixed-x18",
        "-ffixed-x28",
        "-fsigned-char",
    ],
})

DEFAULT_CPPFLAGS = [
	"-D_COSMO_SOURCE",
    # TODO(zbarsky): Other modes?
	"-DMODE='opt'",
	#"-Wno-prio-ctor-dtor",
	"-Wno-unknown-pragmas",
	"-nostdinc",
	"-iquote.",
	"-isystem libc/isystem",
]

DEFAULT_CFLAGS = [
    "-std=gnu23",
]

DEFAULT_CXXFLAGS = [
    "-std=gnu++23",
    "-fuse-cxa-atexit",
    "-Wno-int-in-bool-context",
    "-Wno-narrowing",
    "-Wno-literal-suffix",
    "-isystem third_party/libcxx",
]

DEFAULT_ASFLAGS = [
    "-Wa,-W",
    "-Wa,-I.",
    "-Wa,--noexecstack",
]

DEFAULT_LDFLAGS = [
	"-static",
	"-nostdlib",
	"-znorelro",
	"--gc-sections",
	"-z noexecstack",
	"--build-id=none",
	"--no-dynamic-linker",
]

COSMO_COMMON_COPTS = DEFAULT_CCFLAGS + DEFAULT_CPPFLAGS + DEFAULT_COPTS + DEFAULT_ASFLAGS

def cosmo_cc_library(name, srcs, copts = [], per_file_copts = {}, **kwargs):
    excludes = per_file_copts.keys()
    libs = [name + "_srcs"]

    cc_stage2_library(
        name = name + "_srcs",
        srcs = list(set(srcs) - set(excludes)),
        copts = COSMO_COMMON_COPTS + copts,
        conlyopts = DEFAULT_CFLAGS,
        cxxopts = DEFAULT_CXXFLAGS,
        **kwargs,
    )

    for file in per_file_copts:
        sanitized_name = file.replace("/", "_")
        libs.append(sanitized_name)

        cc_stage2_library(
            name = sanitized_name,
            srcs = [file],
            copts = COSMO_COMMON_COPTS + copts + per_file_copts[file],
            conlyopts = DEFAULT_CFLAGS,
            cxxopts = DEFAULT_CXXFLAGS,
            **kwargs
        )

    cc_stage2_library(
        name = name,
        srcs = [],
        deps = libs,
    )