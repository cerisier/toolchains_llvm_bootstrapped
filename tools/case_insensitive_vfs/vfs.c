#include "tools/case_insensitive_vfs/vfs.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tools/case_insensitive_filesystem/common.h"

struct text_buffer {
  char *data;
  size_t length;
  size_t capacity;
};

struct root_entry {
  char *path;
  char *generic;
};

static void buffer_reserve(struct text_buffer *buffer, size_t extra) {
  size_t needed = buffer->length + extra + 1;
  size_t capacity = buffer->capacity == 0 ? 4096 : buffer->capacity;
  if (needed <= buffer->capacity) {
    return;
  }
  while (capacity < needed) {
    capacity *= 2;
  }
  buffer->data = ci_xrealloc(buffer->data, capacity);
  buffer->capacity = capacity;
}

static void buffer_append_n(struct text_buffer *buffer, const char *value,
                            size_t size) {
  buffer_reserve(buffer, size);
  memcpy(buffer->data + buffer->length, value, size);
  buffer->length += size;
  buffer->data[buffer->length] = '\0';
}

static void buffer_append(struct text_buffer *buffer, const char *value) {
  buffer_append_n(buffer, value, strlen(value));
}

static void buffer_append_format(struct text_buffer *buffer, const char *format,
                                 ...) {
  va_list arguments;
  va_list copy;
  int length;
  va_start(arguments, format);
  va_copy(copy, arguments);
  length = vsnprintf(NULL, 0, format, copy);
  va_end(copy);
  if (length < 0) {
    va_end(arguments);
    fprintf(stderr, "case_insensitive_vfs: failed to format output\n");
    exit(2);
  }
  buffer_reserve(buffer, (size_t)length);
  vsnprintf(buffer->data + buffer->length, buffer->capacity - buffer->length,
            format, arguments);
  va_end(arguments);
  buffer->length += (size_t)length;
}

static void buffer_indent(struct text_buffer *buffer, size_t spaces) {
  while (spaces-- != 0) {
    buffer_append_n(buffer, " ", 1);
  }
}

static int render_directory(const char *path, const char *virtual_name,
                            struct text_buffer *output, size_t indentation,
                            char **error) {
  struct ci_directory_entries entries;
  size_t index;
  char *json_type;
  char *json_name;

  if (!ci_collect_preferred_entries(path, &entries, error)) {
    return 0;
  }
  json_type = ci_json_string("directory");
  json_name = ci_json_string(virtual_name);
  buffer_append(output, "{\n");
  buffer_indent(output, indentation + 2);
  buffer_append_format(output, "\"type\": %s,\n", json_type);
  buffer_indent(output, indentation + 2);
  buffer_append_format(output, "\"name\": %s", json_name);
  free(json_type);
  free(json_name);

  if (entries.count != 0) {
    buffer_append(output, ",\n");
    buffer_indent(output, indentation + 2);
    buffer_append(output, "\"contents\": [\n");
  }
  for (index = 0; index < entries.count; ++index) {
    const struct ci_directory_entry *entry = &entries.values[index];
    char *full_path = ci_join_path(path, entry->name);
    enum ci_path_type type;
    int is_symlink;

    buffer_indent(output, indentation + 4);
    if (!ci_path_info(full_path, &type, &is_symlink, error)) {
      free(full_path);
      ci_free_entries(&entries);
      return 0;
    }
    if (type == CI_PATH_DIRECTORY) {
      if (is_symlink) {
        char *generic = ci_generic_path(full_path);
        ci_set_error(error, "unsupported SDK directory symlink %s", generic);
        free(generic);
        free(full_path);
        ci_free_entries(&entries);
        return 0;
      }
      if (!render_directory(full_path, entry->name, output, indentation + 4,
                            error)) {
        free(full_path);
        ci_free_entries(&entries);
        return 0;
      }
    } else if (type == CI_PATH_REGULAR) {
      char *generic = ci_generic_path(full_path);
      char *file_type = ci_json_string("file");
      char *name = ci_json_string(entry->name);
      char *external = ci_json_string(generic);
      buffer_append(output, "{\n");
      buffer_indent(output, indentation + 6);
      buffer_append_format(output, "\"type\": %s,\n", file_type);
      buffer_indent(output, indentation + 6);
      buffer_append_format(output, "\"name\": %s,\n", name);
      buffer_indent(output, indentation + 6);
      buffer_append_format(output, "\"external-contents\": %s\n", external);
      buffer_indent(output, indentation + 4);
      buffer_append(output, "}");
      free(generic);
      free(file_type);
      free(name);
      free(external);
    } else {
      char *generic = ci_generic_path(full_path);
      ci_set_error(error, "unsupported SDK entry %s", generic);
      free(generic);
      free(full_path);
      ci_free_entries(&entries);
      return 0;
    }
    free(full_path);
    if (index + 1 != entries.count) {
      buffer_append(output, ",");
    }
    buffer_append(output, "\n");
  }
  if (entries.count != 0) {
    buffer_indent(output, indentation + 2);
    buffer_append(output, "]");
  }
  buffer_append(output, "\n");
  buffer_indent(output, indentation);
  buffer_append(output, "}");
  ci_free_entries(&entries);
  return 1;
}

static int compare_roots(const void *left, const void *right) {
  const struct root_entry *left_root = left;
  const struct root_entry *right_root = right;
  return strcmp(left_root->generic, right_root->generic);
}

int case_insensitive_vfs_generate(const char *const *roots, size_t root_count,
                                  char **overlay, char **error) {
  struct text_buffer output = {NULL, 0, 0};
  struct root_entry *sorted_roots;
  size_t index;

  free(*overlay);
  *overlay = NULL;
  if (root_count == 0) {
    ci_set_error(error, "at least one -root is required");
    return 0;
  }
  sorted_roots = ci_xmalloc(root_count * sizeof(*sorted_roots));
  for (index = 0; index < root_count; ++index) {
    sorted_roots[index].path = ci_xstrdup(roots[index]);
    sorted_roots[index].generic = ci_generic_path(roots[index]);
  }
  qsort(sorted_roots, root_count, sizeof(*sorted_roots), compare_roots);

  buffer_append(&output, "{\n"
                         "  \"version\": 0,\n"
                         "  \"case-sensitive\": false,\n"
                         "  \"use-external-names\": false,\n"
                         "  \"roots\": [\n");
  for (index = 0; index < root_count; ++index) {
    buffer_indent(&output, 4);
    if (!render_directory(sorted_roots[index].path, sorted_roots[index].generic,
                          &output, 4, error)) {
      char *detail = ci_xstrdup(*error);
      ci_set_error(error, "walk %s: %s", sorted_roots[index].generic, detail);
      free(detail);
      free(output.data);
      size_t cleanup_index;
      for (cleanup_index = 0; cleanup_index < root_count; ++cleanup_index) {
        free(sorted_roots[cleanup_index].path);
        free(sorted_roots[cleanup_index].generic);
      }
      free(sorted_roots);
      return 0;
    }
    if (index + 1 != root_count) {
      buffer_append(&output, ",");
    }
    buffer_append(&output, "\n");
  }
  buffer_append(&output, "  ]\n}\n");
  for (index = 0; index < root_count; ++index) {
    free(sorted_roots[index].path);
    free(sorted_roots[index].generic);
  }
  free(sorted_roots);
  *overlay = output.data;
  return 1;
}
