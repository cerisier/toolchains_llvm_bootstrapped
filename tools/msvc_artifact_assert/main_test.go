package main

import (
	"encoding/binary"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

func requireEnv(t *testing.T, key string) string {
	t.Helper()
	value := os.Getenv(key)
	if value == "" {
		t.Fatalf("%s is not set", key)
	}
	path, err := runfiles.Rlocation(value)
	if err != nil {
		t.Fatalf("resolve %s runfile %q: %v", key, value, err)
	}
	return path
}

func runTool(t *testing.T, path string, args ...string) {
	t.Helper()
	output, err := exec.Command(path, args...).CombinedOutput()
	if err != nil {
		t.Fatalf("%s %s: %v\n%s", path, strings.Join(args, " "), err, output)
	}
}

func TestRealCOFFPEAndArchive(t *testing.T) {
	clangCL := requireEnv(t, "CLANG_CL")
	lldLink := requireEnv(t, "LLD_LINK")
	tools := toolPaths{
		Readobj: requireEnv(t, "LLVM_READOBJ"), Objdump: requireEnv(t, "LLVM_OBJDUMP"),
		Ar: requireEnv(t, "LLVM_AR"), Nm: requireEnv(t, "LLVM_NM"),
	}
	dir := t.TempDir()
	source := filepath.Join(dir, "probe.c")
	object := filepath.Join(dir, "probe.obj")
	archive := filepath.Join(dir, "probe.lib")
	image := filepath.Join(dir, "probe.exe")
	pdb := filepath.Join(dir, "probe.pdb")
	if err := os.WriteFile(source, []byte("int mainCRTStartup(void) { return 0; }\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	runTool(t, clangCL, "--target=x86_64-pc-windows-msvc", "/nologo", "/c", "/Brepro", "/Fo"+object, source)
	runTool(t, tools.Ar, "rcsD", archive, object)
	runTool(t, lldLink, "/nologo", "/nodefaultlib", "/debug", "/entry:mainCRTStartup", "/subsystem:console", "/out:"+image, object)
	if _, err := inspect(tools, artifactSpec{File: object, Kind: "coff", Machine: "AMD64", Contains: []string{"IMAGE_FILE_MACHINE_AMD64"}}); err != nil {
		t.Fatal(err)
	}
	if _, err := inspect(tools, artifactSpec{File: archive, Kind: "archive", Machine: "AMD64", Contains: []string{"probe.obj", "mainCRTStartup", "timestamp 0", "IMAGE_FILE_MACHINE_AMD64"}}); err != nil {
		t.Fatal(err)
	}
	if _, err := inspect(tools, artifactSpec{File: archive, Kind: "archive", Machine: "x86_64"}); err != nil {
		t.Fatal(err)
	}
	if _, err := inspect(tools, artifactSpec{File: image, Kind: "pe", Machine: "AMD64", Contains: []string{"Subsystem"}}); err != nil {
		t.Fatal(err)
	}
	if _, err := inspect(tools, artifactSpec{File: pdb, Kind: "pdb", Contains: []string{"MSF 7.00"}}); err != nil {
		t.Fatal(err)
	}
}

func TestArchiveMetadataRejectsNonzeroTimestamp(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nondeterministic.lib")
	header := fmt.Sprintf("%-16s%-12s%-6s%-6s%-8s%-10s`\n", "member/", "1", "0", "0", "644", "0")
	if err := os.WriteFile(path, []byte("!<arch>\n"+header), 0o600); err != nil {
		t.Fatal(err)
	}
	_, err := inspectArchiveMetadata(path, "AMD64")
	if err == nil || !strings.Contains(err.Error(), "timestamp = 1, want 0") {
		t.Fatalf("got %v", err)
	}
}

func writeSyntheticArchive(t *testing.T, path, name string, member []byte) {
	t.Helper()
	header := fmt.Sprintf("%-16s%-12s%-6s%-6s%-8s%-10d`\n", name, "0", "0", "0", "644", len(member))
	data := append([]byte("!<arch>\n"+header), member...)
	if len(data)%2 != 0 {
		data = append(data, '\n')
	}
	if err := os.WriteFile(path, data, 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestArchiveMetadataBigobjAndImportHeaders(t *testing.T) {
	dir := t.TempDir()
	metadataOnly := filepath.Join(dir, "metadata-only.lib")
	writeSyntheticArchive(t, metadataOnly, "/", nil)
	if _, err := inspectArchiveMetadata(metadataOnly, "AMD64"); err == nil || !strings.Contains(err.Error(), "no COFF object members") {
		t.Fatalf("metadata-only archive: %v", err)
	}

	bigobj := make([]byte, 56)
	binary.LittleEndian.PutUint16(bigobj[2:4], 0xffff)
	binary.LittleEndian.PutUint16(bigobj[4:6], 2)
	binary.LittleEndian.PutUint16(bigobj[6:8], 0x8664)
	bigobjPath := filepath.Join(dir, "bigobj.lib")
	writeSyntheticArchive(t, bigobjPath, "big.obj/", bigobj)
	if _, err := inspectArchiveMetadata(bigobjPath, "AMD64"); err != nil {
		t.Fatal(err)
	}

	importObject := make([]byte, 20)
	binary.LittleEndian.PutUint16(importObject[2:4], 0xffff)
	binary.LittleEndian.PutUint16(importObject[6:8], 0x8664)
	importPath := filepath.Join(dir, "import.lib")
	writeSyntheticArchive(t, importPath, "import.obj/", importObject)
	if _, err := inspectArchiveMetadata(importPath, "AMD64"); err != nil {
		t.Fatal(err)
	}

	binary.LittleEndian.PutUint32(importObject[8:12], 1)
	writeSyntheticArchive(t, filepath.Join(dir, "bad-import.lib"), "import.obj/", importObject)
	if _, err := inspectArchiveMetadata(filepath.Join(dir, "bad-import.lib"), "AMD64"); err == nil || !strings.Contains(err.Error(), "COFF timestamp = 1, want 0") {
		t.Fatalf("nonzero import-object timestamp: %v", err)
	}

	binary.LittleEndian.PutUint16(bigobj[6:8], 0xaa64)
	writeSyntheticArchive(t, filepath.Join(dir, "bad-bigobj.lib"), "big.obj/", bigobj)
	if _, err := inspectArchiveMetadata(filepath.Join(dir, "bad-bigobj.lib"), "AMD64"); err == nil || !strings.Contains(err.Error(), "machine 0xaa64, want AMD64") {
		t.Fatalf("wrong bigobj machine: %v", err)
	}
}

func TestArchiveRejectsMixedMachinesAndCOFFTimestamp(t *testing.T) {
	clangCL := requireEnv(t, "CLANG_CL")
	tools := toolPaths{
		Readobj: requireEnv(t, "LLVM_READOBJ"), Ar: requireEnv(t, "LLVM_AR"),
		Nm: requireEnv(t, "LLVM_NM"),
	}
	dir := t.TempDir()
	source := filepath.Join(dir, "probe.c")
	x64Object := filepath.Join(dir, "x64.obj")
	arm64Object := filepath.Join(dir, "arm64.obj")
	nondeterministicObject := filepath.Join(dir, "timestamp.obj")
	mixedArchive := filepath.Join(dir, "mixed.lib")
	timestampArchive := filepath.Join(dir, "timestamp.lib")
	if err := os.WriteFile(source, []byte("int value(void) { return 42; }\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	runTool(t, clangCL, "--target=x86_64-pc-windows-msvc", "/nologo", "/c", "/Brepro", "/Fo"+x64Object, source)
	runTool(t, clangCL, "--target=aarch64-pc-windows-msvc", "/nologo", "/c", "/Brepro", "/Fo"+arm64Object, source)
	runTool(t, tools.Ar, "rcsD", mixedArchive, x64Object, arm64Object)
	if _, err := inspect(tools, artifactSpec{File: mixedArchive, Kind: "archive", Machine: "AMD64"}); err == nil || !strings.Contains(err.Error(), "machine 0xaa64, want AMD64") {
		t.Fatalf("mixed-machine archive: %v", err)
	}
	data, err := os.ReadFile(x64Object)
	if err != nil {
		t.Fatal(err)
	}
	binary.LittleEndian.PutUint32(data[4:8], 1)
	if err := os.WriteFile(nondeterministicObject, data, 0o600); err != nil {
		t.Fatal(err)
	}
	runTool(t, tools.Ar, "rcsD", timestampArchive, nondeterministicObject)
	if _, err := inspect(tools, artifactSpec{File: timestampArchive, Kind: "archive", Machine: "AMD64"}); err == nil || !strings.Contains(err.Error(), "COFF timestamp = 1, want 0") {
		t.Fatalf("nonzero COFF timestamp: %v", err)
	}
}

func TestMissingExpectationFails(t *testing.T) {
	tools := toolPaths{Readobj: requireEnv(t, "LLVM_READOBJ")}
	_, err := inspect(tools, artifactSpec{File: "does-not-exist", Kind: "coff"})
	if err == nil {
		t.Fatal("expected failure")
	}
}

func TestPDBRejectsTruncatedMSFSignature(t *testing.T) {
	path := filepath.Join(t.TempDir(), "truncated.pdb")
	if err := os.WriteFile(path, []byte(pdbMagic), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := inspect(toolPaths{}, artifactSpec{File: path, Kind: "pdb"}); err == nil || !strings.Contains(err.Error(), "signature and superblock") {
		t.Fatalf("got %v", err)
	}
}
