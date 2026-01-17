#include <algorithm>
#include <cctype>
#include <errno.h>
#include <fcntl.h>
#include <sstream>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <string>
#include <vector>

// Injected at build-time.
static const char kCxxfiltExecPath[] = "{CXXFILT_EXEC_PATH}";
static const char kNmExecPath[] = "{NM_EXEC_PATH}";
static const char kNmExtraArgs[] = "{NM_EXTRA_ARGS}";

struct SymbolEntry {
  std::string symbol;
  std::string object;
  char type;
};

static void PrintErrno(const char *what) {
  fprintf(stderr, "static_library_validator: %s: %s\n", what, strerror(errno));
}

static std::vector<std::string> SplitArgs(const char *raw) {
  std::istringstream ss(raw ? raw : "");
  std::vector<std::string> out;
  std::string arg;
  while (ss >> arg) out.push_back(arg);
  return out;
}

static bool ShouldKeepType(char type) {
  return std::isupper(static_cast<unsigned char>(type)) &&
         type != 'U' && type != 'V' && type != 'W';
}

static bool ExecWithPipes(const std::vector<std::string> &argv,
                          const std::string &stdin_data,
                          std::string *stdout_data) {
  int in_pipe[2], out_pipe[2];
  if (pipe(in_pipe) != 0) return PrintErrno("pipe"), false;
  if (pipe(out_pipe) != 0) {
    PrintErrno("pipe");
    close(in_pipe[0]); close(in_pipe[1]);
    return false;
  }

  pid_t pid = fork();
  if (pid < 0) {
    PrintErrno("fork");
    close(in_pipe[0]); close(in_pipe[1]);
    close(out_pipe[0]); close(out_pipe[1]);
    return false;
  }

  if (pid == 0) {
    dup2(in_pipe[0], STDIN_FILENO);
    dup2(out_pipe[1], STDOUT_FILENO);
    close(in_pipe[0]); close(in_pipe[1]);
    close(out_pipe[0]); close(out_pipe[1]);
    std::vector<char *> args;
    args.reserve(argv.size() + 1);
    for (const auto &s : argv) args.push_back(const_cast<char *>(s.c_str()));
    args.push_back(nullptr);
    execv(args[0], args.data());
    _exit(127);
  }

  close(in_pipe[0]);
  close(out_pipe[1]);

  ssize_t written = 0;
  while (written < static_cast<ssize_t>(stdin_data.size())) {
    ssize_t n = write(in_pipe[1], stdin_data.data() + written,
                      stdin_data.size() - written);
    if (n < 0) {
      if (errno == EINTR) continue;
      PrintErrno("write");
      close(in_pipe[1]); close(out_pipe[0]);
      return false;
    }
    written += n;
  }
  close(in_pipe[1]);

  stdout_data->clear();
  char buf[4096];
  while (true) {
    ssize_t n = read(out_pipe[0], buf, sizeof(buf));
    if (n == 0) break;
    if (n < 0) {
      if (errno == EINTR) continue;
      PrintErrno("read");
      close(out_pipe[0]);
      return false;
    }
    stdout_data->append(buf, n);
  }
  close(out_pipe[0]);

  int status = 0;
  if (waitpid(pid, &status, 0) < 0) {
    PrintErrno("waitpid");
    return false;
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    fprintf(stderr,
            "static_library_validator: command exited with status %d\n",
            WIFEXITED(status) ? WEXITSTATUS(status) : -1);
    return false;
  }
  return true;
}

static void ParseNmLine(const std::string &line,
                        std::vector<SymbolEntry> *out) {
  size_t open = line.find('[');
  size_t close = line.find(']', open == std::string::npos ? 0 : open + 1);
  size_t sep = line.find("]: ", close == std::string::npos ? 0 : close);
  if (open == std::string::npos || close == std::string::npos ||
      sep == std::string::npos) {
    return;
  }
  std::string object = line.substr(open + 1, close - open - 1);
  std::istringstream rest(line.substr(sep + 3));
  std::string symbol, type_str, dummy1, dummy2;
  if (!(rest >> symbol >> type_str >> dummy1 >> dummy2)) return;
  if (type_str.size() != 1) return;
  char type = type_str[0];
  if (!ShouldKeepType(type)) return;
  out->push_back({symbol, object, type});
}

static bool Touch(const char *path) {
  int fd = open(path, O_WRONLY | O_CREAT, 0666);
  if (fd < 0) return PrintErrno("open"), false;
  if (close(fd) != 0) return PrintErrno("close"), false;
  return true;
}

int main(int argc, char **argv) {
  if (argc != 3) {
    fprintf(stderr,
            "usage: static_library_validator <static_library> <stamp_path>\n");
    return 2;
  }

  std::vector<std::string> nm_args = {kNmExecPath, "-A", "-g", "-P"};
  auto extra = SplitArgs(kNmExtraArgs);
  nm_args.insert(nm_args.end(), extra.begin(), extra.end());
  nm_args.push_back(argv[1]);

  std::string nm_output;
  if (!ExecWithPipes(nm_args, "", &nm_output)) return 2;

  std::vector<SymbolEntry> entries;
  size_t pos = 0;
  while (pos <= nm_output.size()) {
    size_t end = nm_output.find('\n', pos);
    if (end == std::string::npos) end = nm_output.size();
    ParseNmLine(nm_output.substr(pos, end - pos), &entries);
    pos = end + 1;
  }

  std::sort(entries.begin(), entries.end(),
            [](const SymbolEntry &a, const SymbolEntry &b) {
              return a.symbol < b.symbol;
            });

  std::vector<std::string> dup_lines;
  for (size_t i = 0; i < entries.size();) {
    size_t j = i + 1;
    while (j < entries.size() && entries[j].symbol == entries[i].symbol) ++j;
    if (j - i >= 2) {
      for (size_t k = i; k < j; ++k) {
        dup_lines.push_back(entries[k].object + ": " +
                            std::string(1, entries[k].type) + " " +
                            entries[k].symbol);
      }
    }
    i = j;
  }

  if (dup_lines.empty()) return Touch(argv[2]) ? 0 : 2;

  std::string dup_block;
  for (const auto &l : dup_lines) dup_block.append(l).push_back('\n');

  std::string demangled;
  std::vector<std::string> filt_args = {kCxxfiltExecPath};
  if (!ExecWithPipes(filt_args, dup_block, &demangled)) return 2;

  fprintf(stderr, "Duplicate symbols found in %s:\n", argv[1]);
  fwrite(demangled.data(), 1, demangled.size(), stderr);
  return 1;
}
