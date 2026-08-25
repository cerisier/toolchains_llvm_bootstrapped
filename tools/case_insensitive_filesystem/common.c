#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L
#endif

#include "tools/case_insensitive_filesystem/common.h"

#include <ctype.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#include <sys/stat.h>
#include <windows.h>
#else
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#endif

void *ci_xmalloc(size_t size) {
  void *pointer = malloc(size == 0 ? 1 : size);
  if (pointer == NULL) {
    fprintf(stderr, "case-insensitive filesystem helper: out of memory\n");
    exit(2);
  }
  return pointer;
}

void *ci_xrealloc(void *pointer, size_t size) {
  void *result = realloc(pointer, size == 0 ? 1 : size);
  if (result == NULL) {
    fprintf(stderr, "case-insensitive filesystem helper: out of memory\n");
    exit(2);
  }
  return result;
}

char *ci_xstrdup(const char *value) {
  size_t size = strlen(value) + 1;
  char *result = ci_xmalloc(size);
  memcpy(result, value, size);
  return result;
}

void ci_set_error(char **error, const char *format, ...) {
  va_list arguments;
  va_list copy;
  int length;

  free(*error);
  *error = NULL;
  va_start(arguments, format);
  va_copy(copy, arguments);
  length = vsnprintf(NULL, 0, format, copy);
  va_end(copy);
  if (length < 0) {
    va_end(arguments);
    *error = ci_xstrdup("failed to format error");
    return;
  }
  *error = ci_xmalloc((size_t)length + 1);
  vsnprintf(*error, (size_t)length + 1, format, arguments);
  va_end(arguments);
}

char *ci_fold_case(const char *value) {
  size_t index;
  size_t size = strlen(value);
  char *result = ci_xmalloc(size + 1);
  for (index = 0; index < size; ++index) {
    result[index] = (char)tolower((unsigned char)value[index]);
  }
  result[size] = '\0';
  return result;
}

int ci_preferred_name(const char *left, const char *right, char **preferred,
                      char **error) {
  char *folded_left = ci_fold_case(left);
  char *folded_right = ci_fold_case(right);
  int result = 0;

  free(*preferred);
  *preferred = NULL;
  if (strcmp(folded_left, folded_right) != 0) {
    ci_set_error(error, "internal case-fold mismatch: \"%s\" and \"%s\"", left,
                 right);
  } else if (strcmp(left, folded_left) == 0) {
    *preferred = ci_xstrdup(left);
    result = 1;
  } else if (strcmp(right, folded_left) == 0) {
    *preferred = ci_xstrdup(right);
    result = 1;
  } else {
    ci_set_error(error,
                 "ambiguous case-insensitive SDK entries \"%s\" and \"%s\"",
                 left, right);
  }
  free(folded_left);
  free(folded_right);
  return result;
}

static int compare_entries(const void *left, const void *right) {
  const struct ci_directory_entry *left_entry = left;
  const struct ci_directory_entry *right_entry = right;
  return strcmp(left_entry->folded_name, right_entry->folded_name);
}

static int add_entry(struct ci_directory_entries *entries, const char *name,
                     const char *directory, char **error) {
  size_t index;
  char *folded = ci_fold_case(name);
  for (index = 0; index < entries->count; ++index) {
    struct ci_directory_entry *current = &entries->values[index];
    if (strcmp(current->folded_name, folded) == 0) {
      char *preferred = NULL;
      if (!ci_preferred_name(current->name, name, &preferred, error)) {
        char *detail = ci_xstrdup(*error);
        ci_set_error(error, "%s: %s", directory, detail);
        free(detail);
        free(folded);
        return 0;
      }
      if (strcmp(preferred, name) == 0) {
        free(current->name);
        current->name = ci_xstrdup(name);
      }
      free(preferred);
      free(folded);
      return 1;
    }
  }

  entries->values = ci_xrealloc(entries->values, (entries->count + 1) *
                                                     sizeof(*entries->values));
  entries->values[entries->count].name = ci_xstrdup(name);
  entries->values[entries->count].folded_name = folded;
  entries->count++;
  return 1;
}

