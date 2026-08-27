import hermetic_llvm.tests.partitioned;

int main() {
    return partitioned_value() == 42 && partition_value() == 40 ? 0 : 1;
}