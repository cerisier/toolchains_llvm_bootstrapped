/* Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
   file Copyright.txt or https://cmake.org/licensing for details.  */

#include "tools/coff_def_parser/def_parser.h"

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <string_view>
#include <vector>

namespace {

constexpr std::uint16_t kI386 = 0x014c;
constexpr std::uint16_t kArm = 0x01c0;
constexpr std::uint16_t kArmNt = 0x01c4;
constexpr std::uint16_t kAmd64 = 0x8664;
constexpr std::uint16_t kArm64 = 0xaa64;
constexpr std::uint16_t kArm64Ec = 0xa641;
constexpr std::uint32_t kExecute = 0x20000000;
constexpr std::uint32_t kRead = 0x40000000;
constexpr std::uint32_t kWrite = 0x80000000;

class TemporaryDirectory {
public:
  TemporaryDirectory() {
    path_ = std::filesystem::temp_directory_path() /
            ("coff-def-parser-test-" +
             std::to_string(
                 std::chrono::steady_clock::now().time_since_epoch().count()));
    std::filesystem::create_directories(path_);
  }

  ~TemporaryDirectory() {
    std::error_code error;
    std::filesystem::remove_all(path_, error);
  }

  const std::filesystem::path &path() const { return path_; }

private:
  std::filesystem::path path_;
};

struct Symbol {
  std::string name;
  std::int32_t section;
  std::uint16_t type;
  std::uint8_t auxiliary_count = 0;
};

void Set16(std::vector<std::uint8_t> *bytes, std::size_t offset,
           std::uint16_t value) {
  (*bytes)[offset] = static_cast<std::uint8_t>(value);
  (*bytes)[offset + 1] = static_cast<std::uint8_t>(value >> 8);
}

void Set32(std::vector<std::uint8_t> *bytes, std::size_t offset,
           std::uint32_t value) {
  (*bytes)[offset] = static_cast<std::uint8_t>(value);
  (*bytes)[offset + 1] = static_cast<std::uint8_t>(value >> 8);
  (*bytes)[offset + 2] = static_cast<std::uint8_t>(value >> 16);
  (*bytes)[offset + 3] = static_cast<std::uint8_t>(value >> 24);
}

void AppendName(const std::string &name, std::vector<std::uint8_t> *record,
                std::size_t offset, std::vector<std::uint8_t> *strings) {
  if (name.size() <= 8) {
    std::memcpy(record->data() + offset, name.data(), name.size());
    return;
  }
  Set32(record, offset, 0);
  Set32(record, offset + 4, static_cast<std::uint32_t>(strings->size()));
  strings->insert(strings->end(), name.begin(), name.end());
  strings->push_back(0);
}

std::uint32_t SymbolCount(const std::vector<Symbol> &symbols) {
  std::uint32_t count = 0;
  for (const Symbol &symbol : symbols) {
    count += 1 + symbol.auxiliary_count;
  }
  return count;
}

std::vector<std::uint8_t>
MakeCoff(std::uint16_t machine,
         const std::vector<std::uint32_t> &section_characteristics,
         const std::vector<Symbol> &symbols) {
  constexpr std::size_t kHeaderSize = 20;
  constexpr std::size_t kSectionSize = 40;
  constexpr std::size_t kSymbolSize = 18;
  const std::size_t symbol_table =
      kHeaderSize + section_characteristics.size() * kSectionSize;
  std::vector<std::uint8_t> object(symbol_table, 0);
  Set16(&object, 0, machine);
  Set16(&object, 2, static_cast<std::uint16_t>(section_characteristics.size()));
  Set32(&object, 8, static_cast<std::uint32_t>(symbol_table));
  Set32(&object, 12, SymbolCount(symbols));
  for (std::size_t index = 0; index < section_characteristics.size(); ++index) {
    Set32(&object, kHeaderSize + index * kSectionSize + 36,
          section_characteristics[index]);
  }

  std::vector<std::uint8_t> strings(4, 0);
  for (const Symbol &symbol : symbols) {
    const std::size_t offset = object.size();
    object.resize(offset + kSymbolSize, 0);
    AppendName(symbol.name, &object, offset, &strings);
    Set16(&object, offset + 12, static_cast<std::uint16_t>(symbol.section));
    Set16(&object, offset + 14, symbol.type);
    object[offset + 16] = 2;
    object[offset + 17] = symbol.auxiliary_count;
    object.resize(object.size() + symbol.auxiliary_count * kSymbolSize, 0);
  }
  Set32(&strings, 0, static_cast<std::uint32_t>(strings.size()));
  object.insert(object.end(), strings.begin(), strings.end());
  return object;
}

std::vector<std::uint8_t>
MakeBigObj(std::uint16_t machine,
           const std::vector<std::uint32_t> &section_characteristics,
           const std::vector<Symbol> &symbols) {
  constexpr std::size_t kHeaderSize = 56;
  constexpr std::size_t kSectionSize = 40;
  constexpr std::size_t kSymbolSize = 20;
  const std::size_t symbol_table =
      kHeaderSize + section_characteristics.size() * kSectionSize;
  std::vector<std::uint8_t> object(symbol_table, 0);
  Set16(&object, 2, 0xffff);
  Set16(&object, 4, 2);
  Set16(&object, 6, machine);
  Set32(&object, 44,
        static_cast<std::uint32_t>(section_characteristics.size()));
  Set32(&object, 48, static_cast<std::uint32_t>(symbol_table));
  Set32(&object, 52, SymbolCount(symbols));
  for (std::size_t index = 0; index < section_characteristics.size(); ++index) {
    Set32(&object, kHeaderSize + index * kSectionSize + 36,
          section_characteristics[index]);
  }

  std::vector<std::uint8_t> strings(4, 0);
  for (const Symbol &symbol : symbols) {
    const std::size_t offset = object.size();
    object.resize(offset + kSymbolSize, 0);
    AppendName(symbol.name, &object, offset, &strings);
    Set32(&object, offset + 12, static_cast<std::uint32_t>(symbol.section));
    Set16(&object, offset + 16, symbol.type);
    object[offset + 18] = 2;
    object[offset + 19] = symbol.auxiliary_count;
    object.resize(object.size() + symbol.auxiliary_count * kSymbolSize, 0);
  }
  Set32(&strings, 0, static_cast<std::uint32_t>(strings.size()));
  object.insert(object.end(), strings.begin(), strings.end());
  return object;
}

bool WriteBytes(const std::filesystem::path &path,
                const std::vector<std::uint8_t> &bytes) {
  std::ofstream output(path, std::ios::binary);
  output.write(reinterpret_cast<const char *>(bytes.data()),
               static_cast<std::streamsize>(bytes.size()));
  return output.good();
}

bool WriteText(const std::filesystem::path &path, std::string_view contents) {
  std::ofstream output(path, std::ios::binary);
  output << contents;
  return output.good();
}

bool ReadText(const std::filesystem::path &path, std::string *contents) {
  std::ifstream input(path, std::ios::binary);
  contents->assign(std::istreambuf_iterator<char>(input),
                   std::istreambuf_iterator<char>());
  return input.good() || input.eof();
}

bool Render(DefParser *parser, const std::filesystem::path &path,
            std::string *contents) {
  FILE *output = std::fopen(path.string().c_str(), "wb");
  if (!output) {
    std::cerr << "failed to open output " << path << '\n';
    return false;
  }
  parser->WriteFile(output);
  std::fclose(output);
  return ReadText(path, contents);
}

bool ExpectEqual(std::string_view actual, std::string_view expected) {
  if (actual == expected) {
    return true;
  }
  std::cerr << "unexpected DEF output\nactual:\n"
            << actual << "expected:\n"
            << expected;
  return false;
}

bool TestNormalCoffSymbolClassificationAndSorting() {
  TemporaryDirectory temporary;
  const std::filesystem::path object = temporary.path() / "symbols.obj";
  if (!WriteBytes(object,
                  MakeCoff(kAmd64, {kRead | kExecute, kRead | kWrite, kRead},
                           {
                               {"zeta", 1, 0x20},
                               {"Alpha", 1, 0x20},
                               {"dataZeta", 2, 0},
                               {"dataAlpha", 2, 0},
                               {"constant", 3, 0},
                               {"??_7Vtable", 3, 0},
                               {"??_Gdeleting", 1, 0x20},
                               {"??_Edeleting", 1, 0x20},
                               {"with.dot", 1, 0x20},
                               // The current fixed-width short-name handling
                               // accidentally retains trailing NULs, so this
                               // managed-code sentinel is exported. Keep that
                               // fail-before baseline explicit until the C port
                               // fixes all managed short-name filters.
                               {"__t2m", 1, 0x20},
                               {"managed$$Fsymbol", 1, 0x20},
                           }))) {
    return false;
  }

  DefParser parser;
  parser.SetDLLName("sample.dll");
  if (!parser.AddObjectFile(object.string().c_str())) {
    return false;
  }
  std::string output;
  return Render(&parser, temporary.path() / "symbols.def", &output) &&
         ExpectEqual(output, "LIBRARY sample.dll\n"
                             "EXPORTS \n"
                             "\tdataAlpha \t DATA\n"
                             "\tdataZeta \t DATA\n"
                             "\t??_7Vtable\n"
                             "\tAlpha\n"
                             "\t__t2m\n"
                             "\tzeta\n");
}

bool TestArchitectureSpecificSymbols() {
  TemporaryDirectory temporary;
  struct ObjectSpec {
    const char *name;
    std::uint16_t machine;
    std::vector<Symbol> symbols;
  };
  const std::vector<ObjectSpec> objects = {
      {"i386.obj", kI386, {{"_stdcall@8", 1, 0x20}}},
      {"amd64.obj", kAmd64, {{"_amd64", 1, 0x20}}},
      {"arm.obj", kArm, {{"_arm", 1, 0x20}}},
      {"arm64.obj", kArm64, {{"_arm64", 1, 0x20}}},
      {"armnt.obj", kArmNt, {{"_armnt", 1, 0x20}}},
      {"arm64ec.obj",
       kArm64Ec,
       {{"arm64ec", 1, 0x20}, {"func$entry_thunk", 1, 0x20}}},
  };

  DefParser parser;
  for (const ObjectSpec &spec : objects) {
    const std::filesystem::path path = temporary.path() / spec.name;
    if (!WriteBytes(path,
                    MakeCoff(spec.machine, {kRead | kExecute}, spec.symbols)) ||
        !parser.AddObjectFile(path.string().c_str())) {
      return false;
    }
  }
  std::string output;
  return Render(&parser, temporary.path() / "architectures.def", &output) &&
         ExpectEqual(output, "EXPORTS \n"
                             "\t_amd64\n"
                             "\t_arm\n"
                             "\t_arm64\n"
                             "\t_armnt\n"
                             "\tarm64ec\n"
                             "\tstdcall\n");
}

bool TestBigObjAndAuxiliarySymbols() {
  TemporaryDirectory temporary;
  const std::filesystem::path object = temporary.path() / "symbols-big.obj";
  if (!WriteBytes(object, MakeBigObj(kI386, {kRead | kExecute},
                                     {{"_bigobj@4", 1, 0x20, 1},
                                      {"afteraux", 1, 0x20}}))) {
    return false;
  }
  DefParser parser;
  if (!parser.AddObjectFile(object.string().c_str())) {
    return false;
  }
  std::string output;
  return Render(&parser, temporary.path() / "bigobj.def", &output) &&
         ExpectEqual(output, "EXPORTS \n"
                             "\tafteraux\n"
                             "\tbigobj\n");
}

bool TestDefinitionFileMerge() {
  TemporaryDirectory temporary;
  const std::filesystem::path input = temporary.path() / "existing.DEF";
  if (!WriteText(input, "LIBRARY old.dll\n"
                        "EXPORTS\n"
                        "  ExistingData \t DATA\n"
                        "  Existing\n")) {
    return false;
  }
  DefParser parser;
  parser.SetDLLName("new.dll");
  if (!parser.AddFile(input.string())) {
    return false;
  }
  std::string output;
  return Render(&parser, temporary.path() / "merged.def", &output) &&
         ExpectEqual(output, "LIBRARY new.dll\n"
                             "EXPORTS \n"
                             "\tExistingData \t DATA\n"
                             "\tExisting\n");
}

bool TestMalformedObjectsAreRejected() {
  TemporaryDirectory temporary;

  const std::filesystem::path too_small = temporary.path() / "small.obj";
  const std::filesystem::path truncated = temporary.path() / "truncated.obj";
  const std::filesystem::path invalid_section =
      temporary.path() / "invalid-section.obj";
  const std::filesystem::path truncated_bigobj =
      temporary.path() / "truncated-big.obj";

  std::vector<std::uint8_t> truncated_bytes(20, 0);
  Set16(&truncated_bytes, 0, kAmd64);
  Set16(&truncated_bytes, 2, 1);
  Set32(&truncated_bytes, 8, 60);

  std::vector<std::uint8_t> truncated_bigobj_bytes(56, 0);
  Set16(&truncated_bigobj_bytes, 2, 0xffff);
  Set16(&truncated_bigobj_bytes, 4, 2);
  Set16(&truncated_bigobj_bytes, 6, kAmd64);
  Set32(&truncated_bigobj_bytes, 44, 1);
  Set32(&truncated_bigobj_bytes, 48, 96);
  Set32(&truncated_bigobj_bytes, 52, 1);

  if (!WriteBytes(too_small, {0}) || !WriteBytes(truncated, truncated_bytes) ||
      !WriteBytes(invalid_section, MakeCoff(kAmd64, {kRead | kExecute},
                                            {{"invalid", 2, 0x20}})) ||
      !WriteBytes(truncated_bigobj, truncated_bigobj_bytes)) {
    return false;
  }

  DefParser parser;
  return !parser.AddObjectFile(too_small.string().c_str()) &&
         !parser.AddObjectFile(truncated.string().c_str()) &&
         !parser.AddObjectFile(invalid_section.string().c_str()) &&
         !parser.AddObjectFile(truncated_bigobj.string().c_str());
}

} // namespace

int main() {
  if (!TestNormalCoffSymbolClassificationAndSorting() ||
      !TestArchitectureSpecificSymbols() || !TestBigObjAndAuxiliarySymbols() ||
      !TestDefinitionFileMerge() || !TestMalformedObjectsAreRejected()) {
    return 1;
  }
  return 0;
}
