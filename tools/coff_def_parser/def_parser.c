/* Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
   file Copyright.txt or https://cmake.org/licensing for details.  */
/*-------------------------------------------------------------------------
  Portions of this source have been derived from the 'bindexplib' tool
  provided by the CERN ROOT Data Analysis Framework project (root.cern.ch).
  Permission has been granted by Pere Mato <pere.mato@cern.ch> to distribute
  this derived work under the CMake license.
-------------------------------------------------------------------------*/

/*
 * Behavior derived from bazelbuild/bazel third_party/def_parser at parser
 * revision 56d21d61f551e5a48f56771c1748ed05751f58aa. Reimplemented in
 * hosted C to avoid a C++ runtime cycle in toolchain construction.
 */

#include "tools/coff_def_parser/def_parser.h"

#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#endif

#define COFF_DOS_SIGNATURE 0x5a4d
#define COFF_MACHINE_I386 0x014c
#define COFF_MACHINE_ARM 0x01c0
#define COFF_MACHINE_ARMNT 0x01c4
#define COFF_MACHINE_AMD64 0x8664
#define COFF_MACHINE_ARM64EC 0xa641
#define COFF_MACHINE_ARM64 0xaa64
#define COFF_SYM_CLASS_EXTERNAL 2
#define COFF_SCN_MEM_EXECUTE 0x20000000u
#define COFF_SCN_MEM_READ 0x40000000u
#define COFF_SCN_MEM_WRITE 0x80000000u
#define COFF_HEADER_SIZE 20u
#define COFF_SECTION_SIZE 40u
#define COFF_SYMBOL_SIZE 18u
#define BIGOBJ_HEADER_SIZE 56u
#define BIGOBJ_SYMBOL_SIZE 20u

enum symbol_arch {
  SYMBOL_ARCH_GENERIC,
  SYMBOL_ARCH_I386,
  SYMBOL_ARCH_ARM64EC,
};

struct string_set {
  char **values;
  size_t count;
  size_t capacity;
};

struct coff_def_parser {
  struct string_set symbols;
  struct string_set data_symbols;
  char *dll_name;
};

static void *xmalloc(size_t size) {
  void *result = malloc(size == 0 ? 1 : size);
  if (result == NULL) {
    fprintf(stderr, "coff_def_parser: out of memory\n");
    exit(2);
  }
  return result;
}

static void *xrealloc(void *pointer, size_t size) {
  void *result = realloc(pointer, size == 0 ? 1 : size);
  if (result == NULL) {
    fprintf(stderr, "coff_def_parser: out of memory\n");
    exit(2);
  }
  return result;
}

static char *xstrdup(const char *value) {
  size_t size = strlen(value) + 1;
  char *result = xmalloc(size);
  memcpy(result, value, size);
  return result;
}

static void string_set_destroy(struct string_set *set) {
  size_t index;
  for (index = 0; index < set->count; ++index) {
    free(set->values[index]);
  }
  free(set->values);
}

static void string_set_insert(struct string_set *set, const char *value) {
  size_t position = 0;
  while (position < set->count && strcmp(set->values[position], value) < 0) {
    ++position;
  }
  if (position < set->count && strcmp(set->values[position], value) == 0) {
    return;
  }
  if (set->count == set->capacity) {
    set->capacity = set->capacity == 0 ? 32 : set->capacity * 2;
    set->values = xrealloc(set->values, set->capacity * sizeof(*set->values));
  }
  memmove(set->values + position + 1, set->values + position,
          (set->count - position) * sizeof(*set->values));
  set->values[position] = xstrdup(value);
  set->count++;
}

static uint16_t read_u16(const unsigned char *bytes) {
  return (uint16_t)bytes[0] | (uint16_t)((uint16_t)bytes[1] << 8);
}

static uint32_t read_u32(const unsigned char *bytes) {
  return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) |
         ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static int has_bytes(size_t file_size, size_t offset, size_t count) {
  return offset <= file_size && count <= file_size - offset;
}

#ifdef _WIN32
static wchar_t *absolute_windows_path(const char *path) {
  int input_length;
  wchar_t *input;
  DWORD full_length;
  wchar_t *full;
  wchar_t *result;

  input_length = MultiByteToWideChar(CP_ACP, 0, path, -1, NULL, 0);
  if (input_length <= 0) {
    return NULL;
  }
  input = xmalloc((size_t)input_length * sizeof(*input));
  if (MultiByteToWideChar(CP_ACP, 0, path, -1, input, input_length) <= 0) {
    free(input);
    return NULL;
  }
  full_length = GetFullPathNameW(input, 0, NULL, NULL);
  if (full_length == 0) {
    free(input);
    return NULL;
  }
  full = xmalloc((size_t)full_length * sizeof(*full));
  if (GetFullPathNameW(input, full_length, full, NULL) == 0) {
    free(input);
    free(full);
    return NULL;
  }
  free(input);
  if (wcsncmp(full, L"\\\\?\\", 4) == 0) {
    return full;
  }
  result = xmalloc(((size_t)full_length + 4) * sizeof(*result));
  wcscpy(result, L"\\\\?\\");
  wcscat(result, full);
  free(full);
  return result;
}
#endif

