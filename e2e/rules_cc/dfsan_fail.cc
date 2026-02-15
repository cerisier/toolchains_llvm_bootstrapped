extern "C" void __dfsan_unimplemented(char *fname);

int main(void) {
    __dfsan_unimplemented((char *)"dfsan_e2e_probe");
    return 0;
}
