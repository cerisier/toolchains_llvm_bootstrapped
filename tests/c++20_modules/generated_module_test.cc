import hermetic_llvm.tests.generated;

int main() {
    return generated_value() == 42 ? 0 : 1;
}