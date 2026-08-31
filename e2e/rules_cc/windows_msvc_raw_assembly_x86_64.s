        .text
        .globl windows_msvc_raw_assembly_value
windows_msvc_raw_assembly_value:
        movl $42, %eax
        ret
