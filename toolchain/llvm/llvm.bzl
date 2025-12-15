def bin(name):
    return select({
        "@platforms//os:windows": "bin/" + name + ".exe",
        "//conditions:default": "bin/" + name,
    })

def bins(names):
    return select({
        "@platforms//os:windows": ["bin/" + name + ".exe" for name in names],
        "//conditions:default": ["bin/" + name for name in names],
    })