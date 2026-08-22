#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

#include "tools/windows_case/common.h"
#include "tools/windows_case_copy/copy.h"

namespace {

class TemporaryDirectory {
public:
  TemporaryDirectory() {
    path_ = std::filesystem::temp_directory_path() /
            ("windows-case-copy-test-" +
             std::to_string(
                 std::chrono::steady_clock::now().time_since_epoch().count()));
    std::filesystem::create_directories(path_);
  }

  ~TemporaryDirectory() {
    std::error_code error;
    std::filesystem::remove_all(path_, error);
  }

  const std::filesystem::path &path() const { return path_; }

private:
  std::filesystem::path path_;
};

bool Write(const std::filesystem::path &path, std::string_view contents) {
  std::ofstream output(path, std::ios::binary);
  output << contents;
  return output.good();
}

bool TestCopyDirectoryLowercasesFileBasenames() {
  TemporaryDirectory temporary;
  const std::filesystem::path source = temporary.path() / "source";
  const std::filesystem::path output = temporary.path() / "output";
  std::filesystem::create_directories(source / "Nested");
  if (!Write(source / "Kernel32.Lib", "kernel32") ||
      !Write(source / "Nested" / "Uuid.Lib", "uuid")) {
    std::cerr << "failed to create source files\n";
    return false;
  }

  std::string error;
  if (!windows_case_copy::CopyDirectory(source, output, &error)) {
    std::cerr << error << '\n';
    return false;
  }
  if (!std::filesystem::is_regular_file(output / "kernel32.lib") ||
      !std::filesystem::is_regular_file(output / "Nested" / "uuid.lib")) {
    std::cerr << "case-folded output files are missing\n";
    return false;
  }
  return true;
}

bool TestPreferredNameChoosesLowercaseAlias() {
  std::string preferred;
  std::string error;
  if (!windows_case::PreferredName("Kernel32.Lib", "kernel32.lib", &preferred,
                                   &error)) {
    std::cerr << error << '\n';
    return false;
  }
  if (preferred != "kernel32.lib") {
    std::cerr << "preferred name is " << preferred
              << ", want lowercase alias\n";
    return false;
  }
  return true;
}

} // namespace

int main() {
  if (!TestCopyDirectoryLowercasesFileBasenames() ||
      !TestPreferredNameChoosesLowercaseAlias()) {
    return 1;
  }
  return 0;
}
