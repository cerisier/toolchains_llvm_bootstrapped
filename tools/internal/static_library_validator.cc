#include <algorithm>
#include <cctype>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <string>
#include <vector>

// Injected at build-time.
static const char kNmExecPath[] = "{NM_EXEC_PATH}";
static const char kNmExtraArgs[] = "{NM_EXTRA_ARGS}";
static const char kCxxfiltExecPath[] = "{CXXFILT_EXEC_PATH}";

struct SymbolEntry {
  std::string symbol;
  char type;
  std::string object;
  std::string line;
};

static void PrintErrno(const char *context) {
  fprintf(stderr, "static_library_validator: %s: %s\n", context,
          strerror(errno));
}

static std::vector<std::string> SplitArgs(const std::string &args) {
  std::vector<std::string> result;
  std::string current;
  for (char c : args) {
    if (isspace(static_cast<unsigned char>(c))) {
      if (!current.empty()) {
        result.push_back(current);
        current.clear();
      }
    } else {
      current.push_back(c);
    }
  }
  if (!current.empty()) {
    result.push_back(current);
  }
  return result;
}

static bool ShouldKeepType(char type) {
  if (!std::isupper(static_cast<unsigned char>(type))) {
    return false;
  }
  return type != 'U' && type != 'V' && type != 'W';
}

static bool RunCommand(const std::vector<std::string> &args,
                       const std::string &input, std::string *output) {
  int to_child[2];
  int from_child[2];
  if (pipe(to_child) != 0) {
    PrintErrno("pipe");
    return false;
  }
  if (pipe(from_child) != 0) {
    PrintErrno("pipe");
    close(to_child[0]);
    close(to_child[1]);
    return false;
  }

  pid_t pid = fork();
  if (pid < 0) {
    PrintErrno("fork");
    close(to_child[0]);
    close(to_child[1]);
    close(from_child[0]);
    close(from_child[1]);
    return false;
  }

  if (pid == 0) {
    // Child.
    if (dup2(to_child[0], STDIN_FILENO) < 0 ||
        dup2(from_child[1], STDOUT_FILENO) < 0) {
      PrintErrno("dup2");
      _exit(127);
    }
    close(to_child[0]);
    close(to_child[1]);
    close(from_child[0]);
    close(from_child[1]);

    std::vector<char *> argv;
    argv.reserve(args.size() + 1);
    for (const auto &arg : args) {
      argv.push_back(const_cast<char *>(arg.c_str()));
    }
    argv.push_back(nullptr);
    execv(argv[0], argv.data());
    PrintErrno("execv");
    _exit(127);
  }

  // Parent.
  close(to_child[0]);
  close(from_child[1]);

  ssize_t written = 0;
  while (written < static_cast<ssize_t>(input.size())) {
    ssize_t n = write(to_child[1], input.data() + written,
                      input.size() - written);
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      PrintErrno("write");
      close(to_child[1]);
      close(from_child[0]);
      return false;
    }
    written += n;
  }
  close(to_child[1]);

  output->clear();
  char buffer[4096];
  while (true) {
    ssize_t n = read(from_child[0], buffer, sizeof(buffer));
    if (n == 0) {
      break;
    }
    if (n < 0) {
      if (errno == EINTR) {
        continue;
      }
      PrintErrno("read");
      close(from_child[0]);
      return false;
    }
    output->append(buffer, n);
  }
  close(from_child[0]);

  int status = 0;
  if (waitpid(pid, &status, 0) < 0) {
    PrintErrno("waitpid");
    return false;
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    fprintf(stderr,
            "static_library_validator: command exited with status %d\n",
            exit_code);
    return false;
  }
  return true;
}