FILE *coff_def_parser_open_file(const char *filename, const char *mode) {
#ifdef _WIN32
  wchar_t *path = absolute_windows_path(filename);
  const wchar_t *wide_mode = strcmp(mode, "rb") == 0 ? L"rb" : L"wb";
  FILE *file = path == NULL ? NULL : _wfopen(path, wide_mode);
  free(path);
  return file;
#else
  return fopen(filename, mode);
#endif
}

static int read_file(const char *filename, unsigned char **contents,
                     size_t *size) {
  FILE *file = coff_def_parser_open_file(filename, "rb");
  long length;
  if (file == NULL) {
    fprintf(stderr, "Couldn't open file '%s'\n", filename);
    return 0;
  }
  if (fseek(file, 0, SEEK_END) != 0 || (length = ftell(file)) < 0 ||
      fseek(file, 0, SEEK_SET) != 0) {
    fprintf(stderr, "Couldn't determine file size for '%s'\n", filename);
    fclose(file);
    return 0;
  }
  *size = (size_t)length;
  *contents = xmalloc(*size);
  if (*size != 0 && fread(*contents, 1, *size, file) != *size) {
    fprintf(stderr, "Couldn't read file '%s'\n", filename);
    free(*contents);
    *contents = NULL;
    fclose(file);
    return 0;
  }
  if (fclose(file) != 0) {
    fprintf(stderr, "Couldn't read file '%s'\n", filename);
    free(*contents);
    *contents = NULL;
    return 0;
  }
  return 1;
}

static int contains(const char *value, const char *substring) {
  return strstr(value, substring) != NULL;
}

static int managed_symbol(const char *symbol) {
  return strcmp(symbol, "__t2m") == 0 || strcmp(symbol, "__m2mep") == 0 ||
         strcmp(symbol, "__mep") == 0 || contains(symbol, "$$F") ||
         contains(symbol, "$$J");
}

static char *symbol_name(const unsigned char *symbol,
                         const unsigned char *string_table,
                         size_t string_table_size) {
  if (read_u32(symbol) != 0) {
    size_t length = 0;
    char *result;
    while (length < 8 && symbol[length] != '\0') {
      ++length;
    }
    result = xmalloc(length + 1);
    memcpy(result, symbol, length);
    result[length] = '\0';
    return result;
  }
  {
    uint32_t offset = read_u32(symbol + 4);
    const unsigned char *end;
    size_t length;
    char *result;
    if (offset < 4 || offset >= string_table_size) {
      return NULL;
    }
    end = memchr(string_table + offset, '\0', string_table_size - offset);
    if (end == NULL) {
      return NULL;
    }
    length = (size_t)(end - (string_table + offset));
    result = xmalloc(length + 1);
    memcpy(result, string_table + offset, length);
    result[length] = '\0';
    return result;
  }
}

