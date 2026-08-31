#include <threads.h>
#include <windows.h>

int windows_msvc_c_smoke(void) {
  const thrd_t current = thrd_current();
  return GetCurrentProcessId() != 0 && thrd_equal(current, current) ? 42 : 0;
}
