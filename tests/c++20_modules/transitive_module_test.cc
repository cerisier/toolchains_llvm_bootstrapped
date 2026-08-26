import hermetic_llvm.tests.transitive;

int main() {
    return transitive_value() == 42 ? 0 : 1;
}