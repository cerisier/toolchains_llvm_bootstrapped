#include <threads.h>
#include <windows.h>

int main(void) {
  const thrd_t current = thrd_current();
  return GetCurrentProcessId() == 0 || !thrd_equal(current, current);
}