static int parse_symbol_table(struct coff_def_parser *parser,
                              const unsigned char *contents, size_t file_size,
                              size_t section_offset, uint32_t section_count,
                              size_t symbol_offset, uint32_t symbol_count,
                              size_t symbol_size, int bigobj,
                              enum symbol_arch arch, const char *filename) {
  size_t table_size = (size_t)symbol_count * symbol_size;
  size_t string_offset = symbol_offset + table_size;
  const unsigned char *string_table;
  size_t string_table_size;
  uint32_t index = 0;

  if (!has_bytes(file_size, section_offset,
                 (size_t)section_count * COFF_SECTION_SIZE) ||
      !has_bytes(file_size, symbol_offset, table_size) ||
      !has_bytes(file_size, string_offset, 4)) {
    fprintf(stderr, "Object file '%s' has truncated %s tables\n", filename,
            bigobj ? "bigobj" : "COFF");
    return 0;
  }
  string_table = contents + string_offset;
  string_table_size = read_u32(string_table);
  if (string_table_size < 4 ||
      !has_bytes(file_size, string_offset, string_table_size)) {
    fprintf(stderr, "Object file '%s' has truncated string table\n", filename);
    return 0;
  }

  while (index < symbol_count) {
    const unsigned char *symbol =
        contents + symbol_offset + (size_t)index * symbol_size;
    int32_t section = bigobj ? (int32_t)read_u32(symbol + 12)
                             : (int16_t)read_u16(symbol + 12);
    uint16_t type = read_u16(symbol + (bigobj ? 16 : 14));
    unsigned char storage_class = symbol[bigobj ? 18 : 16];
    unsigned char auxiliary_count = symbol[bigobj ? 19 : 17];

    if (section > 0 && (uint32_t)section > section_count) {
      fprintf(stderr, "Object file '%s' has an invalid section reference\n",
              filename);
      return 0;
    }
    if (section > 0 && (type == 0x20 || type == 0) &&
        storage_class == COFF_SYM_CLASS_EXTERNAL) {
      char *name = symbol_name(symbol, string_table, string_table_size);
      char *at;
      uint32_t characteristics;
      if (name == NULL) {
        fprintf(stderr, "Object file '%s' has an invalid symbol name\n",
                filename);
        return 0;
      }
      while (name[0] != '\0' && isspace((unsigned char)name[0])) {
        memmove(name, name + 1, strlen(name));
      }
      if (name[0] == '_') {
        at = strchr(name, '@');
        if (at != NULL) {
          *at = '\0';
        }
      }
      if (arch == SYMBOL_ARCH_I386 && name[0] == '_') {
        memmove(name, name + 1, strlen(name));
      }
      characteristics =
          read_u32(contents + section_offset +
                   (size_t)(section - 1) * COFF_SECTION_SIZE + 36);
      if (name[0] != '\0' && strncmp(name, "??_G", 4) != 0 &&
          strncmp(name, "??_E", 4) != 0 && strchr(name, '.') == NULL &&
          !managed_symbol(name) &&
          (arch != SYMBOL_ARCH_ARM64EC || (!contains(name, "$ientry_thunk") &&
                                           !contains(name, "$entry_thunk") &&
                                           !contains(name, "$iexit_thunk") &&
                                           !contains(name, "$exit_thunk")))) {
        if (type == 0 && (characteristics & COFF_SCN_MEM_WRITE) != 0) {
          string_set_insert(&parser->data_symbols, name);
        } else if (type != 0 || (characteristics & COFF_SCN_MEM_READ) == 0 ||
                   (characteristics & COFF_SCN_MEM_EXECUTE) != 0 ||
                   strncmp(name, "??_7", 4) == 0) {
          string_set_insert(&parser->symbols, name);
        }
      }
      free(name);
    }
    if ((uint32_t)auxiliary_count >= symbol_count - index) {
      fprintf(stderr, "Object file '%s' has truncated auxiliary symbols\n",
              filename);
      return 0;
    }
    index += (uint32_t)auxiliary_count + 1;
  }
  return 1;
}

static enum symbol_arch arch_for_machine(uint16_t machine) {
  return machine == COFF_MACHINE_I386      ? SYMBOL_ARCH_I386
         : machine == COFF_MACHINE_ARM64EC ? SYMBOL_ARCH_ARM64EC
                                           : SYMBOL_ARCH_GENERIC;
}

static int supported_machine(uint16_t machine) {
  return machine == COFF_MACHINE_I386 || machine == COFF_MACHINE_AMD64 ||
         machine == COFF_MACHINE_ARM || machine == COFF_MACHINE_ARMNT ||
         machine == COFF_MACHINE_ARM64 || machine == COFF_MACHINE_ARM64EC;
}

static int dump_file(struct coff_def_parser *parser, const char *filename) {
  unsigned char *contents = NULL;
  size_t file_size = 0;
  uint16_t machine;
  int result;

  if (!read_file(filename, &contents, &file_size)) {
    return 0;
  }
  if (!has_bytes(file_size, 0, 2)) {
    fprintf(stderr, "Object file '%s' is too small\n", filename);
    free(contents);
    return 0;
  }
  if (read_u16(contents) == COFF_DOS_SIGNATURE) {
    fprintf(stderr, "File is an executable.  I don't dump those.\n");
    fprintf(stderr, "File is an executable.  I don't dump those.\n");
    free(contents);
    return 0;
  }
  if (!has_bytes(file_size, 0, COFF_HEADER_SIZE)) {
    fprintf(stderr, "Object file '%s' is too small for a COFF header\n",
            filename);
    free(contents);
    return 0;
  }
  machine = read_u16(contents);
  if (supported_machine(machine) && read_u16(contents + 18) == 0) {
    uint16_t section_count = read_u16(contents + 2);
    size_t section_offset = COFF_HEADER_SIZE + read_u16(contents + 16);
    uint32_t symbol_offset = read_u32(contents + 8);
    uint32_t symbol_count = read_u32(contents + 12);
    result = parse_symbol_table(parser, contents, file_size, section_offset,
                                section_count, symbol_offset, symbol_count,
                                COFF_SYMBOL_SIZE, 0, arch_for_machine(machine),
                                filename);
  } else if (has_bytes(file_size, 0, BIGOBJ_HEADER_SIZE) &&
             read_u16(contents) == 0 && read_u16(contents + 2) == 0xffff) {
    machine = read_u16(contents + 6);
    if (!supported_machine(machine)) {
      printf("unrecognized file format in '%s, %u'\n", filename,
             (unsigned)machine);
      result = 0;
    } else {
      result =
          parse_symbol_table(parser, contents, file_size, BIGOBJ_HEADER_SIZE,
                             read_u32(contents + 44), read_u32(contents + 48),
                             read_u32(contents + 52), BIGOBJ_SYMBOL_SIZE, 1,
                             arch_for_machine(machine), filename);
    }
  } else {
    printf("unrecognized file format in '%s, %u'\n", filename,
           (unsigned)machine);
    result = 0;
  }
  free(contents);
  return result;
}

