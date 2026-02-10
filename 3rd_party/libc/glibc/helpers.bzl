def glibc_includes(cpu):

    x86_64_variant = [
        "sysdeps/unix/sysv/linux/x86_64/64".format(cpu),
    ] if cpu == "x86_64" else []

    return [
        "include",
        "sysdeps/unix/sysv/linux/{}".format(cpu),
    ] + x86_64_variant + [
        "sysdeps/{}".format(cpu),
        "sysdeps/unix/sysv/linux/generic",
        "sysdeps/unix/sysv/linux/include",
        "sysdeps/unix/sysv/linux",
        "sysdeps/{}/nptl".format(cpu),
        "sysdeps/nptl",
        "sysdeps/pthread",
        "sysdeps/unix/sysv",
        "sysdeps/unix/{}".format(cpu),
        "sysdeps/unix",
        "sysdeps/{}".format(cpu),
        "sysdeps/generic",
        ".",
    ]

# hdrs = glob([
#     "lib/libc/glibc/**/*.h",
# ], exclude = [
#     "lib/libc/glibc/sysdeps/**",
#     "lib/libc/glibc/include/**",
# ]) + glob([
#     "lib/libc/glibc/include/*.h",
#     "lib/libc/glibc/include/*.h",
# ])
# + glob(
#     [
#         "lib/libc/glibc/sysdeps/unix/sysv/linux/x86_64/**",
#         "lib/libc/glibc/sysdeps/x86_64/**",
#         "lib/libc/glibc/sysdeps/unix/sysv/linux/generic/**",
#         "lib/libc/glibc/sysdeps/unix/sysv/linux/include/**",
#     ],
#     allow_empty = True
# ) + glob(
#     [
#         "lib/libc/glibc/sysdeps/unix/sysv/linux/*",
#         "lib/libc/glibc/sysdeps/unix/sysv/linux/bits/**",
#         "lib/libc/glibc/sysdeps/unix/sysv/linux/sys/**",
#     ],
#     allow_empty = True
# )
# + glob([
#         # "lib/libc/glibc/sysdeps/nptl/**",
#         "lib/libc/glibc/sysdeps/pthread/**",
#         "lib/libc/glibc/sysdeps/unix/x86_64/**",
#         # "lib/libc/glibc/sysdeps/x86_64/**",
#         "lib/libc/glibc/sysdeps/generic/**",
#     ],
#     allow_empty = True
# ),
