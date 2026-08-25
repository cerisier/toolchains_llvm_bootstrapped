#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>

#include "tools/case_insensitive_copy/copy.h"
#include "tools/case_insensitive_filesystem/common.h"

namespace {

class TemporaryDirectory {
public:
  TemporaryDirectory() {
    path_ = std::filesystem::temp_directory_path() /
            ("case-insensitive-copy-test-" +
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

bool Read(const std::filesystem::path &path, std::string *contents) {
  std::ifstream input(path, std::ios::binary);
  contents->assign(std::istreambuf_iterator<char>(input),
                   std::istreambuf_iterator<char>());
  return input.good() || input.eof();
}

bool Contains(std::string_view value, std::string_view expected) {
  if (value.find(expected) != std::string_view::npos) {
    return true;
  }
  std::cerr << value << " does not contain " << expected << '\n';
  return false;
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
  if (!case_insensitive_copy::CopyDirectory(source, output, &error)) {
    std::cerr << error << '\n';
    return false;
  }
  const std::filesystem::path kernel32 = output / "kernel32.lib";
  const std::filesystem::path uuid = output / "Nested" / "uuid.lib";
  if (!std::filesystem::is_regular_file(kernel32) ||
      !std::filesystem::is_regular_file(uuid) ||
      !std::filesystem::is_directory(output / "Nested")) {
    std::cerr << "case-folded output files are missing\n";
    return false;
  }
  std::string kernel32_contents;
  std::string uuid_contents;
  return Read(kernel32, &kernel32_contents) && Read(uuid, &uuid_contents) &&
         kernel32_contents == "kernel32" && uuid_contents == "uuid";
}

bool TestPreferredNameChoosesLowercaseAlias() {
  std::string preferred;
  std::string error;
  if (!case_insensitive_filesystem::PreferredName(
          "Kernel32.Lib", "kernel32.lib", &preferred, &error)) {
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

bool TestCopyChoosesLowercaseAliasContents() {
  TemporaryDirectory temporary;
  const std::filesystem::path source = temporary.path() / "source";
  const std::filesystem::path output = temporary.path() / "output";
  std::filesystem::create_directories(source);
  const std::filesystem::path mixed = source / "Kernel32.Lib";
  const std::filesystem::path lower = source / "kernel32.lib";
  if (!Write(mixed, "mixed") || !Write(lower, "lower")) {
    std::cerr << "failed to create alias files\n";
    return false;
  }
  std::error_code filesystem_error;
  if (std::filesystem::equivalent(mixed, lower, filesystem_error) &&
      !filesystem_error) {
    return true;
  }

  std::string error;
  if (!case_insensitive_copy::CopyDirectory(source, output, &error)) {
    std::cerr << error << '\n';
    return false;
  }
  std::string contents;
  return Read(output / "kernel32.lib", &contents) && contents == "lower";
}

bool TestCopyRejectsAmbiguousCaseCollision() {
  TemporaryDirectory temporary;
  const std::filesystem::path source = temporary.path() / "source";
  const std::filesystem::path output = temporary.path() / "output";
  std::filesystem::create_directories(source);
  const std::filesystem::path upper = source / "FOO.Lib";
  const std::filesystem::path title = source / "Foo.Lib";
  if (!Write(upper, "upper") || !Write(title, "title")) {
    std::cerr << "failed to create collision files\n";
    return false;
  }
  std::error_code filesystem_error;
  if (std::filesystem::equivalent(upper, title, filesystem_error) &&
      !filesystem_error) {
    return true;
  }

  std::string error;
  if (!case_insensitive_copy::CopyDirectory(source, output, &error)) {
    return Contains(error, "ambiguous case-insensitive SDK entries");
  }
  std::cerr << "ambiguous case-only entries were accepted\n";
  return false;
}

bool TestCopyIsRepeatableAndPreservesEmptyDirectories() {
  TemporaryDirectory temporary;
  const std::filesystem::path source = temporary.path() / "source";
  const std::filesystem::path first_output = temporary.path() / "first";
  const std::filesystem::path second_output = temporary.path() / "second";
  std::filesystem::create_directories(source / "Empty");
  if (!Write(source / "Zeta.Lib", "zeta") ||
      !Write(source / "Alpha.Lib", "alpha")) {
    std::cerr << "failed to create source files\n";
    return false;
  }

  std::string error;
  if (!case_insensitive_copy::CopyDirectory(source, first_output, &error) ||
      !case_insensitive_copy::CopyDirectory(source, second_output, &error)) {
    std::cerr << error << '\n';
    return false;
  }
  std::string first_alpha;
  std::string second_alpha;
  std::string first_zeta;
  std::string second_zeta;
  return std::filesystem::is_directory(first_output / "Empty") &&
         std::filesystem::is_directory(second_output / "Empty") &&
         Read(first_output / "alpha.lib", &first_alpha) &&
         Read(second_output / "alpha.lib", &second_alpha) &&
         Read(first_output / "zeta.lib", &first_zeta) &&
         Read(second_output / "zeta.lib", &second_zeta) &&
         first_alpha == second_alpha && first_zeta == second_zeta;
}

bool TestCopyFollowsFileSymlink() {
  TemporaryDirectory temporary;
  const std::filesystem::path source = temporary.path() / "source";
  const std::filesystem::path output = temporary.path() / "output";
  std::filesystem::create_directories(source);
  const std::filesystem::path original = source / "Uuid.Lib";
  if (!Write(original, "uuid")) {
    std::cerr << "failed to create source file\n";
    return false;
  }
  std::error_code filesystem_error;
  std::filesystem::create_symlink(original, source / "uuid.lib",
                                  filesystem_error);
  if (filesystem_error) {
    return true;
  }

  std::string error;
  if (!case_insensitive_copy::CopyDirectory(source, output, &error)) {
    std::cerr << error << '\n';
    return false;
  }
  std::string contents;
  return Read(output / "uuid.lib", &contents) && contents == "uuid";
}

} // namespace

int main() {
  if (!TestCopyDirectoryLowercasesFileBasenames() ||
      !TestPreferredNameChoosesLowercaseAlias() ||
      !TestCopyChoosesLowercaseAliasContents() ||
      !TestCopyRejectsAmbiguousCaseCollision() ||
      !TestCopyIsRepeatableAndPreservesEmptyDirectories() ||
      !TestCopyFollowsFileSymlink()) {
    return 1;
  }
  return 0;
}
