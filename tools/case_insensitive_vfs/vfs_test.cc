#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <string_view>
#include <vector>

#include "tools/case_insensitive_filesystem/common.h"
#include "tools/case_insensitive_vfs/vfs.h"

namespace {

class TemporaryDirectory {
public:
  TemporaryDirectory() {
    path_ = std::filesystem::temp_directory_path() /
            ("case-insensitive-vfs-test-" +
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

bool AppearsBefore(std::string_view value, std::string_view left,
                   std::string_view right) {
  const std::size_t left_position = value.find(left);
  const std::size_t right_position = value.find(right);
  if (left_position != std::string_view::npos &&
      right_position != std::string_view::npos &&
      left_position < right_position) {
    return true;
  }
  std::cerr << left << " does not appear before " << right << '\n';
  return false;
}

bool GenerateOverlay(std::initializer_list<std::filesystem::path> roots,
                     std::string *overlay, std::string *error) {
  std::vector<std::string> root_strings;
  std::vector<const char *> root_paths;
  for (const std::filesystem::path &root : roots) {
    root_strings.push_back(root.string());
  }
  for (const std::string &root : root_strings) {
    root_paths.push_back(root.c_str());
  }
  char *generated = nullptr;
  char *generated_error = nullptr;
  const bool result = case_insensitive_vfs_generate(
      root_paths.data(), root_paths.size(), &generated, &generated_error);
  if (result) {
    *overlay = generated;
  } else {
    *error = generated_error;
  }
  std::free(generated);
  std::free(generated_error);
  return result;
}

bool PreferredName(std::string_view left, std::string_view right,
                   std::string *preferred, std::string *error) {
  const std::string left_string(left);
  const std::string right_string(right);
  char *generated = nullptr;
  char *generated_error = nullptr;
  const bool result = ci_preferred_name(
      left_string.c_str(), right_string.c_str(), &generated, &generated_error);
  if (result) {
    *preferred = generated;
  } else {
    *error = generated_error;
  }
  std::free(generated);
  std::free(generated_error);
  return result;
}

std::string GenericPath(const std::filesystem::path &path) {
  char *generic = ci_generic_path(path.string().c_str());
  std::string result(generic);
  std::free(generic);
  return result;
}

std::string JsonString(const std::string &value) {
  char *json = ci_json_string(value.c_str());
  std::string result(json);
  std::free(json);
  return result;
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
  if (!GenerateOverlay({root}, &overlay, &error)) {
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
  if (!PreferredName("Windows.h", "windows.h", &preferred, &error)) {
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
  if (!PreferredName("FOO.h", "Foo.h", &preferred, &error)) {
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
  if (!GenerateOverlay({root}, &overlay, &error)) {
    std::cerr << error << '\n';
    return false;
  }
  return Contains(overlay, "\"name\": \"windows.h\"");
}

bool TestGenerateIsDeterministicAndSortsRootsAndEntries() {
  TemporaryDirectory temporary;
  const std::filesystem::path first_root = temporary.path() / "a-root";
  const std::filesystem::path second_root = temporary.path() / "z-root";
  std::filesystem::create_directories(first_root / "Empty");
  std::filesystem::create_directories(second_root);
  if (!Write(first_root / "zeta.h", "zeta") ||
      !Write(first_root / "Alpha.h", "alpha") ||
      !Write(second_root / "Second.h", "second")) {
    std::cerr << "failed to create source files\n";
    return false;
  }

  std::string first_overlay;
  std::string error;
  if (!GenerateOverlay({second_root, first_root}, &first_overlay, &error)) {
    std::cerr << error << '\n';
    return false;
  }

  std::filesystem::remove(first_root / "zeta.h");
  std::filesystem::remove(first_root / "Alpha.h");
  if (!Write(first_root / "Alpha.h", "alpha") ||
      !Write(first_root / "zeta.h", "zeta")) {
    std::cerr << "failed to recreate source files\n";
    return false;
  }

  std::string second_overlay;
  if (!GenerateOverlay({first_root, second_root}, &second_overlay, &error)) {
    std::cerr << error << '\n';
    return false;
  }
  if (first_overlay != second_overlay) {
    std::cerr << "overlay depends on root or directory iteration order\n";
    return false;
  }

  return Contains(first_overlay, "\"name\": \"Empty\"") &&
         AppearsBefore(first_overlay, GenericPath(first_root),
                       GenericPath(second_root)) &&
         AppearsBefore(first_overlay, "\"name\": \"Alpha.h\"",
                       "\"name\": \"zeta.h\"");
}

bool TestGenerateRejectsAmbiguousCaseCollision() {
  TemporaryDirectory temporary;
  const std::filesystem::path root = temporary.path() / "root";
  std::filesystem::create_directories(root);
  const std::filesystem::path upper = root / "FOO.h";
  const std::filesystem::path title = root / "Foo.h";
  if (!Write(upper, "upper") || !Write(title, "title")) {
    std::cerr << "failed to create case-collision files\n";
    return false;
  }
  std::error_code filesystem_error;
  if (std::filesystem::equivalent(upper, title, filesystem_error) &&
      !filesystem_error) {
    return true;
  }

  std::string overlay;
  std::string error;
  if (!GenerateOverlay({root}, &overlay, &error)) {
    return Contains(error, "ambiguous case-insensitive SDK entries");
  }
  std::cerr << "ambiguous case-only entries were accepted\n";
  return false;
}

bool TestGenerateRejectsDirectorySymlink() {
  TemporaryDirectory temporary;
  const std::filesystem::path root = temporary.path() / "root";
  std::filesystem::create_directories(root / "Directory");
  std::error_code filesystem_error;
  std::filesystem::create_directory_symlink(root / "Directory", root / "Link",
                                            filesystem_error);
  if (filesystem_error) {
    return true;
  }

  std::string overlay;
  std::string error;
  if (!GenerateOverlay({root}, &overlay, &error)) {
    return Contains(error, "unsupported SDK directory symlink");
  }
  std::cerr << "directory symlink was accepted\n";
  return false;
}

bool TestJsonAndGenericPathEscaping() {
  const std::string escaped = JsonString(std::string("\"\\\b\f\n\r\t\x01", 8));
  if (escaped != "\"\\\"\\\\\\b\\f\\n\\r\\t\\u0001\"") {
    std::cerr << "unexpected JSON escaping: " << escaped << '\n';
    return false;
  }
  const std::string generic =
      GenericPath(std::filesystem::path("alpha") / "beta");
  if (generic != "alpha/beta") {
    std::cerr << "unexpected generic path: " << generic << '\n';
    return false;
  }
  return true;
}

} // namespace

int main() {
  if (!TestGenerateCaseInsensitiveOverlay() ||
      !TestPreferredNameChoosesLowercaseAlias() ||
      !TestPreferredNameRejectsAmbiguousEntries() ||
      !TestGenerateFollowsTransformedHeaderSymlink() ||
      !TestGenerateIsDeterministicAndSortsRootsAndEntries() ||
      !TestGenerateRejectsAmbiguousCaseCollision() ||
      !TestGenerateRejectsDirectorySymlink() ||
      !TestJsonAndGenericPathEscaping()) {
    return 1;
  }
  return 0;
}
