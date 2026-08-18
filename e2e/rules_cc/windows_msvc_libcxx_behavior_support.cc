#include "windows_msvc_libcxx_behavior_support.h"

#ifndef _LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS
#error "Windows MSVC Layer 1 requires configuration-wide static libc++ annotations"
#endif

#ifndef _LIBCPP_NO_AUTO_LINK
#error "Windows MSVC Layer 1 requires explicit libc++ link inputs"
#endif

#include <atomic>
#include <filesystem>

namespace {
std::atomic<int> alwayslink_marker{0};
}

extern "C" int windows_msvc_alwayslink_marker() {
  return alwayslink_marker.load();
}

extern "C" int windows_msvc_library_filesystem() {
  const std::filesystem::path path =
      (std::filesystem::path(L"library") / L".." / L"dependency")
          .lexically_normal();
  return path.filename().wstring() == L"dependency" ? 42 : 0;
}

extern "C" void windows_msvc_register_alwayslink() {
  alwayslink_marker.fetch_add(1);
}

extern "C" int windows_msvc_ordinary_add(int left, int right) {
  return left + right;
}

extern "C" unsigned long long windows_msvc_wide_divide(
    unsigned long long high,
    unsigned long long low,
    unsigned long long divisor) {
  const unsigned __int128 dividend =
      (static_cast<unsigned __int128>(high) << 64) | low;
  return static_cast<unsigned long long>(dividend / divisor);
}
