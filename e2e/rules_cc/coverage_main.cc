#include <cstdio>

namespace {

int covered(int x) {
    return x + 1;
}

// Never called at run time. A full lcov report would show this as uncovered;
// this binary-level test only asserts that instrumentation emits a .profraw,
// so we just keep the symbol around without executing it.
[[maybe_unused]] int uncovered(int x) {
    return x - 1;
}

}  // namespace

int main() {
    volatile int r = covered(41);
    (void)r;
    std::puts("coverage runtime exercised");
    return 0;
}
