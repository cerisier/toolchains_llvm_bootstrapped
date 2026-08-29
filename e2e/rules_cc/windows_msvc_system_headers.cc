#include <comdef.h>
#include <intrin.h>
#include <stdio.h>
#include <vcruntime.h>
#include <windows.h>
#include <winstring.h>

#include <vector>

int windows_msvc_system_headers() {
  FILE* stream = nullptr;
  _com_error* com_error = nullptr;
  HSTRING string = nullptr;
  std::vector<DWORD> values = {sizeof(stream), sizeof(com_error), sizeof(string)};
  return static_cast<int>(values.front());
}
