#include <winsock2.h>
#include <windows.h>

#include <bcrypt.h>
#include <commctrl.h>
#include <iphlpapi.h>
#include <sdkddkver.h>
#include <type_traits>
#include <winternl.h>

int main() {
    WSADATA wsa_data = {};
    SOCKET sock = INVALID_SOCKET;
    (void)wsa_data;
    (void)sock;

    GUID guid = GUID_NULL;
    (void)guid;

    CRITICAL_SECTION cs;
    InitializeCriticalSection(&cs);
    DeleteCriticalSection(&cs);

    MIB_IPADDRROW addr_row = {};
    addr_row.dwAddr = INADDR_ANY;
    (void)addr_row;

    INITCOMMONCONTROLSEX icc = {sizeof(icc), ICC_STANDARD_CLASSES};
    (void)icc;

    BCRYPT_ALG_HANDLE alg_handle = nullptr;
    (void)alg_handle;

    // Exercise the mingw-provided RtlSecureZeroMemory implementation.
    unsigned char secret[16] = {0xde, 0xad, 0xbe, 0xef};
    RtlSecureZeroMemory(secret, sizeof(secret));
    volatile unsigned char zero = secret[0];
    (void)zero;

    static_assert(std::is_same<DWORD, unsigned long>::value, "DWORD changed");

    return 0;
}
