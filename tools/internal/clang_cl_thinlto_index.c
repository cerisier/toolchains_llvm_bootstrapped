#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *required_env(const char *name) {
  const char *value = getenv(name);
  if (value == NULL || value[0] == '\0') {
    fprintf(stderr,
            "clang-cl-thinlto-index: required env var %s is not set\n",
            name);
    exit(1);
  }
  return value;
}

int main(int argc, char **argv) {
  const char *lld_link = required_env("LLVM_LLD_LINK");
  const char *clang_cl = required_env("LLVM_CLANG_CL");

  char *compiler_path = strdup(lld_link);
  if (compiler_path == NULL) {
    fprintf(stderr, "clang-cl-thinlto-index: strdup failed: %s\n",
            strerror(errno));
    return 1;
  }

  char *separator = strrchr(compiler_path, '/');
  if (separator == NULL) {
    compiler_path[0] = '.';
    compiler_path[1] = '\0';
  } else if (separator == compiler_path) {
    separator[1] = '\0';
  } else {
    *separator = '\0';
  }

  if (setenv("COMPILER_PATH", compiler_path, 1) != 0) {
    fprintf(stderr, "clang-cl-thinlto-index: setenv failed: %s\n",
            strerror(errno));
    return 1;
  }
  free(compiler_path);

  char **clang_argv = calloc((size_t)argc + 2, sizeof(char *));
  if (clang_argv == NULL) {
    fprintf(stderr, "clang-cl-thinlto-index: calloc failed: %s\n",
            strerror(errno));
    return 1;
  }

  clang_argv[0] = (char *)clang_cl;
  clang_argv[1] = "/clang:-fuse-ld=lld";
  for (int i = 1; i < argc; ++i) {
    clang_argv[i + 1] = argv[i];
  }

  execv(clang_cl, clang_argv);
  fprintf(stderr, "clang-cl-thinlto-index: failed to execute %s: %s\n",
          clang_cl, strerror(errno));
  return 1;
}
