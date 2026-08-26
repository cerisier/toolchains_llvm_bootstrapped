export module hermetic_llvm.tests.std_importing;

export import std;

export inline std::string std_importing_value() {
    return "modules";
}