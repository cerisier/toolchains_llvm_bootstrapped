#if defined(__APPLE__)
.comm _comm_tentative_symbol,4
#else
.comm comm_tentative_symbol,4
#endif
