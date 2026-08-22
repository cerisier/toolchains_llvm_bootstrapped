#ifndef HERMETIC_LLVM_TOOLS_WINDOWS_CASE_VFS_VFS_H_
#define HERMETIC_LLVM_TOOLS_WINDOWS_CASE_VFS_VFS_H_

#include <filesystem>
#include <string>
#include <vector>

namespace windows_case_vfs {

bool GenerateOverlay(const std::vector<std::filesystem::path> &roots,
                     std::string *overlay, std::string *error);

} // namespace windows_case_vfs

#endif // HERMETIC_LLVM_TOOLS_WINDOWS_CASE_VFS_VFS_H_
