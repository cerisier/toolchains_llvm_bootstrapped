#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
  const char *path = getenv("PARSE_HEADER");
  if (path == nullptr || path[0] == '\0') {
    fprintf(stderr, "header_parser: required env var PARSE_HEADER is not set\n");
    exit(2);
  }

  int fd = open(path, O_WRONLY | O_CREAT, 0666);
  if (fd < 0) {
    fprintf(stderr, "header_parser: failed to touch %s: %s\n",
            path, strerror(errno));
    exit(2);
  }
  if (close(fd) != 0) {
    fprintf(stderr, "header_parser: failed to close =%s: %s\n",
            path, strerror(errno));
    exit(2);
  }

  const char *clang_env = getenv("CLANG_PATH");
  if (clang_env == nullptr || clang_env[0] == '\0') {
    fprintf(stderr, "header_parser: required env var HEADER_PARSER_CLANG is not set\n");
    exit(2);
  }

  argv[0] = const_cast<char *>(clang_env);
  execv(clang_env, argv);
  fprintf(stderr, "header_parser: execv failed: %s\n", strerror(errno));
}
