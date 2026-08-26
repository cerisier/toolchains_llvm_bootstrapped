import hermetic_llvm.tests.direct;

int main() {
    return direct_add(20, 22) == 42 ? 0 : 1;
}