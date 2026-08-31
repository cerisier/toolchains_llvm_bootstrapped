#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tools/case_insensitive_vfs/filesystem.h"
#include "tools/case_insensitive_vfs/vfs.h"

int main(int argc, char **argv) {
  const char **roots = NULL;
  size_t root_count = 0;
  const char *output_path = NULL;
  char *overlay = NULL;
  char *error = NULL;
  FILE *output;
  int index;

  for (index = 1; index < argc; ++index) {
    if (strcmp(argv[index], "-root") == 0) {
      if (++index == argc) {
        fprintf(stderr, "-root requires a value\n");
        return 2;
      }
      roots = ci_xrealloc(roots, (root_count + 1) * sizeof(*roots));
      roots[root_count++] = argv[index];
    } else if (strcmp(argv[index], "-output") == 0) {
      if (++index == argc) {
        fprintf(stderr, "-output requires a value\n");
        return 2;
      }
      output_path = argv[index];
    } else {
      fprintf(stderr, "unknown argument: %s\n", argv[index]);
      free(roots);
      return 2;
    }
  }
  if (output_path == NULL) {
    fprintf(stderr, "-output is required\n");
    free(roots);
    return 2;
  }
  if (!case_insensitive_vfs_generate(roots, root_count, &overlay, &error)) {
    fprintf(stderr, "%s\n", error);
    free(error);
    free(roots);
    return 1;
  }
  output = fopen(output_path, "wb");
  if (output == NULL) {
    fprintf(stderr, "open %s failed: %s\n", output_path, strerror(errno));
    free(overlay);
    free(roots);
    return 1;
  }
  if (fwrite(overlay, 1, strlen(overlay), output) != strlen(overlay)) {
    fprintf(stderr, "write %s failed\n", output_path);
    fclose(output);
    free(overlay);
    free(roots);
    return 1;
  }
  if (fclose(output) != 0) {
    fprintf(stderr, "write %s failed\n", output_path);
    free(overlay);
    free(roots);
    return 1;
  }
  free(overlay);
  free(roots);
  return 0;
}
