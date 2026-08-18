#include <exception>
#include <utility>

namespace {

struct payload {
  explicit payload(int value) : value(value) {}
  payload(const payload& other) : value(other.value) {}
  ~payload() { value = -1; }

  int value;
};

std::exception_ptr capture(int value) {
  try {
    throw payload(value);
  } catch (...) {
    return std::current_exception();
  }
}

int rethrow_value(const std::exception_ptr& exception) {
  try {
    std::rethrow_exception(exception);
  } catch (const payload& caught) {
    return caught.value;
  }
}

}  // namespace

int main() {
  std::exception_ptr original = capture(42);
  if (!original || rethrow_value(original) != 42) {
    return 1;
  }

  std::exception_ptr copied(original);
  if (copied != original || rethrow_value(copied) != 42) {
    return 2;
  }

  std::exception_ptr assigned;
  assigned = copied;
  std::swap(assigned, copied);
  if (!assigned || rethrow_value(assigned) != 42) {
    return 3;
  }

  std::exception_ptr made = std::make_exception_ptr(payload(7));
  if (!made || rethrow_value(made) != 7) {
    return 4;
  }

  return 0;
}
