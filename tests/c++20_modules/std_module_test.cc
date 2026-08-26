import std;

int main() {
    std::string value = "modules";
    std::array<int, 3> numbers{1, 2, 3};
    return value.size() == 7 && numbers[0] + numbers[1] + numbers[2] == 6 ? 0 : 1;
}