static void ParseNmLine(const std::string &line,
                        std::vector<SymbolEntry> *entries) {
  const size_t open = line.find('[');
  if (open == std::string::npos) {
    return;
  }
  const size_t close = line.find(']', open + 1);
  if (close == std::string::npos) {
    return;
  }
  const size_t after = line.find("]: ", close);
  if (after == std::string::npos) {
    return;
  }

  std::string object = line.substr(open + 1, close - open - 1);
  std::string rest = line.substr(after + 3);

  const size_t last_space = rest.rfind(' ');
  if (last_space == std::string::npos || last_space == 0) {
    return;
  }
  const size_t second_last_space = rest.rfind(' ', last_space - 1);
  if (second_last_space == std::string::npos ||
      second_last_space == 0) {
    return;
  }
  const size_t third_last_space = rest.rfind(' ', second_last_space - 1);
  if (third_last_space == std::string::npos) {
    return;
  }

  const size_t type_len = second_last_space - third_last_space - 1;
  if (type_len != 1) {
    return;
  }
  const char type = rest[third_last_space + 1];
  if (!ShouldKeepType(type)) {
    return;
  }

  std::string symbol = rest.substr(0, third_last_space);
  if (symbol.empty()) {
    return;
  }

  SymbolEntry entry{symbol, type, object,
                    object + ": " + std::string(1, type) + " " + symbol};
  entries->push_back(std::move(entry));
}

static bool TouchFile(const char *path) {
  int fd = open(path, O_WRONLY | O_CREAT, 0666);
  if (fd < 0) {
    PrintErrno("open");
    return false;
  }
  if (futimens(fd, nullptr) != 0) {
    PrintErrno("futimens");
    close(fd);
    return false;
  }
  if (close(fd) != 0) {
    PrintErrno("close");
    return false;
  }
  return true;
}

int main(int argc, char **argv) {
  if (argc != 3) {
    fprintf(stderr,
            "usage: static_library_validator <static_library> <stamp_path>\n");
    return 2;
  }

  const char *library_path = argv[1];
  const char *stamp_path = argv[2];

  std::vector<std::string> nm_args = {kNmExecPath, "-A", "-g", "-P"};
  std::vector<std::string> extra_args = SplitArgs(kNmExtraArgs);
  nm_args.insert(nm_args.end(), extra_args.begin(), extra_args.end());
  nm_args.push_back(library_path);

  std::string nm_output;
  if (!RunCommand(nm_args, "", &nm_output)) {
    return 2;
  }

  std::vector<SymbolEntry> entries;
  size_t start = 0;
  while (start < nm_output.size()) {
    size_t end = nm_output.find('\n', start);
    if (end == std::string::npos) {
      end = nm_output.size();
    }
    ParseNmLine(nm_output.substr(start, end - start), &entries);
    start = end + 1;
  }

  std::sort(entries.begin(), entries.end(),
            [](const SymbolEntry &a, const SymbolEntry &b) {
              if (a.symbol != b.symbol) {
                return a.symbol < b.symbol;
              }
              if (a.object != b.object) {
                return a.object < b.object;
              }
              return a.type < b.type;
            });

  std::vector<std::string> duplicates;
  for (size_t i = 0; i < entries.size();) {
    size_t j = i + 1;
    while (j < entries.size() && entries[j].symbol == entries[i].symbol) {
      ++j;
    }
    if (j - i >= 2) {
      for (size_t k = i; k < j; ++k) {
        duplicates.push_back(entries[k].line);
      }
    }
    i = j;
  }

  if (duplicates.empty()) {
    if (!TouchFile(stamp_path)) {
      return 2;
    }
    return 0;
  }

  std::string duplicate_block;
  for (const auto &line : duplicates) {
    duplicate_block.append(line);
    duplicate_block.push_back('\n');
  }

  std::vector<std::string> cxxfilt_args = {kCxxfiltExecPath};
  std::string demangled;
  if (!RunCommand(cxxfilt_args, duplicate_block, &demangled)) {
    return 2;
  }

  fprintf(stderr, "Duplicate symbols found in %s:\n", library_path);
  fwrite(demangled.data(), 1, demangled.size(), stderr);
  return 1;
}
