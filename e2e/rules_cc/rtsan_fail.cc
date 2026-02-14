#include <stdlib.h>

extern "C" void __rtsan_ensure_initialized(void);
extern "C" void __rtsan_realtime_enter(void);
extern "C" void __rtsan_realtime_exit(void);
extern "C" void __rtsan_notify_intercepted_call(const char *func_name);

int main(void) {
    __rtsan_ensure_initialized();
    __rtsan_realtime_enter();
    // Drive the runtime through a deterministic violation path.
    __rtsan_notify_intercepted_call("rtsan_e2e_probe");
    __rtsan_realtime_exit();
    return 0;
}