static char *read_line(FILE *file) {
  char *line = NULL;
  size_t length = 0;
  size_t capacity = 0;
  int character;
  while ((character = fgetc(file)) != EOF) {
    if (length + 1 >= capacity) {
      capacity = capacity == 0 ? 256 : capacity * 2;
      line = xrealloc(line, capacity);
    }
    if (character == '\n') {
      break;
    }
    line[length++] = (char)character;
  }
  if (character == EOF && length == 0) {
    free(line);
    return NULL;
  }
  if (line == NULL) {
    line = xmalloc(1);
  }
  line[length] = '\0';
  return line;
}

struct coff_def_parser *coff_def_parser_create(void) {
  struct coff_def_parser *parser = xmalloc(sizeof(*parser));
  memset(parser, 0, sizeof(*parser));
  return parser;
}

void coff_def_parser_destroy(struct coff_def_parser *parser) {
  if (parser == NULL) {
    return;
  }
  string_set_destroy(&parser->symbols);
  string_set_destroy(&parser->data_symbols);
  free(parser->dll_name);
  free(parser);
}

void coff_def_parser_set_dll_name(struct coff_def_parser *parser,
                                  const char *name) {
  free(parser->dll_name);
  parser->dll_name = xstrdup(name);
}

int coff_def_parser_add_object_file(struct coff_def_parser *parser,
                                    const char *filename) {
  return dump_file(parser, filename);
}

int coff_def_parser_add_definition_file(struct coff_def_parser *parser,
                                        const char *filename) {
  FILE *file = coff_def_parser_open_file(filename, "rb");
  char *line;
  if (file == NULL) {
    fprintf(stderr, "Couldn't open definition file '%s'\n", filename);
    return 0;
  }
  while ((line = read_line(file)) != NULL) {
    if (strncmp(line, "LIBRARY", 7) != 0 && strncmp(line, "EXPORTS", 7) != 0) {
      char *start = line;
      char *data;
      while (*start == ' ' || *start == '\t') {
        ++start;
      }
      data = strstr(start, " \t DATA");
      if (data != NULL) {
        *data = '\0';
        string_set_insert(&parser->data_symbols, start);
      } else {
        string_set_insert(&parser->symbols, start);
      }
    }
    free(line);
  }
  fclose(file);
  return 1;
}

static int is_definition_file(const char *filename) {
  const char *extension = strrchr(filename, '.');
  const char *value = extension == NULL ? filename : extension + 1;
  return strlen(value) == 3 && tolower((unsigned char)value[0]) == 'd' &&
         tolower((unsigned char)value[1]) == 'e' &&
         tolower((unsigned char)value[2]) == 'f' && value[3] == '\0';
}

int coff_def_parser_add_file(struct coff_def_parser *parser,
                             const char *filename) {
  return is_definition_file(filename)
             ? coff_def_parser_add_definition_file(parser, filename)
             : coff_def_parser_add_object_file(parser, filename);
}

void coff_def_parser_write_file(const struct coff_def_parser *parser,
                                FILE *file) {
  size_t index;
  if (parser->dll_name != NULL && parser->dll_name[0] != '\0') {
    fprintf(file, "LIBRARY %s\n", parser->dll_name);
  }
  fprintf(file, "EXPORTS \n");
  for (index = 0; index < parser->data_symbols.count; ++index) {
    fprintf(file, "\t%s \t DATA\n", parser->data_symbols.values[index]);
  }
  for (index = 0; index < parser->symbols.count; ++index) {
    fprintf(file, "\t%s\n", parser->symbols.values[index]);
  }
}
