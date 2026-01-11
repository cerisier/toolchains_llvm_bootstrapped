#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>

#include <memory>
#include <string>

// Injected at build-time, see `expand_header_parser` in //toolchain/llvm:llvm.bzl .
static const char kClangExecPath[] = "{CLANG_EXEC_PATH}";

static void Die(const char *msg) {
  fprintf(stderr, "header_parser: %s\n", msg);
  exit(1);
}

static void DieErrno(const char *what) {
  fprintf(stderr, "header_parser: %s: %s\n", what, strerror(errno));
  exit(1);
}

static void TouchFile(const char *env_name) {
  const char *path = getenv(env_name);
  if (path == nullptr || path[0] == '\0') {
    fprintf(stderr, "header_parser: required env var %s is not set\n", env_name);
    exit(2);
  }

  int fd = open(path, O_WRONLY | O_CREAT, 0666);
  if (fd < 0) {
    fprintf(stderr, "header_parser: failed to touch %s=%s: %s\n",
            env_name, path, strerror(errno));
    exit(2);
  }
  if (close(fd) != 0) {
    fprintf(stderr, "header_parser: failed to close %s=%s: %s\n",
            env_name, path, strerror(errno));
    exit(2);
  }
}

int main(int argc, char **argv) {
  if (kClangExecPath[0] == '\0') {
    Die("injected clang exec path is empty");
  }

  TouchFile("PARSE_HEADER");

  // Intentional failure to verify header parsing is executed.
  Die("intentional failure in header_parser");

  argv[0] = const_cast<char *>(kClangExecPath);
  execv(kClangExecPath, argv);
  DieErrno("execv failed");
}
