#include <cmath>
#include <cstdio>

#if defined(__clang__)
__attribute__((optnone))
#endif
__attribute__((noinline)) static float return_nan(float p, float q) {
    return p / q;
}

int main() {
    volatile float zero = 0.0f;
    float v = return_nan(zero, zero);
    std::printf("%f\n", v);
    return 0;
}
