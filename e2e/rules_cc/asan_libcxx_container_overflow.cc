#include <sys/utsname.h>

#include <iostream>
#include <string>

std::string get_greet_with_sysinfo(const std::string &who) {
  std::string greet = "Hello " + std::string{who};

  utsname linux_info{};
  if (uname(&linux_info) != 0)
    return greet;

  greet += " (running on Linux kernel: " + std::string(linux_info.release) +
           " " + linux_info.machine + ")";
  return greet;
}

int main(int argc, char **argv) {
  const std::string who = argc > 1 ? argv[1] : "bazel";
  const std::string value = get_greet_with_sysinfo(who);
  std::cout << value << std::endl;

  // basic_string::append must unpoison the short-string storage before
  // replacing the short representation with the long representation.
  volatile char terminator = value.c_str()[value.size()];
  return terminator == '\0' ? 0 : 1;
}
