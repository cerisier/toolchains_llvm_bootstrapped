#include "tools/case_insensitive_copy/copy.h"

#include <stdlib.h>

#include "tools/case_insensitive_filesystem/common.h"

int case_insensitive_copy_directory(const char *source, const char *destination,
                                    char **error) {
  struct ci_directory_entries entries;
  size_t index;

  if (!ci_create_directory(destination, error) ||
      !ci_collect_preferred_entries(source, &entries, error)) {
    return 0;
  }
  for (index = 0; index < entries.count; ++index) {
    const struct ci_directory_entry *entry = &entries.values[index];
    char *source_path = ci_join_path(source, entry->name);
    enum ci_path_type type;
    int is_symlink;

    if (!ci_path_info(source_path, &type, &is_symlink, error)) {
      free(source_path);
      ci_free_entries(&entries);
      return 0;
    }
    (void)is_symlink;
    if (type == CI_PATH_DIRECTORY) {
      char *destination_path = ci_join_path(destination, entry->name);
      int result =
          case_insensitive_copy_directory(source_path, destination_path, error);
      free(destination_path);
      free(source_path);
      if (!result) {
        ci_free_entries(&entries);
        return 0;
      }
      continue;
    }
    if (type == CI_PATH_REGULAR) {
      char *destination_path = ci_join_path(destination, entry->folded_name);
      int result = ci_copy_file_exclusive(source_path, destination_path, error);
      free(destination_path);
      free(source_path);
      if (!result) {
        ci_free_entries(&entries);
        return 0;
      }
      continue;
    }
    {
      char *generic = ci_generic_path(source_path);
      ci_set_error(error, "unsupported SDK entry %s", generic);
      free(generic);
    }
    free(source_path);
    ci_free_entries(&entries);
    return 0;
  }
  ci_free_entries(&entries);
  return 1;
}
