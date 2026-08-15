#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct string_list {
  char **values;
  size_t count;
  size_t capacity;
};

struct version {
  char *name;
  char *successor;
  struct string_list symbols;
  int written;
};

struct version_list {
  struct version *values;
  size_t count;
  size_t capacity;
};

struct symbol {
  char *name;
  const char *version;
};

struct symbol_list {
  struct symbol *values;
  size_t count;
  size_t capacity;
};

static void *checked_realloc(void *pointer, size_t size) {
  void *result = realloc(pointer, size);
  if (result == NULL) {
    fputs("out of memory\n", stderr);
    exit(1);
  }
  return result;
}

static char *copy_string(const char *value) {
  size_t size = strlen(value) + 1;
  char *result = checked_realloc(NULL, size);
  memcpy(result, value, size);
  return result;
}

static char *trim(char *value) {
  while (isspace((unsigned char)*value))
    ++value;
  char *end = value + strlen(value);
  while (end != value && isspace((unsigned char)end[-1]))
    --end;
  *end = '\0';
  return value;
}

static char *read_line(FILE *input) {
  size_t size = 256;
  size_t length = 0;
  char *line = checked_realloc(NULL, size);
  for (;;) {
    if (fgets(line + length, (int)(size - length), input) == NULL) {
      if (length == 0) {
        free(line);
        return NULL;
      }
      return line;
    }
    length += strlen(line + length);
    if (length != 0 && line[length - 1] == '\n')
      return line;
    size *= 2;
    line = checked_realloc(line, size);
  }
}

static void add_string(struct string_list *list, const char *value) {
  if (list->count == list->capacity) {
    list->capacity = list->capacity == 0 ? 16 : list->capacity * 2;
    list->values = checked_realloc(list->values,
                                   list->capacity * sizeof(*list->values));
  }
  list->values[list->count++] = copy_string(value);
}

static struct version *find_version(struct version_list *versions,
                                    const char *name) {
  for (size_t index = 0; index < versions->count; ++index)
    if (strcmp(versions->values[index].name, name) == 0)
      return &versions->values[index];
  return NULL;
}

static struct version *add_version(struct version_list *versions,
                                   const char *name) {
  struct version *existing = find_version(versions, name);
  if (existing != NULL)
    return existing;
  if (versions->count == versions->capacity) {
    versions->capacity = versions->capacity == 0 ? 16 : versions->capacity * 2;
    versions->values = checked_realloc(
        versions->values, versions->capacity * sizeof(*versions->values));
  }
  struct version *version = &versions->values[versions->count++];
  memset(version, 0, sizeof(*version));
  version->name = copy_string(name);
  return version;
}

static int read_versions(const char *path, struct version_list *versions) {
  FILE *input = fopen(path, "r");
  if (input == NULL) {
    perror(path);
    return 0;
  }
  struct version *current = NULL;
  char *line;
  while ((line = read_line(input)) != NULL) {
    char *comment = strchr(line, '#');
    if (comment != NULL)
      *comment = '\0';
    char *value = trim(line);
    size_t length = strlen(value);
    if (length == 0) {
      free(line);
      continue;
    }
    if (value[length - 1] == '{') {
      value[length - 1] = '\0';
      current = add_version(versions, trim(value));
    } else if (current != NULL && value[0] == '}' && value[length - 1] == ';') {
      value[length - 1] = '\0';
      value = trim(value + 1);
      if (*value != '\0')
        current->successor = copy_string(value);
      current = NULL;
    } else {
      fprintf(stderr, "%s: unknown version directive: %s\n", path, value);
      free(line);
      fclose(input);
      return 0;
    }
    free(line);
  }
  fclose(input);
  return versions->count != 0;
}

