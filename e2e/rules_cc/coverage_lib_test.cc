#include "coverage_lib.h"

// Calls covered() but never uncovered(), so a correct lcov report shows one hit
// line and one unexecuted line for coverage_lib.cc.
int main() {
    return covered(41) == 42 ? 0 : 1;
}
