extern "C" __declspec(dllimport) int explicit_add42(int);

int main() {
    return explicit_add42(0) == 42 ? 0 : 1;
}
