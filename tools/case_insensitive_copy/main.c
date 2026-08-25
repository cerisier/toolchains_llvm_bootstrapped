#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tools/case_insensitive_copy/copy.h"

int main(int argc, char **argv) {
  const char *source = NULL;
  const char *output = NULL;
  char *error = NULL;
  int index;

  for (index = 1; index < argc; ++index) {
    if (strcmp(argv[index], "-source") == 0) {
      if (++index == argc) {
        fprintf(stderr, "-source requires a value\n");
        return 2;
      }
      source = argv[index];
    } else if (strcmp(argv[index], "-output") == 0) {
      if (++index == argc) {
        fprintf(stderr, "-output requires a value\n");
        return 2;
      }
      output = argv[index];
    } else {
      fprintf(stderr, "unknown argument: %s\n", argv[index]);
      return 2;
    }
  }
  if (source == NULL || output == NULL) {
    fprintf(stderr, "-source and -output are required\n");
    return 2;
  }
  if (!case_insensitive_copy_directory(source, output, &error)) {
    fprintf(stderr, "%s\n", error);
    free(error);
    return 1;
  }
  return 0;
}
