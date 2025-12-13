load("@bazel_skylib//rules:write_file.bzl", "write_file")

def make_glibc_linker_script(name, lib_name, lib_version, additional_linker_inputs = []):
    write_file(
        name = name,
        out = "lib{lib}.so".format(lib = lib_name),
        content = [
            # GROUP(file) is the same as INPUT(file) when there is just one file
            "GROUP(lib{lib}.so.{version} {extra_inputs})".format(
                lib = lib_name,
                version = lib_version,
                extra_inputs = " ".join(additional_linker_inputs),
            ),
        ],
    )
    return name
