// Pure C NVPTX kernel: no CUDA language, no CUDA headers.
__attribute__((nvptx_kernel))
void saxpy_raw(int n, float a,
               const float *x,
               const float *y,
               float *out) {
    unsigned int tid;
    unsigned int bid;
    unsigned int bdim;

    __asm__("mov.u32 %0, %%tid.x;" : "=r"(tid));
    __asm__("mov.u32 %0, %%ctaid.x;" : "=r"(bid));
    __asm__("mov.u32 %0, %%ntid.x;" : "=r"(bdim));

    unsigned int i = bid * bdim + tid;
    if (i < (unsigned int)n) {
        out[i] = a * x[i] + y[i];
    }
}
