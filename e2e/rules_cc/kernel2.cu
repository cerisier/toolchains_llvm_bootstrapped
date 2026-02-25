#include <cuda_runtime_api.h>
#include <cstdio>
#include <cmath>

extern "C" __device__ float __nv_erfcinvf(float);
__device__ float g_libdevice_probe;

#define CUDA_CHECK(call)                                                          \
    do {                                                                          \
        cudaError_t err__ = (call);                                               \
        if (err__ != cudaSuccess) {                                               \
            fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__,     \
                    cudaGetErrorString(err__));                                   \
            return 1;                                                             \
        }                                                                         \
    } while (0)

__global__ void saxpy2(float a, float *x, float *y) {
    int i = threadIdx.x;
    g_libdevice_probe = __nv_erfcinvf(x[i] * 0.25f);
    y[i] = a * x[i] + y[i];
}
