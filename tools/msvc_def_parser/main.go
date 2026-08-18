package main

// COFF export filtering and its test cases are a portable Go adaptation of
// bazelbuild/bazel third_party/def_parser at
// 8220c6198837d5c13d53fea211cf3282aa12408a (Bazel 9.2.0). That implementation
// derives from CMake's bindexplib and is distributed under BSD-3-Clause; see
// COPYING.bazel-def-parser in this directory.

import (
	"bufio"
	"encoding/binary"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const (
	coffHeaderSize       = 20
	coffSectionSize      = 40
	coffSymbolSize       = 18
	bigObjectHeaderSize  = 56
	bigObjectSymbolSize  = 20
	symbolClassExternal  = 2
	sectionMemoryExecute = 0x20000000
	sectionMemoryRead    = 0x40000000
	sectionMemoryWrite   = 0x80000000
)

var supportedMachines = map[uint16]bool{
	0x014c: true, // I386
	0x01c0: true, // ARM
	0x01c4: true, // ARMNT
	0x8664: true, // AMD64
	0xa641: true, // ARM64EC
	0xaa64: true, // ARM64
}

type exports struct {
	functions map[string]bool
	data      map[string]bool
}

func newExports() *exports {
	return &exports{functions: map[string]bool{}, data: map[string]bool{}}
}

func rangeAt(data []byte, offset, size int, description string) ([]byte, error) {
	if offset < 0 || size < 0 || offset > len(data) || size > len(data)-offset {
		return nil, fmt.Errorf("%s extends past end of file", description)
	}
	return data[offset : offset+size], nil
}

func cString(data []byte) string {
	if index := strings.IndexByte(string(data), 0); index >= 0 {
		data = data[:index]
	}
	return string(data)
}

func symbolName(record, stringTable []byte) (string, error) {
	if binary.LittleEndian.Uint32(record[:4]) != 0 {
		return cString(record[:8]), nil
	}
	offset := int(binary.LittleEndian.Uint32(record[4:8]))
	if offset < 4 || offset >= len(stringTable) {
		return "", fmt.Errorf("COFF symbol has invalid string-table offset %d", offset)
	}
	return cString(stringTable[offset:]), nil
}

func normalizeSymbol(symbol string, i386 bool) string {
	symbol = strings.TrimSpace(symbol)
	if strings.HasPrefix(symbol, "_") {
		if index := strings.IndexByte(symbol, '@'); index >= 0 {
			symbol = symbol[:index]
		}
	}
	if i386 {
		symbol = strings.TrimPrefix(symbol, "_")
	}
	return symbol
}

func excludedSymbol(symbol string, arm64ec bool) bool {
	if symbol == "" || strings.Contains(symbol, ".") ||
		strings.HasPrefix(symbol, "??_G") || strings.HasPrefix(symbol, "??_E") ||
		symbol == "__t2m" || symbol == "__m2mep" || symbol == "__mep" ||
		strings.Contains(symbol, "$$F") || strings.Contains(symbol, "$$J") {
		return true
	}
	if arm64ec {
		for _, suffix := range []string{"$ientry_thunk", "$entry_thunk", "$iexit_thunk", "$exit_thunk"} {
			if strings.Contains(symbol, suffix) {
				return true
			}
		}
	}
	return false
}

func parseObject(path string, result *exports) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if len(data) < coffHeaderSize {
		return errors.New("COFF object is shorter than its header")
	}

	machine := binary.LittleEndian.Uint16(data[0:2])
	sectionCount := int(binary.LittleEndian.Uint16(data[2:4]))
	symbolOffset := int(binary.LittleEndian.Uint32(data[8:12]))
	symbolCount := int(binary.LittleEndian.Uint32(data[12:16]))
	sectionOffset := coffHeaderSize + int(binary.LittleEndian.Uint16(data[16:18]))
	symbolSize := coffSymbolSize
	sectionNumberOffset := 12
	typeOffset := 14
	classOffset := 16
	auxOffset := 17

	bigObject := machine == 0 && binary.LittleEndian.Uint16(data[2:4]) == 0xffff
	if bigObject {
		if len(data) < bigObjectHeaderSize {
			return errors.New("bigobj header is truncated")
		}
		machine = binary.LittleEndian.Uint16(data[6:8])
		sectionCount = int(binary.LittleEndian.Uint32(data[44:48]))
		symbolOffset = int(binary.LittleEndian.Uint32(data[48:52]))
		symbolCount = int(binary.LittleEndian.Uint32(data[52:56]))
		sectionOffset = bigObjectHeaderSize
		symbolSize = bigObjectSymbolSize
		typeOffset = 16
		classOffset = 18
		auxOffset = 19
	}
	if !supportedMachines[machine] {
		return fmt.Errorf("unsupported COFF machine 0x%04x", machine)
	}
	if !bigObject && binary.LittleEndian.Uint16(data[18:20]) != 0 {
		return errors.New("linked COFF images are not valid DEF inputs")
	}

	sectionsData, err := rangeAt(data, sectionOffset, sectionCount*coffSectionSize, "COFF section table")
	if err != nil {
		return err
	}
	sections := make([]uint32, sectionCount)
	for i := range sections {
		sections[i] = binary.LittleEndian.Uint32(sectionsData[i*coffSectionSize+36 : i*coffSectionSize+40])
	}
	symbolsData, err := rangeAt(data, symbolOffset, symbolCount*symbolSize, "COFF symbol table")
	if err != nil {
		return err
	}
	stringOffset := symbolOffset + symbolCount*symbolSize
	lengthData, err := rangeAt(data, stringOffset, 4, "COFF string-table length")
	if err != nil {
		return err
	}
	stringLength := int(binary.LittleEndian.Uint32(lengthData))
	if stringLength < 4 {
		return errors.New("COFF string table is shorter than its length field")
	}
	stringTable, err := rangeAt(data, stringOffset, stringLength, "COFF string table")
	if err != nil {
		return err
	}

	for index := 0; index < symbolCount; {
		record := symbolsData[index*symbolSize : (index+1)*symbolSize]
		var sectionNumber int
		if bigObject {
			sectionNumber = int(int32(binary.LittleEndian.Uint32(record[sectionNumberOffset : sectionNumberOffset+4])))
		} else {
			sectionNumber = int(int16(binary.LittleEndian.Uint16(record[sectionNumberOffset : sectionNumberOffset+2])))
		}
		typeValue := binary.LittleEndian.Uint16(record[typeOffset : typeOffset+2])
		auxCount := int(record[auxOffset])
		if sectionNumber > 0 && sectionNumber <= len(sections) &&
			(typeValue == 0 || typeValue == 0x20) && record[classOffset] == symbolClassExternal {
			symbol, nameErr := symbolName(record, stringTable)
			if nameErr != nil {
				return nameErr
			}
			symbol = normalizeSymbol(symbol, machine == 0x014c)
			if !excludedSymbol(symbol, machine == 0xa641) {
				characteristics := sections[sectionNumber-1]
				if typeValue == 0 && characteristics&sectionMemoryWrite != 0 {
					if !result.functions[symbol] {
						result.data[symbol] = true
					}
				} else if typeValue != 0 || characteristics&sectionMemoryRead == 0 ||
					characteristics&sectionMemoryExecute != 0 || strings.HasPrefix(symbol, "??_7") {
					result.functions[symbol] = true
					delete(result.data, symbol)
				}
			}
		}
		index += 1 + auxCount
		if index > symbolCount {
			return errors.New("COFF auxiliary symbol count exceeds symbol table")
		}
	}
	return nil
}

