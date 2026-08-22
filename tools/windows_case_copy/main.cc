#include <iostream>
#include <string>

#include "tools/windows_case_copy/copy.h"

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
  std::string source;
  std::string output;
  for (int index = 1; index < argc; ++index) {
    const std::string argument = argv[index];
    if (argument == "-source") {
      if (!ReadValue(argc, argv, &index, &source)) {
        std::cerr << "-source requires a value\n";
        return 2;
      }
    } else if (argument == "-output") {
      if (!ReadValue(argc, argv, &index, &output)) {
        std::cerr << "-output requires a value\n";
        return 2;
      }
    } else {
      std::cerr << "unknown argument: " << argument << '\n';
      return 2;
    }
  }
  if (source.empty() || output.empty()) {
    std::cerr << "-source and -output are required\n";
    return 2;
  }

  std::string error;
  if (!windows_case_copy::CopyDirectory(source, output, &error)) {
    std::cerr << error << '\n';
    return 1;
  }
  return 0;
}
