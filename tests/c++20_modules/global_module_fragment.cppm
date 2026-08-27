module;

#include "global_module_fragment.h"

export module hermetic_llvm.tests.global_fragment;

export constexpr int global_fragment_value() {
    return HERMETIC_LLVM_GLOBAL_FRAGMENT_VALUE;
}