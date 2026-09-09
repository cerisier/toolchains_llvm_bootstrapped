#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <process.h>
#else
#include <unistd.h>
#endif

int main(int argc, char **argv) {
  const char *path = getenv("PARSE_HEADER");
  if (path == NULL || path[0] == '\0') {
    fprintf(stderr, "header_parser: required env var PARSE_HEADER is not set\n");
    exit(2);
  }

  FILE *touched = fopen(path, "a");
  if (touched == NULL) {
    fprintf(stderr, "header_parser: failed to touch %s: %s\n",
            path, strerror(errno));
    exit(2);
  }
  if (fclose(touched) != 0) {
    fprintf(stderr, "header_parser: failed to close =%s: %s\n",
            path, strerror(errno));
    exit(2);
  }

  const char *clang_path = getenv("LLVM_CLANGXX");
  if (clang_path == NULL || clang_path[0] == '\0') {
    fprintf(stderr, "header_parser: required env var LLVM_CLANGXX is not set\n");
    exit(2);
  }

  argv[0] = (char *)clang_path;
#ifdef _WIN32
  intptr_t status = _spawnv(_P_WAIT, clang_path, (const char *const *)argv);
  if (status == -1) {
    fprintf(stderr, "header_parser: failed to execute %s: %s\n",
            clang_path, strerror(errno));
    return 2;
  }
  return (int)status;
#else
  execv(clang_path, argv);
  fprintf(stderr, "header_parser: execv failed: %s\n", strerror(errno));
  return 2;
#endif
}
