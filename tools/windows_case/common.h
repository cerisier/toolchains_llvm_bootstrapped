#ifndef HERMETIC_LLVM_TOOLS_WINDOWS_CASE_COMMON_H_
#define HERMETIC_LLVM_TOOLS_WINDOWS_CASE_COMMON_H_

#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

namespace windows_case {

struct DirectoryEntry {
  std::filesystem::directory_entry entry;
  std::string folded_name;
};

std::string FoldCase(std::string_view value);

bool PreferredName(std::string_view left, std::string_view right,
                   std::string *preferred, std::string *error);

bool CollectPreferredEntries(const std::filesystem::path &directory,
                             std::vector<DirectoryEntry> *entries,
                             std::string *error);

std::string GenericPath(const std::filesystem::path &path);

std::string JsonString(std::string_view value);

} // namespace windows_case

#endif // HERMETIC_LLVM_TOOLS_WINDOWS_CASE_COMMON_H_
