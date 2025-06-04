def make_glibc_linker_script(name, lib_name, lib_version):
    native.genrule(
        name = name,
        srcs = [],
        outs = ["lib{lib}.so".format(lib = lib_name)],
        cmd = "echo 'INPUT(lib{lib}.so.{version})' > $@".format(lib = lib_name, version = lib_version),
    )
    return name
