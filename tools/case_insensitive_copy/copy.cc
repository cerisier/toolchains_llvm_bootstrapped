#include "tools/case_insensitive_copy/copy.h"

#include <sstream>
#include <system_error>
#include <vector>

#include "tools/case_insensitive_filesystem/common.h"

namespace case_insensitive_copy {
namespace {

std::string FilesystemError(std::string_view operation,
                            const std::filesystem::path &path,
                            const std::error_code &error) {
  std::ostringstream message;
  message << operation << " " << case_insensitive_filesystem::GenericPath(path)
          << ": " << error.message();
  return message.str();
}

} // namespace

bool CopyDirectory(const std::filesystem::path &source,
                   const std::filesystem::path &destination,
                   std::string *error) {
  std::error_code filesystem_error;
  std::filesystem::create_directories(destination, filesystem_error);
  if (filesystem_error) {
    *error = FilesystemError("create", destination, filesystem_error);
    return false;
  }

  std::vector<case_insensitive_filesystem::DirectoryEntry> entries;
  if (!case_insensitive_filesystem::CollectPreferredEntries(source, &entries,
                                                            error)) {
    return false;
  }

  for (const case_insensitive_filesystem::DirectoryEntry &candidate : entries) {
    const std::filesystem::path source_path = candidate.entry.path();
    const std::filesystem::file_status status =
        std::filesystem::status(source_path, filesystem_error);
    if (filesystem_error) {
      *error = FilesystemError("stat", source_path, filesystem_error);
      return false;
    }

    if (std::filesystem::is_directory(status)) {
      if (!CopyDirectory(source_path, destination / source_path.filename(),
                         error)) {
        return false;
      }
      continue;
    }
    if (!std::filesystem::is_regular_file(status)) {
      *error = "unsupported SDK entry " +
               case_insensitive_filesystem::GenericPath(source_path);
      return false;
    }

    const std::filesystem::path output = destination / candidate.folded_name;
    std::filesystem::copy_file(source_path, output,
                               std::filesystem::copy_options::none,
                               filesystem_error);
    if (filesystem_error) {
      *error = FilesystemError("copy", output, filesystem_error);
      return false;
    }
  }
  return true;
}

} // namespace case_insensitive_copy
