// COFF represents each synthesized vector deleting destructor as a weak alias.
// The vtables keep those aliases live across ThinLTO indexing, exercising the
// prevailing-ownership handling in lld/COFF/LTO.cpp.
struct AbstractValue {
  virtual ~AbstractValue();
  virtual int value() const = 0;
};

struct ConcreteValue final : AbstractValue {
  ~ConcreteValue() override;
  int value() const override { return 42; }
};

AbstractValue::~AbstractValue() = default;
ConcreteValue::~ConcreteValue() = default;

int main() {
  AbstractValue *values = new ConcreteValue[1];
  const int result = values[0].value();
  delete[] static_cast<ConcreteValue *>(values);
  return result == 42 ? 0 : 1;
}
