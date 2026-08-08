PPC64LE_FREESTANDING_RUNTIME_STAGES = [
    "stage0",
    "stage1",
    "stage1_hosted",
    "complete",
]

_PPC64LE_FREESTANDING_RUNTIME_SETTINGS = [
    "@llvm//toolchain:linux_ppc64le_freestanding_{}".format(runtime_stage)
    for runtime_stage in PPC64LE_FREESTANDING_RUNTIME_STAGES
]

def ppc64le_freestanding_select(value):
    """Returns a select map covering every freestanding ppc64le runtime stage.

    Args:
        value: The select value to use for every runtime stage.

    Returns:
        A dictionary keyed by the stage-specific ppc64le config settings.
    """
    return {
        setting: value
        for setting in _PPC64LE_FREESTANDING_RUNTIME_SETTINGS
    }
