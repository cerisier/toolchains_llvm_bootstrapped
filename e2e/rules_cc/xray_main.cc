#include <cstdio>

[[clang::xray_always_instrument]] static void function_to_trace() {
    std::puts("xray runtime exercised");
}

int main() {
    function_to_trace();
    return 0;
}
