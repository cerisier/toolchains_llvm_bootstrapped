#ifndef HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_VFS_VFS_H_
#define HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_VFS_VFS_H_

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int case_insensitive_vfs_generate(const char *const *roots, size_t root_count,
                                  char **overlay, char **error);

#ifdef __cplusplus
}
#endif

#endif // HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_VFS_VFS_H_
