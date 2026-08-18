#ifndef _MT
#error "clang-cl must receive an explicit retail CRT mode"
#endif

#ifndef _DLL
#error "the default Windows MSVC CRT mode must remain /MD"
#endif

int windows_msvc_crt_default_probe(void) { return 42; }