int ci_collect_preferred_entries(const char *directory,
                                 struct ci_directory_entries *entries,
                                 char **error) {
  entries->values = NULL;
  entries->count = 0;
#ifdef _WIN32
  WIN32_FIND_DATAA data;
  char *pattern = ci_join_path(directory, "*");
  HANDLE handle = FindFirstFileA(pattern, &data);
  free(pattern);
  if (handle == INVALID_HANDLE_VALUE) {
    DWORD code = GetLastError();
    if (code == ERROR_FILE_NOT_FOUND) {
      return 1;
    }
    ci_set_error(error, "read %s: Windows error %lu", directory,
                 (unsigned long)code);
    return 0;
  }
  do {
    if (strcmp(data.cFileName, ".") != 0 && strcmp(data.cFileName, "..") != 0 &&
        !add_entry(entries, data.cFileName, directory, error)) {
      FindClose(handle);
      ci_free_entries(entries);
      return 0;
    }
  } while (FindNextFileA(handle, &data));
  if (GetLastError() != ERROR_NO_MORE_FILES) {
    DWORD code = GetLastError();
    FindClose(handle);
    ci_set_error(error, "read %s: Windows error %lu", directory,
                 (unsigned long)code);
    ci_free_entries(entries);
    return 0;
  }
  FindClose(handle);
#else
  DIR *stream = opendir(directory);
  struct dirent *entry;
  if (stream == NULL) {
    ci_set_error(error, "read %s: %s", directory, strerror(errno));
    return 0;
  }
  errno = 0;
  while ((entry = readdir(stream)) != NULL) {
    if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0 &&
        !add_entry(entries, entry->d_name, directory, error)) {
      closedir(stream);
      ci_free_entries(entries);
      return 0;
    }
    errno = 0;
  }
  if (errno != 0) {
    int code = errno;
    closedir(stream);
    ci_set_error(error, "read %s: %s", directory, strerror(code));
    ci_free_entries(entries);
    return 0;
  }
  closedir(stream);
#endif
  if (entries->count > 1) {
    qsort(entries->values, entries->count, sizeof(*entries->values),
          compare_entries);
  }
  return 1;
}

void ci_free_entries(struct ci_directory_entries *entries) {
  size_t index;
  for (index = 0; index < entries->count; ++index) {
    free(entries->values[index].name);
    free(entries->values[index].folded_name);
  }
  free(entries->values);
  entries->values = NULL;
  entries->count = 0;
}

char *ci_join_path(const char *left, const char *right) {
  size_t left_size = strlen(left);
  size_t right_size = strlen(right);
  int separator = left_size != 0 && left[left_size - 1] != '/' &&
                  left[left_size - 1] != '\\';
  char *result = ci_xmalloc(left_size + (size_t)separator + right_size + 1);
  memcpy(result, left, left_size);
  if (separator) {
    result[left_size++] = '/';
  }
  memcpy(result + left_size, right, right_size + 1);
  return result;
}

char *ci_generic_path(const char *path) {
  size_t index;
  char *result = ci_xstrdup(path);
  for (index = 0; result[index] != '\0'; ++index) {
    if (result[index] == '\\') {
      result[index] = '/';
    }
  }
  return result;
}

char *ci_json_string(const char *value) {
  static const char hex[] = "0123456789abcdef";
  size_t index;
  size_t size = 3;
  char *result;
  size_t offset = 0;
  for (index = 0; value[index] != '\0'; ++index) {
    unsigned char character = (unsigned char)value[index];
    size += character < 0x20                          ? 6
            : (character == '"' || character == '\\') ? 2
                                                      : 1;
  }
  result = ci_xmalloc(size);
  result[offset++] = '"';
  for (index = 0; value[index] != '\0'; ++index) {
    unsigned char character = (unsigned char)value[index];
    const char *escape = NULL;
    switch (character) {
    case '"':
      escape = "\\\"";
      break;
    case '\\':
      escape = "\\\\";
      break;
    case '\b':
      escape = "\\b";
      break;
    case '\f':
      escape = "\\f";
      break;
    case '\n':
      escape = "\\n";
      break;
    case '\r':
      escape = "\\r";
      break;
    case '\t':
      escape = "\\t";
      break;
    default:
      break;
    }
    if (escape != NULL) {
      result[offset++] = escape[0];
      result[offset++] = escape[1];
    } else if (character < 0x20) {
      result[offset++] = '\\';
      result[offset++] = 'u';
      result[offset++] = '0';
      result[offset++] = '0';
      result[offset++] = hex[character >> 4];
      result[offset++] = hex[character & 0xf];
    } else {
      result[offset++] = (char)character;
    }
  }
  result[offset++] = '"';
  result[offset] = '\0';
  return result;
}

