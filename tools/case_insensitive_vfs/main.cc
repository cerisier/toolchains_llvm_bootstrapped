#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "tools/case_insensitive_vfs/vfs.h"

namespace {

bool ReadValue(int argc, char **argv, int *index, std::string *value) {
  if (*index + 1 >= argc) {
    return false;
  }
  *value = argv[++*index];
  return true;
}

} // namespace

int main(int argc, char **argv) {
  std::vector<std::filesystem::path> roots;
  std::string output_path;
  for (int index = 1; index < argc; ++index) {
    const std::string argument = argv[index];
    std::string value;
    if (argument == "-root") {
      if (!ReadValue(argc, argv, &index, &value)) {
        std::cerr << "-root requires a value\n";
        return 2;
      }
      roots.push_back(value);
    } else if (argument == "-output") {
      if (!ReadValue(argc, argv, &index, &output_path)) {
        std::cerr << "-output requires a value\n";
        return 2;
      }
    } else {
      std::cerr << "unknown argument: " << argument << '\n';
      return 2;
    }
  }
  if (output_path.empty()) {
    std::cerr << "-output is required\n";
    return 2;
  }

  std::string overlay;
  std::string error;
  if (!case_insensitive_vfs::GenerateOverlay(roots, &overlay, &error)) {
    std::cerr << error << '\n';
    return 1;
  }

  std::ofstream output(output_path, std::ios::binary | std::ios::trunc);
  output << overlay;
  if (!output.good()) {
    std::cerr << "write " << output_path << " failed\n";
    return 1;
  }
  return 0;
}
