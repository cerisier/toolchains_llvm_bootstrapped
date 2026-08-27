import hermetic_llvm.tests.implementation;

int main() {
    return implemented_value() == 42 ? 0 : 1;
}