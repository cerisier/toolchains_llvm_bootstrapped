#include <iostream>

// Bring in the C function declaration with C linkage.
extern "C" {
#include "add.h"
}

int main() {
	int a = 21;
	int b = 21;

	int result = add(a, b);

	std::cout << "Result from C library: " << result << '\n';

	return 0;
}

