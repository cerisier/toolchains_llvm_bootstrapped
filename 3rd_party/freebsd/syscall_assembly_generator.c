#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct string_list {
  char **values;
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

static int starts_with(const char *value, const char *prefix) {
  return strncmp(value, prefix, strlen(prefix)) == 0;
}

static int ends_with(const char *value, const char *suffix) {
  size_t value_length = strlen(value);
  size_t suffix_length = strlen(suffix);
  return value_length >= suffix_length &&
         strcmp(value + value_length - suffix_length, suffix) == 0;
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
    if (length != 0 && line[length - 1] == '\n') {
      line[length - 1] = '\0';
      return line;
    }
    size *= 2;
    line = checked_realloc(line, size);
  }
}

static void add_string(struct string_list *list, const char *value) {
  if (list->count == list->capacity) {
    list->capacity = list->capacity == 0 ? 32 : list->capacity * 2;
    list->values = checked_realloc(list->values,
                                   list->capacity * sizeof(*list->values));
  }
  list->values[list->count++] = copy_string(value);
}

static int contains(const struct string_list *list, const char *value) {
  for (size_t index = 0; index < list->count; ++index)
    if (strcmp(list->values[index], value) == 0)
      return 1;
  return 0;
}

static int compare_strings(const void *left, const void *right) {
  const char *const *left_string = left;
  const char *const *right_string = right;
  return strcmp(*left_string, *right_string);
}

static void add_words(struct string_list *list, char *line, int skip_variables) {
  for (char *word = strtok(line, " \t"); word != NULL;
       word = strtok(NULL, " \t")) {
    if (!skip_variables || word[0] != '$')
      add_string(list, word);
  }
}

static struct string_list read_variable(const char *path,
                                        const char *const *names,
                                        size_t name_count) {
  struct string_list result = {0};
  FILE *input = fopen(path, "r");
  if (input == NULL) {
    perror(path);
    exit(1);
  }
  int collecting = 0;
  char *line;
  while ((line = read_line(input)) != NULL) {
    if (!collecting) {
      char *equal = NULL;
      for (size_t index = 0; index < name_count; ++index) {
        if (starts_with(line, names[index])) {
          equal = strchr(line, '=');
          if (equal != NULL) {
            line = equal + 1;
            break;
          }
        }
      }
      if (equal == NULL)
        continue;
    }
    size_t length = strlen(line);
    collecting = length != 0 && line[length - 1] == '\\';
    if (collecting)
      line[length - 1] = '\0';
    add_words(&result, line, 1);
  }
  fclose(input);
  return result;
}

static struct string_list read_assignment(const char *path, const char *name) {
  struct string_list result = {0};
  FILE *input = fopen(path, "r");
  if (input == NULL) {
    perror(path);
    exit(1);
  }
  int collecting = 0;
  char *line;
  while ((line = read_line(input)) != NULL) {
    if (!collecting) {
      size_t name_length = strlen(name);
      if (!starts_with(line, name) || line[name_length] == '\0' ||
          (line[name_length] != ' ' && line[name_length] != '\t' &&
           line[name_length] != '='))
        continue;
      char *equal = strchr(line, '=');
      if (equal == NULL || (equal != line && equal[-1] == '+'))
        continue;
      line = equal + 1;
    }
    size_t length = strlen(line);
    collecting = length != 0 && line[length - 1] == '\\';
    if (collecting)
      line[length - 1] = '\0';
    add_words(&result, line, 0);
    if (!collecting)
      break;
  }
  fclose(input);
  return result;
}

static void strip_suffix(char *value, const char *suffix) {
  if (ends_with(value, suffix))
    value[strlen(value) - strlen(suffix)] = '\0';
}

static void emit(FILE *output, const char *kind, const char *name) {
  fprintf(output, "%s(%s)\n", kind, name);
}

int main(int argc, char **argv) {
  if (argc != 8) {
    fputs("usage: syscall_assembly_generator MODE ARCH OUTPUT "
          "SYSCALL_MK LIBSYS_MK ARCH_MK RTLD_MK\n",
          stderr);
    return 1;
  }
  FILE *output = fopen(argv[3], "w");
  if (output == NULL) {
    perror(argv[3]);
    return 1;
  }
  fputs("/* Generated from FreeBSD libsys and rtld make metadata. */\n"
        "#include \"compat.h\"\n"
        "#include \"SYS.h\"\n",
        output);
  if (strcmp(argv[1], "libsys") == 0) {
    const char *pseudo_names[] = {"PSEUDO", "INTERPOSED"};
    const char *mdasm_name[] = {"MDASM"};
    const char *miasm_name[] = {"MIASM"};
    struct string_list pseudo = read_variable(argv[5], pseudo_names, 2);
    qsort(pseudo.values, pseudo.count, sizeof(*pseudo.values), compare_strings);
    for (size_t index = 0; index < pseudo.count; ++index)
      emit(output, "PSEUDO", pseudo.values[index]);
    struct string_list machine_dependent =
        read_variable(argv[6], mdasm_name, 1);
    for (size_t index = 0; index < machine_dependent.count; ++index)
      strip_suffix(machine_dependent.values[index], ".S");
    struct string_list machine_independent =
        read_variable(argv[4], miasm_name, 1);
    for (size_t index = 0; index < machine_independent.count; ++index) {
      char *name = machine_independent.values[index];
      strip_suffix(name, ".o");
      if (strcmp(argv[2], "aarch64") == 0 &&
          (starts_with(name, "freebsd4_") || starts_with(name, "freebsd6_") ||
           starts_with(name, "freebsd7_")))
        continue;
      if (!contains(&machine_dependent, name) && !contains(&pseudo, name))
        emit(output, "RSYSCALL", name);
    }
  } else if (strcmp(argv[1], "rtld") == 0) {
    struct string_list names = read_assignment(argv[7], "_libsys_other_objects");
    for (size_t index = 0; index < names.count; ++index) {
      char *name = names.values[index];
      if (strcmp(name, "___realpathat") == 0) {
        emit(output, "PSEUDO", "__realpathat");
      } else if (name[0] == '_' && strcmp(name, "__sysctl") != 0 &&
                 strcmp(name, "__getcwd") != 0 && strcmp(name, "_exit") != 0) {
        emit(output, "PSEUDO", name + 1);
      } else if (strcmp(name, "cerror") != 0) {
        emit(output, "RSYSCALL", name);
      }
    }
  } else {
    fprintf(stderr, "unknown mode: %s\n", argv[1]);
    fclose(output);
    return 1;
  }
  fputs("\t.section .note.GNU-stack,\"\",%progbits\n", output);
  if (strcmp(argv[2], "aarch64") == 0)
    fputs("#include <sys/elf_common.h>\n"
          "GNU_PROPERTY_AARCH64_FEATURE_1_NOTE("
          "GNU_PROPERTY_AARCH64_FEATURE_1_VAL)\n",
          output);
  return fclose(output) == 0 ? 0 : 1;
}
