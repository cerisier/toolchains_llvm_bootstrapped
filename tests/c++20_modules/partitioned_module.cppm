export module hermetic_llvm.tests.partitioned;

export import :detail;

export constexpr int partitioned_value() {
    return partition_value() + 2;
}