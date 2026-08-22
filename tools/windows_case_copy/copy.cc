#include "tools/windows_case_copy/copy.h"

#include <sstream>
#include <system_error>
#include <vector>

#include "tools/windows_case/common.h"

namespace windows_case_copy {
namespace {

std::string FilesystemError(std::string_view operation,
                            const std::filesystem::path &path,
                            const std::error_code &error) {
  std::ostringstream message;
  message << operation << " " << windows_case::GenericPath(path) << ": "
          << error.message();
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

  std::vector<windows_case::DirectoryEntry> entries;
  if (!windows_case::CollectPreferredEntries(source, &entries, error)) {
    return false;
  }

  for (const windows_case::DirectoryEntry &candidate : entries) {
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
      *error =
          "unsupported SDK entry " + windows_case::GenericPath(source_path);
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

} // namespace windows_case_copy
