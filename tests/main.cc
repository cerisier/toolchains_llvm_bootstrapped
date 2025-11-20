#include <iostream>
#include <cstdlib>
#include <stdexcept>


extern "C" int __cxa_atexit(void (*func)(void*), void* arg, void* dso_handle);

// A simple class to track lifetime
class Foo {
public:
    Foo() { std::cout << "[Foo] Constructor\n"; }
    ~Foo() { std::cout << "[Foo] Destructor\n"; }
};

// Global object to show constructor and destructor
Foo global_foo;

// Manually registered function with __cxa_atexit
void on_exit_callback(void* arg) {
    std::cout << "[__cxa_atexit] Callback: " << static_cast<const char*>(arg) << "\n";
}

// Function that throws an exception
void throw_something() {
    std::cout << "[throw_something] About to throw\n";
    throw std::runtime_error("Something went wrong!");
}

// Runs before main()
__attribute__((constructor))
static void before_main() {
    std::cout << "[constructor] Before main()\n";
    const char* msg = "Goodbye from __cxa_atexit";
    __cxa_atexit(on_exit_callback, (void*)msg, nullptr);
}

// Runs after global destructors
__attribute__((destructor))
static void after_main() {
    std::cout << "[destructor] After main()\n";
}

int main() {
    std::cout << "[main] Inside main()\n";

    try {
        throw_something();
    } catch (const std::exception& ex) {
        std::cout << "[main] Caught exception: " << ex.what() << "\n";
    }

    std::cout << "[main] Exiting main()\n";
    return 0;
}