func parseDefinition(path string, result *exports) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		upper := strings.ToUpper(line)
		if line == "" || strings.HasPrefix(upper, "LIBRARY") || upper == "EXPORTS" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		name := fields[0]
		isData := false
		for _, field := range fields[1:] {
			if strings.EqualFold(field, "DATA") {
				isData = true
			}
		}
		if isData {
			result.data[name] = true
		} else {
			result.functions[name] = true
		}
	}
	return scanner.Err()
}

func parseShellWords(input string) ([]string, error) {
	var words []string
	var current strings.Builder
	quote := rune(0)
	escaped := false
	started := false
	flush := func() {
		if started {
			words = append(words, current.String())
			current.Reset()
			started = false
		}
	}
	for _, character := range input {
		if escaped {
			current.WriteRune(character)
			escaped = false
			started = true
			continue
		}
		if quote == '\'' {
			if character == '\'' {
				quote = 0
			} else {
				current.WriteRune(character)
			}
			started = true
			continue
		}
		if quote == '"' {
			switch character {
			case '"':
				quote = 0
			case '\\':
				escaped = true
			default:
				current.WriteRune(character)
			}
			started = true
			continue
		}
		switch character {
		case '\'', '"':
			quote = character
			started = true
		case '\\':
			escaped = true
			started = true
		case ' ', '\t', '\r', '\n':
			flush()
		default:
			current.WriteRune(character)
			started = true
		}
	}
	if quote != 0 || escaped {
		return nil, errors.New("unterminated quote or escape in response file")
	}
	flush()
	return words, nil
}

func expandArguments(arguments []string, depth int) ([]string, error) {
	if depth > 16 {
		return nil, errors.New("response-file nesting exceeds 16 levels")
	}
	var expanded []string
	for _, argument := range arguments {
		if !strings.HasPrefix(argument, "@") {
			expanded = append(expanded, argument)
			continue
		}
		contents, err := os.ReadFile(strings.TrimPrefix(argument, "@"))
		if err != nil {
			return nil, err
		}
		words, err := parseShellWords(string(contents))
		if err != nil {
			return nil, err
		}
		words, err = expandArguments(words, depth+1)
		if err != nil {
			return nil, err
		}
		expanded = append(expanded, words...)
	}
	return expanded, nil
}

func writeDefinition(path, dllName string, result *exports) error {
	var lines []string
	if dllName != "" {
		lines = append(lines, "LIBRARY "+dllName)
	}
	lines = append(lines, "EXPORTS")
	dataNames := make([]string, 0, len(result.data))
	for name := range result.data {
		dataNames = append(dataNames, name)
	}
	functionNames := make([]string, 0, len(result.functions))
	for name := range result.functions {
		functionNames = append(functionNames, name)
	}
	sort.Strings(dataNames)
	sort.Strings(functionNames)
	for _, name := range dataNames {
		lines = append(lines, "\t"+name+" \t DATA")
	}
	for _, name := range functionNames {
		lines = append(lines, "\t"+name)
	}
	return os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0o666)
}

func run(arguments []string) error {
	arguments, err := expandArguments(arguments, 0)
	if err != nil {
		return err
	}
	if len(arguments) < 3 {
		return errors.New("usage: msvc_def_parser output.def dllname object-or-def ...")
	}
	result := newExports()
	for _, input := range arguments[2:] {
		if strings.EqualFold(filepath.Ext(input), ".def") {
			err = parseDefinition(input, result)
		} else {
			err = parseObject(input, result)
		}
		if err != nil {
			return fmt.Errorf("parse %s: %w", input, err)
		}
	}
	return writeDefinition(arguments[0], arguments[1], result)
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
