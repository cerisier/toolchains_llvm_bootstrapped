load(":abis.bzl", "ABIS")

def declare_abis_constraints():
    for abi in ABIS:
        native.constraint_value(
            name = abi,
            constraint_setting = "variant",
        )
