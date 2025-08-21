#TODO: Generate this file based on the content of lib/builtins/Darwin-excludes.txt
_OSX_EXCLUDE_LIST = [
    "apple_versioning",
    "addtf3",
    "divtf3",
    "multf3",
    "powitf2",
    "subtf3",
    "trampoline_setup",
]

def _filter_exclude(srcs, exclude):
    result = []
    for s in srcs:
        excluded = False
        for e in exclude:
            if e in s:
                excluded = True
                break
        if not excluded:
            result.append(s)
    return result

def filter_excludes(srcs):
    return select({
        "@platforms//os:macos": _filter_exclude(srcs, _OSX_EXCLUDE_LIST),
        "//conditions:default": srcs,
    })
