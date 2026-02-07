#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <string>

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

  std::string self_path = argv[0] ? argv[0] : "";
  std::string dir;
  size_t slash = self_path.find_last_of('/');
  if (slash == std::string::npos) {
    fprintf(stderr, "header_parser: expected argv[0] to include a directory\n");
    exit(2);
  }
  dir = self_path.substr(0, slash);

  std::string clang_path = dir + "/clang++";

  argv[0] = const_cast<char *>(clang_path.c_str());
  execv(clang_path.c_str(), argv);
  fprintf(stderr, "header_parser: execv failed: %s\n", strerror(errno));
}
