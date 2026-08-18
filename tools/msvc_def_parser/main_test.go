package main

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type testSymbol struct {
	name    string
	section int16
	typeID  uint16
	class   byte
}

func testObject(t *testing.T, path string, machine uint16, symbols []testSymbol) {
	t.Helper()
	const sections = 3
	symbolOffset := coffHeaderSize + sections*coffSectionSize
	stringTable := []byte{0, 0, 0, 0}
	records := make([]byte, len(symbols)*coffSymbolSize)
	for index, symbol := range symbols {
		record := records[index*coffSymbolSize : (index+1)*coffSymbolSize]
		if len(symbol.name) <= 8 {
			copy(record[:8], symbol.name)
		} else {
			binary.LittleEndian.PutUint32(record[4:8], uint32(len(stringTable)))
			stringTable = append(stringTable, []byte(symbol.name)...)
			stringTable = append(stringTable, 0)
		}
		binary.LittleEndian.PutUint16(record[12:14], uint16(symbol.section))
		binary.LittleEndian.PutUint16(record[14:16], symbol.typeID)
		record[16] = symbol.class
	}
	binary.LittleEndian.PutUint32(stringTable[:4], uint32(len(stringTable)))
	data := make([]byte, symbolOffset+len(records)+len(stringTable))
	binary.LittleEndian.PutUint16(data[0:2], machine)
	binary.LittleEndian.PutUint16(data[2:4], sections)
	binary.LittleEndian.PutUint32(data[8:12], uint32(symbolOffset))
	binary.LittleEndian.PutUint32(data[12:16], uint32(len(symbols)))
	sectionData := data[coffHeaderSize:symbolOffset]
	binary.LittleEndian.PutUint32(sectionData[36:40], sectionMemoryRead|sectionMemoryExecute)
	binary.LittleEndian.PutUint32(sectionData[coffSectionSize+36:coffSectionSize+40], sectionMemoryRead|sectionMemoryWrite)
	binary.LittleEndian.PutUint32(sectionData[2*coffSectionSize+36:2*coffSectionSize+40], sectionMemoryRead)
	copy(data[symbolOffset:], records)
	copy(data[symbolOffset+len(records):], stringTable)
	if err := os.WriteFile(path, data, 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestRunGeneratesDeterministicDefinition(t *testing.T) {
	directory := t.TempDir()
	object := filepath.Join(directory, "object space λ.obj")
	testObject(t, object, 0x8664, []testSymbol{
		{name: "shortfn", section: 1, typeID: 0x20, class: symbolClassExternal},
		{name: "?decorated_function@@YAHH@Z", section: 1, typeID: 0x20, class: symbolClassExternal},
		{name: "writable", section: 2, class: symbolClassExternal},
		{name: "constant", section: 3, class: symbolClassExternal},
		{name: "??_Gdeleted", section: 1, typeID: 0x20, class: symbolClassExternal},
		{name: "has.dot", section: 1, typeID: 0x20, class: symbolClassExternal},
		{name: "local", section: 1, typeID: 0x20, class: 3},
	})
	inputDefinition := filepath.Join(directory, "existing.def")
	if err := os.WriteFile(inputDefinition, []byte("LIBRARY old\nEXPORTS\n merged\n global DATA\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	response := filepath.Join(directory, "inputs.rsp")
	responseText := "'" + object + "'\n'" + inputDefinition + "'\n"
	if err := os.WriteFile(response, []byte(responseText), 0o600); err != nil {
		t.Fatal(err)
	}
	output := filepath.Join(directory, "generated.def")
	if err := run([]string{output, "sample.dll", "@" + response}); err != nil {
		t.Fatal(err)
	}
	contents, err := os.ReadFile(output)
	if err != nil {
		t.Fatal(err)
	}
	want := "LIBRARY sample.dll\nEXPORTS\n\tglobal \t DATA\n\twritable \t DATA\n\t?decorated_function@@YAHH@Z\n\tmerged\n\tshortfn\n"
	if string(contents) != want {
		t.Fatalf("definition mismatch\nwant:\n%s\ngot:\n%s", want, contents)
	}
}

func TestI386AndARM64Symbols(t *testing.T) {
	for _, test := range []struct {
		name    string
		machine uint16
		symbol  string
		want    string
	}{
		{name: "i386", machine: 0x014c, symbol: "_function@8", want: "function"},
		{name: "arm64", machine: 0xaa64, symbol: "arm64_function", want: "arm64_function"},
	} {
		t.Run(test.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "input.obj")
			testObject(t, path, test.machine, []testSymbol{{name: test.symbol, section: 1, typeID: 0x20, class: symbolClassExternal}})
			result := newExports()
			if err := parseObject(path, result); err != nil {
				t.Fatal(err)
			}
			if !result.functions[test.want] {
				t.Fatalf("missing normalized symbol %q in %#v", test.want, result.functions)
			}
		})
	}
}

func TestParseShellWords(t *testing.T) {
	words, err := parseShellWords(`'space path.obj' "unicode λ.obj" plain\ path.obj`)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"space path.obj", "unicode λ.obj", "plain path.obj"}
	if strings.Join(words, "|") != strings.Join(want, "|") {
		t.Fatalf("got %#v, want %#v", words, want)
	}
	if _, err := parseShellWords(`'unterminated`); err == nil {
		t.Fatal("unterminated quote unexpectedly accepted")
	}
}
