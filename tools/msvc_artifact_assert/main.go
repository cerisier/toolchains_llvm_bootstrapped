package main

import (
	"bytes"
	"encoding/binary"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"unicode/utf16"
)

type toolPaths struct {
	Readobj string
	Objdump string
	Ar      string
	Nm      string
}

type artifactSpec struct {
	File     string
	Kind     string
	Machine  string
	Contains []string
	Absent   []string
}

func command(path string, args ...string) (string, error) {
	if path == "" {
		return "", errors.New("required LLVM inspection tool path is empty")
	}
	cmd := exec.Command(path, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output), fmt.Errorf("%s %s: %w\n%s", path, strings.Join(args, " "), err, output)
	}
	return string(output), nil
}

func expectedCOFFMachine(name string) (uint16, string, error) {
	switch strings.ToLower(name) {
	case "amd64", "x86_64", "image_file_machine_amd64":
		return 0x8664, "AMD64", nil
	case "arm64", "aarch64", "image_file_machine_arm64":
		return 0xaa64, "ARM64", nil
	default:
		return 0, "", fmt.Errorf("unsupported archive COFF machine %q", name)
	}
}

func isArchiveMetadataMember(name string) bool {
	return name == "/" || name == "//" || name == "/SYM64/" || name == "/<ECSYMBOLS>/" ||
		name == "__.SYMDEF" || name == "__.SYMDEF SORTED"
}

