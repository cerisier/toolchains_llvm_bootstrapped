int windows_msvc_assembly_value(void);

int main(void) {
    return windows_msvc_assembly_value() == 42 ? 0 : 1;
}
