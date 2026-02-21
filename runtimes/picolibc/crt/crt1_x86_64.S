.global _start
.type _start,@function

_start:
    xorq %rbp, %rbp
    movq (%rsp), %rdi
    leaq 8(%rsp), %rsi
    leaq 16(%rsp,%rdi,8), %rdx
    andq $-16, %rsp
    call main

    movl %eax, %edi
    movl $60, %eax
    syscall

    hlt