int ci_path_info(const char *path, enum ci_path_type *type, int *is_symlink,
                 char **error) {
#ifdef _WIN32
  DWORD attributes = GetFileAttributesA(path);
  if (attributes == INVALID_FILE_ATTRIBUTES) {
    ci_set_error(error, "stat %s: Windows error %lu", path,
                 (unsigned long)GetLastError());
    return 0;
  }
  *is_symlink = (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
  *type = (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0 ? CI_PATH_DIRECTORY
                                                       : CI_PATH_REGULAR;
#else
  struct stat link_status;
  struct stat status;
  if (lstat(path, &link_status) != 0 || stat(path, &status) != 0) {
    ci_set_error(error, "stat %s: %s", path, strerror(errno));
    return 0;
  }
  *is_symlink = S_ISLNK(link_status.st_mode);
  *type = S_ISDIR(status.st_mode)   ? CI_PATH_DIRECTORY
          : S_ISREG(status.st_mode) ? CI_PATH_REGULAR
                                    : CI_PATH_OTHER;
#endif
  return 1;
}

int ci_create_directory(const char *path, char **error) {
#ifdef _WIN32
  if (CreateDirectoryA(path, NULL)) {
    return 1;
  }
  {
    DWORD code = GetLastError();
    if (code == ERROR_ALREADY_EXISTS) {
      DWORD attributes = GetFileAttributesA(path);
      if (attributes != INVALID_FILE_ATTRIBUTES &&
          (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
        return 1;
      }
    }
    ci_set_error(error, "create %s: Windows error %lu", path,
                 (unsigned long)code);
  }
#else
  if (mkdir(path, 0777) == 0) {
    return 1;
  }
  {
    int code = errno;
    if (code == EEXIST) {
      struct stat status;
      if (stat(path, &status) == 0 && S_ISDIR(status.st_mode)) {
        return 1;
      }
    }
    ci_set_error(error, "create %s: %s", path, strerror(code));
  }
#endif
  return 0;
}

int ci_copy_file_exclusive(const char *source, const char *destination,
                           char **error) {
  FILE *input;
  FILE *output;
  char buffer[65536];
  int descriptor;
  int result = 0;

  input = fopen(source, "rb");
  if (input == NULL) {
    ci_set_error(error, "copy %s: %s", source, strerror(errno));
    return 0;
  }
#ifdef _WIN32
  descriptor = _open(destination, _O_WRONLY | _O_CREAT | _O_EXCL | _O_BINARY,
                     _S_IREAD | _S_IWRITE);
  output = descriptor < 0 ? NULL : _fdopen(descriptor, "wb");
#else
  descriptor = open(destination, O_WRONLY | O_CREAT | O_EXCL, 0666);
  output = descriptor < 0 ? NULL : fdopen(descriptor, "wb");
#endif
  if (output == NULL) {
    if (descriptor >= 0) {
#ifdef _WIN32
      _close(descriptor);
#else
      close(descriptor);
#endif
    }
    ci_set_error(error, "copy %s: %s", destination, strerror(errno));
    fclose(input);
    return 0;
  }
  while (!feof(input)) {
    size_t count = fread(buffer, 1, sizeof(buffer), input);
    if ((count != 0 && fwrite(buffer, 1, count, output) != count) ||
        ferror(input)) {
      ci_set_error(error, "copy %s: %s", destination, strerror(errno));
      goto done;
    }
  }
  result = 1;
done:
  if (fclose(output) != 0 && result) {
    ci_set_error(error, "copy %s: %s", destination, strerror(errno));
    result = 0;
  }
  fclose(input);
  if (!result) {
    remove(destination);
  }
  return result;
}
