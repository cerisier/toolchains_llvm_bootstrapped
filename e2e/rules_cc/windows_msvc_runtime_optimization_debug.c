#ifdef NDEBUG
#error "debug runtime compilation must not define NDEBUG"
#endif

#ifdef __OPTIMIZE__
#error "debug runtime compilation must disable optimization"
#endif

#ifdef _DEBUG
#error "Windows MSVC runtime compilation never enables a debug CRT"
#endif

int windows_msvc_runtime_optimization_debug(void) { return 42; }
