#ifndef HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_VFS_VFS_H_
#define HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_VFS_VFS_H_

#include <filesystem>
#include <string>
#include <vector>

namespace case_insensitive_vfs {

bool GenerateOverlay(const std::vector<std::filesystem::path> &roots,
                     std::string *overlay, std::string *error);

} // namespace case_insensitive_vfs

#endif // HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_VFS_VFS_H_