func inspectArchiveMetadata(path, machineName string) (string, error) {
	wantMachine, canonicalMachine, err := expectedCOFFMachine(machineName)
	if err != nil {
		return "", err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	const magic = "!<arch>\n"
	if !strings.HasPrefix(string(data), magic) {
		return "", errors.New("file does not have the archive magic")
	}
	var lines []string
	objectMembers := 0
	for offset := len(magic); offset < len(data); {
		if len(data)-offset < 60 {
			return "", fmt.Errorf("truncated archive member header at offset %d", offset)
		}
		header := data[offset : offset+60]
		if string(header[58:60]) != "`\n" {
			return "", fmt.Errorf("invalid archive member header at offset %d", offset)
		}
		name := strings.TrimSpace(string(header[0:16]))
		timestampText := strings.TrimSpace(string(header[16:28]))
		var timestamp int64
		if timestampText != "" {
			timestamp, err = strconv.ParseInt(timestampText, 10, 64)
			if err != nil {
				return "", fmt.Errorf("archive member %q has invalid timestamp %q: %w", name, timestampText, err)
			}
		} else if !isArchiveMetadataMember(name) {
			return "", fmt.Errorf("archive member %q has an empty timestamp", name)
		}
		if timestamp != 0 {
			return "", fmt.Errorf("archive member %q timestamp = %d, want 0", name, timestamp)
		}
		sizeText := strings.TrimSpace(string(header[48:58]))
		size, err := strconv.ParseInt(sizeText, 10, 64)
		if err != nil || size < 0 {
			return "", fmt.Errorf("archive member %q has invalid size %q", name, sizeText)
		}
		memberStart := offset + 60
		memberEnd := memberStart + int(size)
		if memberEnd > len(data) {
			return "", fmt.Errorf("archive member %q extends past end of file", name)
		}
		memberData := data[memberStart:memberEnd]
		if strings.HasPrefix(name, "#1/") {
			nameSize, err := strconv.Atoi(strings.TrimPrefix(name, "#1/"))
			if err != nil || nameSize < 0 || nameSize > len(memberData) {
				return "", fmt.Errorf("archive member has invalid BSD name length %q", name)
			}
			name = string(memberData[:nameSize])
			memberData = memberData[nameSize:]
		}
		if isArchiveMetadataMember(name) {
			lines = append(lines, fmt.Sprintf("archive metadata member %q timestamp 0", name))
		} else {
			objectMembers++
			if len(memberData) < 20 {
				return "", fmt.Errorf("archive member %q is too short for a COFF header", name)
			}
			machine := binary.LittleEndian.Uint16(memberData[0:2])
			coffTimestampOffset := 4
			if machine == 0 && binary.LittleEndian.Uint16(memberData[2:4]) == 0xffff {
				if len(memberData) < 12 {
					return "", fmt.Errorf("archive member %q has a truncated bigobj/import header", name)
				}
				machine = binary.LittleEndian.Uint16(memberData[6:8])
				coffTimestampOffset = 8
			}
			if machine != wantMachine {
				return "", fmt.Errorf("archive member %q machine 0x%04x, want %s (0x%04x)", name, machine, canonicalMachine, wantMachine)
			}
			coffTimestamp := binary.LittleEndian.Uint32(memberData[coffTimestampOffset : coffTimestampOffset+4])
			if coffTimestamp != 0 {
				return "", fmt.Errorf("archive member %q COFF timestamp = %d, want 0", name, coffTimestamp)
			}
			lines = append(lines, fmt.Sprintf("archive object member %q machine %s COFF timestamp 0; archive timestamp 0", name, canonicalMachine))
		}
		offset = memberEnd
		if offset%2 != 0 {
			offset++
		}
	}
	if objectMembers == 0 {
		return "", errors.New("archive contains no COFF object members")
	}
	return strings.Join(lines, "\n"), nil
}

const pdbMagic = "Microsoft C/C++ MSF 7.00\r\n\x1aDS\x00\x00\x00"

func pdbBlock(data []byte, blockSize, numBlocks, index uint32) ([]byte, error) {
	if index >= numBlocks {
		return nil, fmt.Errorf("PDB block index %d is outside %d blocks", index, numBlocks)
	}
	start := uint64(index) * uint64(blockSize)
	end := start + uint64(blockSize)
	if end > uint64(len(data)) {
		return nil, fmt.Errorf("PDB block %d extends past end of file", index)
	}
	return data[start:end], nil
}

func parsePDB(data []byte) (string, error) {
	if len(data) < 56 || !bytes.Equal(data[:len(pdbMagic)], []byte(pdbMagic)) {
		return "", errors.New("file does not have the PDB/MSF 7.00 signature and superblock")
	}
	blockSize := binary.LittleEndian.Uint32(data[32:36])
	numBlocks := binary.LittleEndian.Uint32(data[40:44])
	directoryBytes := binary.LittleEndian.Uint32(data[44:48])
	blockMapIndex := binary.LittleEndian.Uint32(data[52:56])
	if blockSize < 512 || blockSize > 1<<20 || blockSize&(blockSize-1) != 0 {
		return "", fmt.Errorf("invalid PDB block size %d", blockSize)
	}
	if numBlocks == 0 || uint64(numBlocks)*uint64(blockSize) != uint64(len(data)) {
		return "", fmt.Errorf("PDB file size %d does not match %d blocks of %d bytes", len(data), numBlocks, blockSize)
	}
	if directoryBytes < 4 || uint64(directoryBytes) > uint64(len(data)) {
		return "", fmt.Errorf("invalid PDB directory size %d", directoryBytes)
	}
	blockMap, err := pdbBlock(data, blockSize, numBlocks, blockMapIndex)
	if err != nil {
		return "", err
	}
	directoryBlockCount := (directoryBytes + blockSize - 1) / blockSize
	if uint64(directoryBlockCount)*4 > uint64(len(blockMap)) {
		return "", errors.New("PDB directory block map exceeds its block")
	}
	directory := make([]byte, 0, uint64(directoryBlockCount)*uint64(blockSize))
	for i := uint32(0); i < directoryBlockCount; i++ {
		index := binary.LittleEndian.Uint32(blockMap[i*4 : i*4+4])
		block, err := pdbBlock(data, blockSize, numBlocks, index)
		if err != nil {
			return "", err
		}
		directory = append(directory, block...)
	}
	directory = directory[:directoryBytes]
	cursor := 0
	readDirectoryUint32 := func() (uint32, error) {
		if cursor+4 > len(directory) {
			return 0, errors.New("truncated PDB stream directory")
		}
		value := binary.LittleEndian.Uint32(directory[cursor : cursor+4])
		cursor += 4
		return value, nil
	}
	numStreams, err := readDirectoryUint32()
	if err != nil {
		return "", err
	}
	if uint64(numStreams)*4 > uint64(len(directory)-cursor) {
		return "", fmt.Errorf("PDB stream count %d exceeds directory", numStreams)
	}
	streamSizes := make([]uint32, numStreams)
	for i := range streamSizes {
		streamSizes[i], err = readDirectoryUint32()
		if err != nil {
			return "", err
		}
	}
	var infoStream []byte
	for streamIndex, size := range streamSizes {
		if size == ^uint32(0) {
			continue
		}
		blockCount := (size + blockSize - 1) / blockSize
		stream := make([]byte, 0, uint64(blockCount)*uint64(blockSize))
		for i := uint32(0); i < blockCount; i++ {
			index, err := readDirectoryUint32()
			if err != nil {
				return "", err
			}
			block, err := pdbBlock(data, blockSize, numBlocks, index)
			if err != nil {
				return "", err
			}
			stream = append(stream, block...)
		}
		if uint64(size) > uint64(len(stream)) {
			return "", fmt.Errorf("PDB stream %d is truncated", streamIndex)
		}
		if streamIndex == 1 {
			infoStream = append([]byte{}, stream[:size]...)
		}
	}
	if cursor != len(directory) {
		return "", fmt.Errorf("PDB stream directory has %d trailing bytes", len(directory)-cursor)
	}
	if len(infoStream) < 28 {
		return "", errors.New("PDB info stream is missing or truncated")
	}
	version := binary.LittleEndian.Uint32(infoStream[0:4])
	signature := binary.LittleEndian.Uint32(infoStream[4:8])
	age := binary.LittleEndian.Uint32(infoStream[8:12])
	guid := infoStream[12:28]
	return fmt.Sprintf("Microsoft C/C++ MSF 7.00 PDB\nBlockSize: %d\nNumBlocks: %d\nNumStreams: %d\nPDB Version: %d\nPDB Signature: %d\nPDB Age: %d\nPDB GUID: %x", blockSize, numBlocks, numStreams, version, signature, age, guid), nil
}

func utf16LittleEndianBytes(value string) []byte {
	words := utf16.Encode([]rune(value))
	encoded := make([]byte, len(words)*2)
	for i, word := range words {
		binary.LittleEndian.PutUint16(encoded[i*2:i*2+2], word)
	}
	return encoded
}

func pdbContains(metadata string, data []byte, needle string) bool {
	return strings.Contains(metadata, needle) || bytes.Contains(data, []byte(needle)) || bytes.Contains(data, utf16LittleEndianBytes(needle))
}

func inspect(tools toolPaths, spec artifactSpec) (string, error) {
	if spec.File == "" || spec.Kind == "" {
		return "", errors.New("both -file and -kind are required")
	}
	var sections []string
	var pdbData []byte
	appendOutput := func(path string, args ...string) error {
		out, err := command(path, args...)
		if err != nil {
			return err
		}
		sections = append(sections, out)
		return nil
	}
	switch spec.Kind {
	case "coff":
		if err := appendOutput(tools.Readobj, "--file-headers", "--coff-directives", spec.File); err != nil {
			return "", err
		}
	case "pe":
		if err := appendOutput(tools.Readobj, "--file-headers", "--coff-imports", "--coff-exports", "--coff-debug-directory", "--codeview", spec.File); err != nil {
			return "", err
		}
		if err := appendOutput(tools.Objdump, "-p", spec.File); err != nil {
			return "", err
		}
	case "archive":
		if spec.Machine == "" {
			return "", errors.New("-machine is required for archive inspection")
		}
		if err := appendOutput(tools.Ar, "t", spec.File); err != nil {
			return "", err
		}
		if err := appendOutput(tools.Nm, "--defined-only", spec.File); err != nil {
			return "", err
		}
		metadata, err := inspectArchiveMetadata(spec.File, spec.Machine)
		if err != nil {
			return "", err
		}
		sections = append(sections, metadata)
		if err := appendOutput(tools.Readobj, "--file-headers", "--coff-directives", spec.File); err != nil {
			return "", err
		}
	case "pdb":
		data, err := os.ReadFile(spec.File)
		if err != nil {
			return "", err
		}
		metadata, err := parsePDB(data)
		if err != nil {
			return "", err
		}
		pdbData = data
		sections = append(sections, metadata)
	default:
		return "", fmt.Errorf("unsupported artifact kind %q", spec.Kind)
	}
	output := strings.Join(sections, "\n")
	if spec.Kind != "archive" && spec.Machine != "" && !strings.Contains(strings.ToLower(output), strings.ToLower(spec.Machine)) {
		return output, fmt.Errorf("inspection does not contain machine %q", spec.Machine)
	}
	for _, needle := range spec.Contains {
		if (spec.Kind == "pdb" && !pdbContains(output, pdbData, needle)) || (spec.Kind != "pdb" && !strings.Contains(output, needle)) {
			return output, fmt.Errorf("inspection does not contain %q", needle)
		}
	}
	for _, needle := range spec.Absent {
		if (spec.Kind == "pdb" && pdbContains(output, pdbData, needle)) || (spec.Kind != "pdb" && strings.Contains(output, needle)) {
			return output, fmt.Errorf("inspection unexpectedly contains %q", needle)
		}
	}
	return output, nil
}

type repeatedFlag []string

func (values *repeatedFlag) String() string { return strings.Join(*values, ",") }
func (values *repeatedFlag) Set(value string) error {
	*values = append(*values, value)
	return nil
}

func main() {
	var containsFlags, absentFlags repeatedFlag
	spec := artifactSpec{}
	tools := toolPaths{}
	flag.StringVar(&spec.File, "file", "", "artifact to inspect")
	flag.StringVar(&spec.Kind, "kind", "", "coff, pe, archive, or pdb")
	flag.StringVar(&spec.Machine, "machine", "", "case-insensitive machine substring")
	flag.Var(&containsFlags, "contains", "required inspection substring; repeatable")
	flag.Var(&absentFlags, "absent", "forbidden inspection substring; repeatable")
	flag.StringVar(&tools.Readobj, "llvm-readobj", "", "path to llvm-readobj")
	flag.StringVar(&tools.Objdump, "llvm-objdump", "", "path to llvm-objdump")
	flag.StringVar(&tools.Ar, "llvm-ar", "", "path to llvm-ar")
	flag.StringVar(&tools.Nm, "llvm-nm", "", "path to llvm-nm")
	flag.Parse()
	spec.Contains, spec.Absent = containsFlags, absentFlags
	output, err := inspect(tools, spec)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		if output != "" {
			fmt.Fprintln(os.Stderr, output)
		}
		os.Exit(1)
	}
	fmt.Print(output)
}
