#ifndef HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_FILESYSTEM_COMMON_H_
#define HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_FILESYSTEM_COMMON_H_

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

struct ci_directory_entry {
  char *name;
  char *folded_name;
};

struct ci_directory_entries {
  struct ci_directory_entry *values;
  size_t count;
};

enum ci_path_type {
  CI_PATH_REGULAR,
  CI_PATH_DIRECTORY,
  CI_PATH_OTHER,
};

void *ci_xmalloc(size_t size);
void *ci_xrealloc(void *pointer, size_t size);
char *ci_xstrdup(const char *value);
void ci_set_error(char **error, const char *format, ...);

char *ci_fold_case(const char *value);
int ci_preferred_name(const char *left, const char *right, char **preferred,
                      char **error);
int ci_collect_preferred_entries(const char *directory,
                                 struct ci_directory_entries *entries,
                                 char **error);
void ci_free_entries(struct ci_directory_entries *entries);

char *ci_join_path(const char *left, const char *right);
char *ci_generic_path(const char *path);
char *ci_json_string(const char *value);
int ci_path_info(const char *path, enum ci_path_type *type, int *is_symlink,
                 char **error);
int ci_create_directory(const char *path, char **error);
int ci_copy_file_exclusive(const char *source, const char *destination,
                           char **error);

#ifdef __cplusplus
}
#endif

#endif // HERMETIC_LLVM_TOOLS_CASE_INSENSITIVE_FILESYSTEM_COMMON_H_
