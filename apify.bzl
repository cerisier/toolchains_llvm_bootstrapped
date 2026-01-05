"""Macro for producing APE-wrapped binaries without modifying upstream build files."""

def apify_binary(name, elf, objcopy = "@toolchains_llvm_bootstrapped//tools:llvm-objcopy"):
    """Wraps an existing ELF binary in an APE-compatible binary for cosmo builds.

    Args:
        name: Name of the exposed target. On cosmo, this will produce an APE binary.
        elf: Label of the source executable (ELF) to convert.
        objcopy: Label of the objcopy tool to use.
    """
    ape_out = name + ".ape"

    native.genrule(
        name = name + "_ape",
        srcs = [elf],
        outs = [ape_out],
        tools = [objcopy],
        cmd = "$(location {objcopy}) -O binary $< $@".format(objcopy = objcopy),
        executable = True,
    )

    native.filegroup(
        name = name,
        srcs = select({
            "@toolchains_llvm_bootstrapped//platforms/config:cosmo": [name + "_ape"],
            "//conditions:default": [elf],
        }),
    )