static int add_symbol(struct symbol_list *symbols, const char *name,
                      const char *version, const char *path) {
  for (size_t index = 0; index < symbols->count; ++index) {
    if (strcmp(symbols->values[index].name, name) != 0)
      continue;
    if (strcmp(symbols->values[index].version, version) != 0) {
      fprintf(stderr, "%s: symbol %s occurs in %s and %s\n", path, name,
              version, symbols->values[index].version);
      return 0;
    }
    return 1;
  }
  if (symbols->count == symbols->capacity) {
    symbols->capacity = symbols->capacity == 0 ? 64 : symbols->capacity * 2;
    symbols->values = checked_realloc(
        symbols->values, symbols->capacity * sizeof(*symbols->values));
  }
  symbols->values[symbols->count].name = copy_string(name);
  symbols->values[symbols->count].version = version;
  ++symbols->count;
  return 1;
}

static int read_symbols(const char *path, struct version_list *versions,
                        struct symbol_list *symbols) {
  FILE *input = fopen(path, "r");
  if (input == NULL) {
    perror(path);
    return 0;
  }
  struct version *current = NULL;
  char *line;
  while ((line = read_line(input)) != NULL) {
    char *comment = strchr(line, '#');
    if (comment != NULL)
      *comment = '\0';
    char *value = trim(line);
    size_t length = strlen(value);
    if (length == 0) {
      free(line);
      continue;
    }
    if (value[length - 1] == '{') {
      value[length - 1] = '\0';
      current = find_version(versions, trim(value));
      if (current == NULL) {
        fprintf(stderr, "%s: undefined version %s\n", path, trim(value));
        free(line);
        fclose(input);
        return 0;
      }
    } else if (strcmp(value, "};") == 0) {
      current = NULL;
    } else if (current != NULL && value[length - 1] == ';') {
      value[length - 1] = '\0';
      value = trim(value);
      if (!add_symbol(symbols, value, current->name, path)) {
        free(line);
        fclose(input);
        return 0;
      }
      add_string(&current->symbols, value);
    } else {
      fprintf(stderr, "%s: unknown symbol directive: %s\n", path, value);
      free(line);
      fclose(input);
      return 0;
    }
    free(line);
  }
  fclose(input);
  return 1;
}

static int compare_versions(const void *left, const void *right) {
  const struct version *const *left_version = left;
  const struct version *const *right_version = right;
  return strcmp((*left_version)->name, (*right_version)->name);
}

static int write_version(struct version *version,
                         struct version_list *versions, FILE *output,
                         size_t *remaining) {
  if (version->written)
    return 1;
  if (version->successor != NULL) {
    struct version *successor = find_version(versions, version->successor);
    if (successor == NULL || !write_version(successor, versions, output, remaining))
      return 0;
  }
  fprintf(output, "%s {\n", version->name);
  if (version->symbols.count != 0) {
    fputs("global:\n", output);
    for (size_t index = 0; index < version->symbols.count; ++index)
      fprintf(output, "\t%s;\n", version->symbols.values[index]);
  }
  if (--*remaining == 0)
    fputs("local:\n\t*;\n", output);
  fputc('}', output);
  if (version->successor != NULL)
    fprintf(output, " %s", version->successor);
  fputs(";\n\n", output);
  version->written = 1;
  return 1;
}

int main(int argc, char **argv) {
  if (argc < 4) {
    fputs("usage: version_script_generator VERSIONS OUTPUT SYMBOL...\n", stderr);
    return 1;
  }
  struct version_list versions = {0};
  struct symbol_list symbols = {0};
  if (!read_versions(argv[1], &versions))
    return 1;
  for (int index = 3; index < argc; ++index)
    if (!read_symbols(argv[index], &versions, &symbols))
      return 1;
  struct version **ordered = checked_realloc(NULL, versions.count * sizeof(*ordered));
  for (size_t index = 0; index < versions.count; ++index)
    ordered[index] = &versions.values[index];
  qsort(ordered, versions.count, sizeof(*ordered), compare_versions);
  FILE *output = fopen(argv[2], "w");
  if (output == NULL) {
    perror(argv[2]);
    return 1;
  }
  size_t remaining = versions.count;
  for (size_t index = 0; index < versions.count; ++index)
    if (!write_version(ordered[index], &versions, output, &remaining))
      return 1;
  return fclose(output) == 0 ? 0 : 1;
}
