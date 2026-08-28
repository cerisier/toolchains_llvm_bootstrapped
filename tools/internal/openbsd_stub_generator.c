#include <ctype.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct symbols {
  char **items;
  size_t count;
  size_t capacity;
};

static void fail(const char *message, const char *path) {
  fprintf(stderr, "openbsd-stub-generator: %s: %s\n", message, path);
  exit(1);
}

static bool is_symbol_character(char value) {
  return isalnum((unsigned char)value) || value == '_' || value == '.' ||
         value == '$' || value == '@';
}

static void add_symbol(struct symbols *symbols, const char *name) {
  for (size_t i = 0; i < symbols->count; ++i) {
    if (strcmp(symbols->items[i], name) == 0)
      return;
  }

  if (symbols->count == symbols->capacity) {
    size_t capacity = symbols->capacity == 0 ? 256 : symbols->capacity * 2;
    char **items = realloc(symbols->items, capacity * sizeof(*items));
    if (items == NULL)
      fail("out of memory", name);
    symbols->items = items;
    symbols->capacity = capacity;
  }

  size_t length = strlen(name) + 1;
  symbols->items[symbols->count] = malloc(length);
  if (symbols->items[symbols->count] == NULL)
    fail("out of memory", name);
  memcpy(symbols->items[symbols->count], name, length);
  ++symbols->count;
}

static void strip_comments(char *line, bool *in_comment) {
  char *source = line;
  char *destination = line;

  while (*source != '\0') {
    if (*in_comment) {
      if (source[0] == '*' && source[1] == '/') {
        *in_comment = false;
        source += 2;
      } else {
        ++source;
      }
    } else if (source[0] == '/' && source[1] == '*') {
      *in_comment = true;
      source += 2;
    } else {
      *destination++ = *source++;
    }
  }
  *destination = '\0';
}

static void read_symbols(struct symbols *symbols, const char *path,
                         bool map_format) {
  FILE *input = fopen(path, "r");
  if (input == NULL)
    fail("cannot open input", path);

  char line[4096];
  bool in_comment = false;
  bool in_global_section = !map_format;

  while (fgets(line, sizeof(line), input) != NULL) {
    strip_comments(line, &in_comment);

    char *cursor = line;
    while (isspace((unsigned char)*cursor))
      ++cursor;

    if (map_format && strstr(cursor, "global:") == cursor) {
      in_global_section = true;
      continue;
    }
    if (map_format && strstr(cursor, "local:") == cursor) {
      in_global_section = false;
      continue;
    }
    if (!in_global_section || !is_symbol_character(*cursor))
      continue;

    char *end = cursor;
    while (is_symbol_character(*end))
      ++end;
    *end = '\0';
    add_symbol(symbols, cursor);
  }

  if (ferror(input))
    fail("cannot read input", path);
  fclose(input);
}

int main(int argc, char **argv) {
  if (argc < 4 ||
      (strcmp(argv[1], "--list") != 0 && strcmp(argv[1], "--map") != 0)) {
    fprintf(stderr,
            "usage: openbsd-stub-generator (--list|--map) OUTPUT INPUT...\n");
    return 1;
  }

  struct symbols symbols = {0};
  bool map_format = strcmp(argv[1], "--map") == 0;
  for (int i = 3; i < argc; ++i)
    read_symbols(&symbols, argv[i], map_format);

  FILE *output = fopen(argv[2], "w");
  if (output == NULL)
    fail("cannot open output", argv[2]);

  fputs(".text\n", output);
  for (size_t i = 0; i < symbols.count; ++i) {
    fprintf(output, ".weak %s\n.type %s,@function\n%s:\n.byte 0\n",
            symbols.items[i], symbols.items[i], symbols.items[i]);
    free(symbols.items[i]);
  }

  free(symbols.items);
  if (fclose(output) != 0)
    fail("cannot write output", argv[2]);
  return 0;
}
