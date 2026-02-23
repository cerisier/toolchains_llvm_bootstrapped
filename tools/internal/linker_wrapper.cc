#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <fstream>
#include <memory>
#include <string>
#include <vector>

#include "tools/cpp/runfiles/runfiles.h"
#include "tools/internal/linker_wrapper_config.h"

using bazel::tools::cpp::runfiles::Runfiles;

namespace {

std::string ResolveRunfilePath(const Runfiles& runfiles,
                               const char* runfile_key,
                               const char* description) {
  if (runfile_key == nullptr || runfile_key[0] == '\0') {
    fprintf(stderr, "linker_wrapper: empty runfile key for %s\n", description);
    exit(2);
  }

  std::string resolved_path = runfiles.Rlocation(runfile_key);
  if (!resolved_path.empty()) {
    return resolved_path;
  }

  fprintf(stderr, "linker_wrapper: failed to resolve runfile for %s: key='%s'\n",
          description, runfile_key);
  exit(2);
}

std::vector<std::string> ParseContractFields(const std::string& line) {
  std::vector<std::string> fields;
  size_t start = 0;

  while (start <= line.size()) {
    const size_t tab = line.find('\t', start);
    if (tab == std::string::npos) {
      fields.push_back(line.substr(start));
      break;
    }
    fields.push_back(line.substr(start, tab - start));
    start = tab + 1;
  }
  return fields;
}

std::string ResolveWorkspaceExecrootPath(const std::string& absolute_path) {
  const std::string marker = "/execroot/";
  const size_t marker_pos = absolute_path.find(marker);
  if (marker_pos == std::string::npos) {
    return "";
  }

  const size_t workspace_start = marker_pos + marker.size();
  const size_t workspace_end = absolute_path.find('/', workspace_start);
  if (workspace_end == std::string::npos) {
    return "";
  }
  return absolute_path.substr(0, workspace_end);
}

std::string ResolveOutputBasePath(const std::string& absolute_path) {
  const std::string marker = "/execroot/";
  const size_t marker_pos = absolute_path.find(marker);
  if (marker_pos != std::string::npos) {
    return absolute_path.substr(0, marker_pos);
  }

  const std::string external_marker = "/external/";
  const size_t external_pos = absolute_path.find(external_marker);
  if (external_pos != std::string::npos) {
    return absolute_path.substr(0, external_pos);
  }
  return "";
}

bool PathExists(const std::string& path) {
  return access(path.c_str(), F_OK) == 0;
}

std::string NormalizeRelativePath(const std::string& value,
                                  const std::string& workspace_execroot,
                                  const std::string& output_base) {
  if (value.empty() || value[0] == '/') {
    return value;
  }

  if (value.rfind("bazel-out/", 0) == 0 && !workspace_execroot.empty()) {
    const std::string candidate = workspace_execroot + "/" + value;
    if (PathExists(candidate)) {
      return candidate;
    }
  }

  if (value.rfind("external/", 0) == 0 && !output_base.empty()) {
    const std::string candidate = output_base + "/" + value;
    if (PathExists(candidate)) {
      return candidate;
    }
  }

  return value;
}

std::string NormalizePathLikeArgument(const std::string& argument,
                                      const std::string& workspace_execroot,
                                      const std::string& output_base) {
  if (argument.rfind("--sysroot=", 0) == 0) {
    const std::string path = argument.substr(strlen("--sysroot="));
    return std::string("--sysroot=") +
           NormalizeRelativePath(path, workspace_execroot, output_base);
  }
  if (argument.rfind("-L", 0) == 0 && argument.size() > 2) {
    const std::string path = argument.substr(2);
    return std::string("-L") +
           NormalizeRelativePath(path, workspace_execroot, output_base);
  }
  if (argument.rfind("-B", 0) == 0 && argument.size() > 2) {
    const std::string path = argument.substr(2);
    return std::string("-B") +
           NormalizeRelativePath(path, workspace_execroot, output_base);
  }
  return NormalizeRelativePath(argument, workspace_execroot, output_base);
}

void RequireArity(const std::vector<std::string>& fields, size_t expected,
                  const char* directive) {
  if (fields.size() == expected) {
    return;
  }
  fprintf(stderr,
          "linker_wrapper: invalid contract %s directive (expected %zu fields, got %zu)\n",
          directive, expected, fields.size());
  exit(2);
}

void ApplyContractLine(const Runfiles& runfiles,
                       const std::vector<std::string>& fields,
                       const std::string& workspace_execroot,
                       const std::string& output_base,
                       std::vector<std::string>* arguments) {
  if (fields.empty()) {
    return;
  }

  if (fields[0] == "arg") {
    RequireArity(fields, 2, "arg");
    arguments->push_back(
        NormalizePathLikeArgument(fields[1], workspace_execroot, output_base));
    return;
  }

  if (fields[0] == "runfile") {
    RequireArity(fields, 2, "runfile");
    arguments->push_back(
        ResolveRunfilePath(runfiles, fields[1].c_str(), "contract runfile"));
    return;
  }

  if (fields[0] == "runfile_prefix") {
    RequireArity(fields, 3, "runfile_prefix");
    arguments->push_back(fields[1] +
                         ResolveRunfilePath(runfiles, fields[2].c_str(),
                                            "contract runfile_prefix"));
    return;
  }

  if (fields[0] == "setenv") {
    RequireArity(fields, 3, "setenv");
    if (setenv(fields[1].c_str(), fields[2].c_str(), 1) != 0) {
      fprintf(stderr, "linker_wrapper: setenv failed for '%s': %s\n",
              fields[1].c_str(), strerror(errno));
      exit(2);
    }
    return;
  }

  fprintf(stderr, "linker_wrapper: unknown contract directive '%s'\n",
          fields[0].c_str());
  exit(2);
}

void AppendLinkerContractArguments(const Runfiles& runfiles,
                                   const std::string& contract_path,
                                   const std::string& workspace_execroot,
                                   const std::string& output_base,
                                   std::vector<std::string>* arguments) {
  std::ifstream contract_stream(contract_path);
  if (!contract_stream.is_open()) {
    fprintf(stderr, "linker_wrapper: failed to open linker contract at '%s'\n",
            contract_path.c_str());
    exit(2);
  }

  std::string line;
  while (std::getline(contract_stream, line)) {
    if (line.empty() || line[0] == '#') {
      continue;
    }
    ApplyContractLine(runfiles, ParseContractFields(line), workspace_execroot,
                      output_base, arguments);
  }
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <clang++-style-link-args...>\n"
                    "Example: %s input.o -o output_binary\n",
            argv[0], argv[0]);
    return 2;
  }

  std::string runfiles_error;
  std::unique_ptr<Runfiles> runfiles(
      Runfiles::Create(argv[0], BAZEL_CURRENT_REPOSITORY, &runfiles_error));
  if (!runfiles) {
    fprintf(stderr, "linker_wrapper: failed to initialize runfiles: %s\n",
            runfiles_error.c_str());
    return 2;
  }

  const std::string clang_path =
      ResolveRunfilePath(*runfiles, llvm_toolchain::kLinkerWrapperClangRlocation,
                         "platform clang++");
  const std::string contract_path = ResolveRunfilePath(
      *runfiles, llvm_toolchain::kLinkerWrapperContractRlocation,
      "linker contract");
  const std::string workspace_execroot =
      ResolveWorkspaceExecrootPath(contract_path);
  const std::string output_base = ResolveOutputBasePath(contract_path);

  std::vector<std::string> argument_storage;
  argument_storage.reserve(static_cast<size_t>(argc) + 24);
  argument_storage.push_back(clang_path);

  AppendLinkerContractArguments(*runfiles, contract_path, workspace_execroot,
                                output_base, &argument_storage);

  for (int index = 1; index < argc; ++index) {
    argument_storage.push_back(argv[index]);
  }

  std::vector<char*> exec_arguments;
  exec_arguments.reserve(argument_storage.size() + 1);
  for (std::string& argument : argument_storage) {
    exec_arguments.push_back(const_cast<char*>(argument.c_str()));
  }
  exec_arguments.push_back(nullptr);

  execv(clang_path.c_str(), exec_arguments.data());
  fprintf(stderr, "linker_wrapper: execv failed for '%s': %s\n",
          clang_path.c_str(), strerror(errno));
  return 2;
}
