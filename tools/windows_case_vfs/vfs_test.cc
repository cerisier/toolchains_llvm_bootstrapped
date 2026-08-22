#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <string_view>

#include "tools/windows_case/common.h"
#include "tools/windows_case_vfs/vfs.h"

namespace {

class TemporaryDirectory {
public:
  TemporaryDirectory() {
    path_ = std::filesystem::temp_directory_path() /
            ("windows-case-vfs-test-" +
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

bool Contains(std::string_view value, std::string_view expected) {
  if (value.find(expected) != std::string_view::npos) {
    return true;
  }
  std::cerr << "overlay does not contain " << expected << '\n';
  return false;
}

bool TestGenerateCaseInsensitiveOverlay() {
  TemporaryDirectory temporary;
  const std::filesystem::path root = temporary.path() / "root";
  std::filesystem::create_directories(root / "Nested");
  if (!Write(root / "Windows.h", "windows") ||
      !Write(root / "Nested" / "Ole2.h", "ole2")) {
    std::cerr << "failed to create source files\n";
    return false;
  }

  std::string overlay;
  std::string error;
  if (!windows_case_vfs::GenerateOverlay({root}, &overlay, &error)) {
    std::cerr << error << '\n';
    return false;
  }
  return Contains(overlay, "\"case-sensitive\": false") &&
         Contains(overlay, "\"use-external-names\": false") &&
         Contains(overlay, "\"name\": \"Windows.h\"") &&
         Contains(overlay, "\"name\": \"Nested\"") &&
         Contains(overlay, "\"name\": \"Ole2.h\"");
}

bool TestPreferredNameChoosesLowercaseAlias() {
  std::string preferred;
  std::string error;
  if (!windows_case::PreferredName("Windows.h", "windows.h", &preferred,
                                   &error)) {
    std::cerr << error << '\n';
    return false;
  }
  if (preferred != "windows.h") {
    std::cerr << "preferred name is " << preferred
              << ", want lowercase alias\n";
    return false;
  }
  return true;
}

bool TestPreferredNameRejectsAmbiguousEntries() {
  std::string preferred;
  std::string error;
  if (!windows_case::PreferredName("FOO.h", "Foo.h", &preferred, &error)) {
    return true;
  }
  std::cerr << "ambiguous case-only entries were accepted\n";
  return false;
}

bool TestGenerateFollowsTransformedHeaderSymlink() {
  TemporaryDirectory temporary;
  const std::filesystem::path root = temporary.path() / "root";
  std::filesystem::create_directories(root);
  const std::filesystem::path original = root / "Windows.h";
  if (!Write(original, "windows")) {
    std::cerr << "failed to create source file\n";
    return false;
  }
  std::error_code filesystem_error;
  std::filesystem::create_symlink(original, root / "windows.h",
                                  filesystem_error);
  if (filesystem_error) {
    return true;
  }

  std::string overlay;
  std::string error;
  if (!windows_case_vfs::GenerateOverlay({root}, &overlay, &error)) {
    std::cerr << error << '\n';
    return false;
  }
  return Contains(overlay, "\"name\": \"windows.h\"");
}

} // namespace

int main() {
  if (!TestGenerateCaseInsensitiveOverlay() ||
      !TestPreferredNameChoosesLowercaseAlias() ||
      !TestPreferredNameRejectsAmbiguousEntries() ||
      !TestGenerateFollowsTransformedHeaderSymlink()) {
    return 1;
  }
  return 0;
}
