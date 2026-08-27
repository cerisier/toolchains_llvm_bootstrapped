/* Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
   file Copyright.txt or https://cmake.org/licensing for details.  */

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tools/coff_def_parser/def_parser.h"

static char *read_line(FILE *file) {
  char *line = NULL;
  size_t length = 0;
  size_t capacity = 0;
  int character;
  while ((character = fgetc(file)) != EOF) {
    if (length + 1 >= capacity) {
      char *resized;
      capacity = capacity == 0 ? 256 : capacity * 2;
      resized = realloc(line, capacity);
      if (resized == NULL) {
        fprintf(stderr, "coff_def_parser: out of memory\n");
        free(line);
        exit(2);
      }
      line = resized;
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
    line = malloc(1);
    if (line == NULL) {
      fprintf(stderr, "coff_def_parser: out of memory\n");
      exit(2);
    }
  }
  line[length] = '\0';
  return line;
}

static char *trim(char *value) {
  char *end;
  while (isspace((unsigned char)*value)) {
    ++value;
  }
  end = value + strlen(value);
  while (end != value && isspace((unsigned char)end[-1])) {
    --end;
  }
  *end = '\0';
  return value;
}

static int decode_shell_argument(char *value, char **argument) {
  char *input = value;
  char *output = value;
  int quote = 0;
  int started = 0;
  int separated = 0;

  while (*input != '\0') {
    unsigned char character = (unsigned char)*input++;
    if (quote == '\'') {
      if (character == '\'') {
        quote = 0;
      } else {
        *output++ = (char)character;
      }
    } else if (quote == '"') {
      if (character == '"') {
        quote = 0;
      } else if (character == '\\') {
        if (*input == '\0') {
          fprintf(stderr,
                  "coff_def_parser: trailing escape in shell parameter\n");
          return 0;
        }
        *output++ = *input++;
      } else {
        *output++ = (char)character;
      }
    } else if (isspace(character)) {
      separated = started;
    } else {
      if (separated) {
        fprintf(stderr,
                "coff_def_parser: multiple arguments in one shell parameter "
                "entry\n");
        return 0;
      }
      started = 1;
      if (character == '\'' || character == '"') {
        quote = character;
      } else if (character == '\\') {
        if (*input == '\0') {
          fprintf(stderr,
                  "coff_def_parser: trailing escape in shell parameter\n");
          return 0;
        }
        *output++ = *input++;
      } else {
        *output++ = (char)character;
      }
    }
  }

  if (quote != 0) {
    fprintf(stderr, "coff_def_parser: unterminated shell parameter quote\n");
    return 0;
  }
  if (!started) {
    fprintf(stderr, "coff_def_parser: empty shell parameter entry\n");
    return 0;
  }
  *output = '\0';
  *argument = value;
  return 1;
}

static void usage(void) {
  fprintf(stderr,
          "Usage: output_def_file dllname [objfile ...] [input_deffile ...] "
          "[@paramfile ...]\n"
          "output_deffile: the output DEF file\n\n"
          "dllname: the DLL name this DEF file is used for, if dllname is not "
          "empty\n"
          "         string, def_parser writes a 'LIBRARY <dllname>' entry\n"
          "         into DEF file.\n\n"
          "objfile: a object file, def_parser parses this file to find "
          "symbols,\n"
          "         then merges them into final result.\n"
          "         Can apppear multiple times.\n\n"
          "input_deffile: an existing def file, def_parser merges all symbols "
          "in this file.\n"
          "               Can appear multiple times.\n\n"
          "@paramfile: a parameter file that can contain objfile and "
          "input_deffile.\n"
          "            Can appear multiple time.\n");
}

int main(int argc, char **argv) {
  FILE *output;
  struct coff_def_parser *parser;
  int index;

  if (argc < 4) {
    usage();
    return 1;
  }
  output = coff_def_parser_open_file(argv[1], "wb");
  if (output == NULL) {
    fprintf(stderr, "Could not open output .def file: %s\n", argv[1]);
    return 1;
  }
  parser = coff_def_parser_create();
  coff_def_parser_set_dll_name(parser, argv[2]);
  for (index = 3; index < argc; ++index) {
    if (argv[index][0] == '@') {
      FILE *parameters = coff_def_parser_open_file(argv[index] + 1, "rb");
      char *line;
      if (parameters == NULL) {
        fprintf(stderr, "Could not open parameter file: %s\n", argv[index]);
        coff_def_parser_destroy(parser);
        fclose(output);
        return 1;
      }
      while ((line = read_line(parameters)) != NULL) {
        char *filename;
        if (!decode_shell_argument(trim(line), &filename) ||
            !coff_def_parser_add_file(parser, filename)) {
          free(line);
          fclose(parameters);
          coff_def_parser_destroy(parser);
          fclose(output);
          return 1;
        }
        free(line);
      }
      fclose(parameters);
    } else if (!coff_def_parser_add_file(parser, trim(argv[index]))) {
      coff_def_parser_destroy(parser);
      fclose(output);
      return 1;
    }
  }
  coff_def_parser_write_file(parser, output);
  coff_def_parser_destroy(parser);
  return fclose(output) == 0 ? 0 : 1;
}
