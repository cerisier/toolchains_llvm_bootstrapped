#ifndef HERMETIC_LLVM_TOOLS_WINDOWS_CASE_COPY_COPY_H_
#define HERMETIC_LLVM_TOOLS_WINDOWS_CASE_COPY_COPY_H_

#include <filesystem>
#include <string>

namespace windows_case_copy {

bool CopyDirectory(const std::filesystem::path &source,
                   const std::filesystem::path &destination,
                   std::string *error);

} // namespace windows_case_copy

#endif // HERMETIC_LLVM_TOOLS_WINDOWS_CASE_COPY_COPY_H_
