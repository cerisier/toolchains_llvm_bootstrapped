#include "tools/windows_case/common.h"

#include <cctype>
#include <iomanip>
#include <map>
#include <sstream>
#include <system_error>

namespace windows_case {
namespace {

std::string FilesystemError(std::string_view operation,
                            const std::filesystem::path &path,
                            const std::error_code &error) {
  std::ostringstream message;
  message << operation << " " << GenericPath(path) << ": " << error.message();
  return message.str();
}

} // namespace

std::string FoldCase(std::string_view value) {
  std::string result;
  result.reserve(value.size());
  for (unsigned char character : value) {
    result.push_back(static_cast<char>(std::tolower(character)));
  }
  return result;
}

bool PreferredName(std::string_view left, std::string_view right,
                   std::string *preferred, std::string *error) {
  const std::string folded = FoldCase(left);
  if (folded != FoldCase(right)) {
    *error = "internal case-fold mismatch: \"" + std::string(left) +
             "\" and \"" + std::string(right) + "\"";
    return false;
  }
  if (left == folded) {
    *preferred = std::string(left);
    return true;
  }
  if (right == folded) {
    *preferred = std::string(right);
    return true;
  }
  *error = "ambiguous case-insensitive SDK entries \"" + std::string(left) +
           "\" and \"" + std::string(right) + "\"";
  return false;
}

bool CollectPreferredEntries(const std::filesystem::path &directory,
                             std::vector<DirectoryEntry> *entries,
                             std::string *error) {
  std::error_code filesystem_error;
  std::filesystem::directory_iterator iterator(directory, filesystem_error);
  if (filesystem_error) {
    *error = FilesystemError("read", directory, filesystem_error);
    return false;
  }

  std::map<std::string, std::filesystem::directory_entry> by_folded_name;
  const std::filesystem::directory_iterator end;
  while (iterator != end) {
    const std::filesystem::directory_entry candidate = *iterator;
    iterator.increment(filesystem_error);
    if (filesystem_error) {
      *error = FilesystemError("read", directory, filesystem_error);
      return false;
    }

    const std::string name = candidate.path().filename().string();
    const std::string folded = FoldCase(name);
    auto [current, inserted] = by_folded_name.emplace(folded, candidate);
    if (inserted) {
      continue;
    }

    const std::string current_name = current->second.path().filename().string();
    std::string preferred;
    if (!PreferredName(current_name, name, &preferred, error)) {
      *error = GenericPath(directory) + ": " + *error;
      return false;
    }
    if (preferred == name) {
      current->second = candidate;
    }
  }

  entries->clear();
  entries->reserve(by_folded_name.size());
  for (const auto &[folded_name, entry] : by_folded_name) {
    entries->push_back({entry, folded_name});
  }
  return true;
}

std::string GenericPath(const std::filesystem::path &path) {
  return path.generic_string();
}

std::string JsonString(std::string_view value) {
  std::ostringstream result;
  result << '"';
  for (unsigned char character : value) {
    switch (character) {
    case '"':
      result << "\\\"";
      break;
    case '\\':
      result << "\\\\";
      break;
    case '\b':
      result << "\\b";
      break;
    case '\f':
      result << "\\f";
      break;
    case '\n':
      result << "\\n";
      break;
    case '\r':
      result << "\\r";
      break;
    case '\t':
      result << "\\t";
      break;
    default:
      if (character < 0x20) {
        result << "\\u" << std::hex << std::setw(4) << std::setfill('0')
               << static_cast<unsigned int>(character) << std::dec;
      } else {
        result << static_cast<char>(character);
      }
    }
  }
  result << '"';
  return result.str();
}

} // namespace windows_case
