def module_map_target_name(target_os, target_cpu, libc = None):
    name = "module_map_{}_{}".format(target_os, target_cpu)
    if libc != None:
        name += "_" + libc.replace(".", "_")
    return name
