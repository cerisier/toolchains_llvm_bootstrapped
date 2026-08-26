import hermetic_llvm.tests.std_importing;

int main() {
    std::string value = std_importing_value();
    return value == "modules" ? 0 : 1;
}