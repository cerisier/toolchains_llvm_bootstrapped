#include <omp.h>

int main() {
  int sum = 0;

#pragma omp parallel for reduction(+ : sum)
  for (int i = 0; i < 100; ++i) {
    sum += i;
  }

  if (sum != 4950) {
    return 1;
  }

  if (omp_get_max_threads() < 1) {
    return 2;
  }

  return 0;
}
