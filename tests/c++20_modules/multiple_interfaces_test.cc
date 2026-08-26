import hermetic_llvm.tests.multiple_alpha;
import hermetic_llvm.tests.multiple_beta;

int main() {
    return alpha_value() + beta_value() == 42 ? 0 : 1;
}