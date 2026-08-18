#ifndef NDEBUG
#error "optimized runtime compilation must define NDEBUG"
#endif

#ifndef __OPTIMIZE__
#error "optimized runtime compilation must enable optimization"
#endif

#ifdef _DEBUG
#error "Windows MSVC runtime compilation never enables a debug CRT"
#endif

int windows_msvc_runtime_optimization_optimized(void) { return 42; }
