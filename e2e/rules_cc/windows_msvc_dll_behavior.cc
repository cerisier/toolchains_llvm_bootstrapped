extern "C" __declspec(dllimport) int add42(int);
extern "C" __declspec(dllimport) int explicit_add42(int);
extern "C" __declspec(dllimport) int generated_add42(int);

int main() {
  return add42(0) == 42 && explicit_add42(0) == 42 &&
                 generated_add42(0) == 42
             ? 0
             : 1;
}
