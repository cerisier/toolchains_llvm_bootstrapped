export module hermetic_llvm.tests.transitive;

import hermetic_llvm.tests.transitive_base;

export constexpr int transitive_value() {
    return base_value() + 2;
}