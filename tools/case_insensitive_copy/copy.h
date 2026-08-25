#ifndef HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_COPY_COPY_H_
#define HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_COPY_COPY_H_

#include <filesystem>
#include <string>

namespace case_insensitive_copy {

bool CopyDirectory(const std::filesystem::path &source,
                   const std::filesystem::path &destination,
                   std::string *error);

} // namespace case_insensitive_copy

#endif // HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_COPY_COPY_H_
