import hermetic_llvm.tests.global_fragment;

int main() {
    return global_fragment_value() == 42 ? 0 : 1;
}