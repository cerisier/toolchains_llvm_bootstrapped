load(
    "//toolchain:linker_policy.bzl",
    "LINKER_CONSTRAINTS",
    "PLATFORM_LINUX_AARCH64_GNU",
    "PLATFORM_LINUX_X86_64_GNU",
    "PLATFORM_MACOS_AARCH64",
    "linker_contract_directives",
)

MACOS_AARCH64_CONSTRAINTS = LINKER_CONSTRAINTS[PLATFORM_MACOS_AARCH64]
LINUX_X86_64_CONSTRAINTS = LINKER_CONSTRAINTS[PLATFORM_LINUX_X86_64_GNU]
LINUX_AARCH64_CONSTRAINTS = LINKER_CONSTRAINTS[PLATFORM_LINUX_AARCH64_GNU]

MACOS_AARCH64_LINKER_CONTRACT_DIRECTIVES = linker_contract_directives(PLATFORM_MACOS_AARCH64)
LINUX_X86_64_LINKER_CONTRACT_DIRECTIVES = linker_contract_directives(PLATFORM_LINUX_X86_64_GNU)
LINUX_AARCH64_LINKER_CONTRACT_DIRECTIVES = linker_contract_directives(PLATFORM_LINUX_AARCH64_GNU)

def _render_contract_line(directive):
    kind = directive[0]
    if kind == "arg":
        return "arg\t%s" % directive[1]
    if kind == "runfile":
        return "runfile\t$(rlocationpath %s)" % directive[1]
    if kind == "runfile_prefix":
        return "runfile_prefix\t%s\t$(rlocationpath %s)" % (directive[1], directive[2])
    if kind == "setenv":
        return "setenv\t%s\t%s" % (directive[1], directive[2])
    fail("Unknown linker contract directive kind: %s" % kind)

def _contract_tools(directives):
    tools = {}
    for directive in directives:
        kind = directive[0]
        if kind == "runfile":
            tools[directive[1]] = True
        elif kind == "runfile_prefix":
            tools[directive[2]] = True
    return tools.keys()

def linker_contract_genrule(name, out, directives, target_compatible_with):
    lines = [
        "cat > $@ <<'CONTRACT'",
        "# directive<TAB>payload",
    ]
    for directive in directives:
        lines.append(_render_contract_line(directive))
    lines.append("CONTRACT")

    native.genrule(
        name = name,
        outs = [out],
        cmd = "\n".join(lines),
        tools = _contract_tools(directives),
        target_compatible_with = target_compatible_with,
    )

def linker_wrapper_config_genrule(name, out, contract_label):
    native.genrule(
        name = name,
        outs = [out],
        cmd = "\n".join([
            "cat > $@ <<'CONFIG'",
            "#include \"tools/internal/linker_wrapper_config.h\"",
            "",
            "namespace llvm_toolchain {",
            "",
            "const char* kLinkerWrapperClangRlocation = \"$(rlocationpath //tools:clang++)\";",
            "const char* kLinkerWrapperContractRlocation = \"$(rlocationpath %s)\";" % contract_label,
            "",
            "}  // namespace llvm_toolchain",
            "CONFIG",
        ]),
        tools = [
            "//tools:clang++",
            contract_label,
        ],
    )
