#include "tools/case_insensitive_vfs/vfs.h"

#include <algorithm>
#include <sstream>
#include <system_error>
#include <utility>

#include "tools/case_insensitive_filesystem/common.h"

namespace case_insensitive_vfs {
namespace {

struct Entry {
  std::string type;
  std::string name;
  std::string external_contents;
  std::vector<Entry> contents;
};

std::string FilesystemError(std::string_view operation,
                            const std::filesystem::path &path,
                            const std::error_code &error) {
  std::ostringstream message;
  message << operation << " " << case_insensitive_filesystem::GenericPath(path)
          << ": " << error.message();
  return message.str();
}

bool DirectoryEntry(const std::filesystem::path &path,
                    const std::filesystem::path &virtual_name, Entry *result,
                    std::string *error) {
  std::vector<case_insensitive_filesystem::DirectoryEntry> entries;
  if (!case_insensitive_filesystem::CollectPreferredEntries(path, &entries,
                                                            error)) {
    return false;
  }

  result->type = "directory";
  result->name = case_insensitive_filesystem::GenericPath(virtual_name);
  for (const case_insensitive_filesystem::DirectoryEntry &candidate : entries) {
    const std::filesystem::path full_path = candidate.entry.path();
    std::error_code filesystem_error;
    const std::filesystem::file_status status =
        std::filesystem::status(full_path, filesystem_error);
    if (filesystem_error) {
      *error = FilesystemError("stat", full_path, filesystem_error);
      return false;
    }

    if (std::filesystem::is_directory(status)) {
      const std::filesystem::file_status link_status =
          std::filesystem::symlink_status(full_path, filesystem_error);
      if (filesystem_error) {
        *error = FilesystemError("lstat", full_path, filesystem_error);
        return false;
      }
      if (std::filesystem::is_symlink(link_status)) {
        *error = "unsupported SDK directory symlink " +
                 case_insensitive_filesystem::GenericPath(full_path);
        return false;
      }

      Entry child;
      if (!DirectoryEntry(full_path, full_path.filename(), &child, error)) {
        return false;
      }
      result->contents.push_back(std::move(child));
      continue;
    }
    if (!std::filesystem::is_regular_file(status)) {
      *error = "unsupported SDK entry " +
               case_insensitive_filesystem::GenericPath(full_path);
      return false;
    }

    result->contents.push_back(
        {"file",
         full_path.filename().string(),
         case_insensitive_filesystem::GenericPath(full_path),
         {}});
  }
  return true;
}

void Indent(std::ostringstream *output, int spaces) {
  *output << std::string(spaces, ' ');
}

void RenderEntry(const Entry &entry, int indentation,
                 std::ostringstream *output) {
  *output << "{\n";
  Indent(output, indentation + 2);
  *output << "\"type\": " << case_insensitive_filesystem::JsonString(entry.type)
          << ",\n";
  Indent(output, indentation + 2);
  *output << "\"name\": "
          << case_insensitive_filesystem::JsonString(entry.name);
  if (!entry.external_contents.empty()) {
    *output << ",\n";
    Indent(output, indentation + 2);
    *output << "\"external-contents\": "
            << case_insensitive_filesystem::JsonString(entry.external_contents);
  }
  if (!entry.contents.empty()) {
    *output << ",\n";
    Indent(output, indentation + 2);
    *output << "\"contents\": [\n";
    for (std::size_t index = 0; index < entry.contents.size(); ++index) {
      Indent(output, indentation + 4);
      RenderEntry(entry.contents[index], indentation + 4, output);
      if (index + 1 != entry.contents.size()) {
        *output << ',';
      }
      *output << '\n';
    }
    Indent(output, indentation + 2);
    *output << ']';
  }
  *output << '\n';
  Indent(output, indentation);
  *output << '}';
}

} // namespace

bool GenerateOverlay(const std::vector<std::filesystem::path> &roots,
                     std::string *overlay, std::string *error) {
  if (roots.empty()) {
    *error = "at least one -root is required";
    return false;
  }

  std::vector<std::filesystem::path> sorted_roots = roots;
  std::sort(sorted_roots.begin(), sorted_roots.end(),
            [](const std::filesystem::path &left,
               const std::filesystem::path &right) {
              return case_insensitive_filesystem::GenericPath(left) <
                     case_insensitive_filesystem::GenericPath(right);
            });

  std::vector<Entry> root_entries;
  root_entries.reserve(sorted_roots.size());
  for (const std::filesystem::path &root : sorted_roots) {
    Entry entry;
    if (!DirectoryEntry(root, root, &entry, error)) {
      *error = "walk " + case_insensitive_filesystem::GenericPath(root) + ": " +
               *error;
      return false;
    }
    root_entries.push_back(std::move(entry));
  }

  std::ostringstream output;
  output << "{\n"
         << "  \"version\": 0,\n"
         << "  \"case-sensitive\": false,\n"
         << "  \"use-external-names\": false,\n"
         << "  \"roots\": [\n";
  for (std::size_t index = 0; index < root_entries.size(); ++index) {
    output << "    ";
    RenderEntry(root_entries[index], 4, &output);
    if (index + 1 != root_entries.size()) {
      output << ',';
    }
    output << '\n';
  }
  output << "  ]\n}\n";
  *overlay = output.str();
  return true;
}

} // namespace case_insensitive_vfs
