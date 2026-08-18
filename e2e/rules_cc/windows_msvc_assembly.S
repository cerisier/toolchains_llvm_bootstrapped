#if defined(_M_ARM64)
        .text
        .globl windows_msvc_assembly_value
windows_msvc_assembly_value:
        mov w0, #42
        ret
#else
        .text
        .globl windows_msvc_assembly_value
windows_msvc_assembly_value:
        movl $42, %eax
        ret
#endif
