package main

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

type paths struct {
	ClangCL string
	LLVMAr  string
	LLDLink string
}

type result struct {
	Host             string            `json:"host"`
	Versions         map[string]string `json:"versions"`
	DependencyFile   bool              `json:"dependency_file"`
	ShowIncludes     bool              `json:"show_includes"`
	UTF8Response     map[string]bool   `json:"utf8_response"`
	UTF16Response    map[string]bool   `json:"utf16_response"`
	BreproObjectHash string            `json:"brepro_object_sha256"`
	BreproTimestamp  uint32            `json:"brepro_timestamp"`
	LLVMLibArgv0     bool              `json:"llvm_lib_argv0_personality"`
	LLVMLibAlias     bool              `json:"llvm_lib_alias_personality"`
	ResponseNotes    map[string]string `json:"response_notes,omitempty"`
}

func run(path string, argv0 string, env []string, args ...string) (string, error) {
	if path == "" {
		return "", errors.New("tool path is empty")
	}
	cmd := exec.Command(path, args...)
	if argv0 != "" {
		cmd.Args[0] = argv0
	}
	if env != nil {
		cmd.Env = append(os.Environ(), env...)
	}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output), fmt.Errorf("%s %s: %w\n%s", argv0, strings.Join(args, " "), err, output)
	}
	return string(output), nil
}

func writeUTF16(path string, lines []string) error {
	text := strings.Join(lines, "\r\n") + "\r\n"
	units := make([]uint16, 0, len(text)+1)
	for _, r := range text {
		if r <= 0xffff {
			units = append(units, uint16(r))
		} else {
			r -= 0x10000
			units = append(units, uint16(0xd800+(r>>10)), uint16(0xdc00+(r&0x3ff)))
		}
	}
	data := []byte{0xff, 0xfe}
	for _, unit := range units {
		data = binary.LittleEndian.AppendUint16(data, unit)
	}
	return os.WriteFile(path, data, 0o600)
}

func sha(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:]), nil
}

func coffTimestamp(path string) (uint32, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	if len(data) < 8 {
		return 0, errors.New("COFF file too short")
	}
	return binary.LittleEndian.Uint32(data[4:8]), nil
}

func quote(value string) string { return `"` + strings.ReplaceAll(value, `"`, `\"`) + `"` }

func createAlias(source, destination string) error {
	absoluteSource, err := filepath.Abs(source)
	if err != nil {
		return err
	}
	if err := os.Symlink(absoluteSource, destination); err == nil {
		return nil
	}
	if err := os.Link(absoluteSource, destination); err == nil {
		return nil
	}
	input, err := os.Open(absoluteSource)
	if err != nil {
		return err
	}
	defer input.Close()
	output, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o700)
	if err != nil {
		return err
	}
	if _, err := io.Copy(output, input); err != nil {
		output.Close()
		return err
	}
	return output.Close()
}

func probe(p paths, outputDir string) (result, error) {
	r := result{Host: runtime.GOOS + "_" + runtime.GOARCH, Versions: map[string]string{}, UTF8Response: map[string]bool{}, UTF16Response: map[string]bool{}, ResponseNotes: map[string]string{}}
	for name, tool := range map[string]string{"clang-cl": p.ClangCL, "llvm-ar": p.LLVMAr, "lld-link": p.LLDLink} {
		version, err := run(tool, "", nil, "--version")
		if err != nil {
			return r, err
		}
		r.Versions[name] = strings.TrimSpace(version)
	}
	work := outputDir
	remove := false
	if work == "" {
		var err error
		work, err = os.MkdirTemp("", "msvc-tool-probe-")
		if err != nil {
			return r, err
		}
		remove = true
	}
	if remove {
		defer os.RemoveAll(work)
	}
	pathDir := filepath.Join(work, "space unicode-λ"+map[bool]string{true: "", false: ":colon"}[runtime.GOOS == "windows"])
	if err := os.MkdirAll(pathDir, 0o700); err != nil {
		return r, err
	}
	header := filepath.Join(pathDir, "probe header.h")
	source := filepath.Join(pathDir, "probe source.c")
	if err := os.WriteFile(header, []byte("#define PROBE_VALUE 42\n"), 0o600); err != nil {
		return r, err
	}
	if err := os.WriteFile(source, []byte("#include \"probe header.h\"\nint mainCRTStartup(void) { return PROBE_VALUE == 42 ? 0 : 1; }\n"), 0o600); err != nil {
		return r, err
	}
	directObj := filepath.Join(pathDir, "direct.obj")
	dep := filepath.Join(pathDir, "direct.d")
	show, err := run(p.ClangCL, "", []string{"VSLANG=1033"}, "/nologo", "/showIncludes", "/c", "/Brepro", "/Fo"+directObj, "/clang:-MD", "/clang:-MF", "/clang:"+dep, source)
	if err != nil {
		return r, err
	}
	depData, err := os.ReadFile(dep)
	if err != nil {
		return r, err
	}
	depText := strings.ReplaceAll(string(depData), `\ `, " ")
	if !strings.Contains(depText, filepath.Base(source)) || !strings.Contains(depText, filepath.Base(header)) {
		return r, fmt.Errorf("dependency file omitted source/header:\n%s", depData)
	}
	r.DependencyFile = true
	if !strings.Contains(show, "Note: including file:") {
		return r, fmt.Errorf("showIncludes English prefix absent:\n%s", show)
	}
	r.ShowIncludes = true
	directHash, err := sha(directObj)
	if err != nil {
		return r, err
	}
	repeatObj := filepath.Join(pathDir, "repeat.obj")
	if _, err := run(p.ClangCL, "", nil, "/nologo", "/c", "/Brepro", "/Fo"+repeatObj, source); err != nil {
		return r, err
	}
	repeatHash, err := sha(repeatObj)
	if err != nil {
		return r, err
	}
	if directHash != repeatHash {
		return r, fmt.Errorf("/Brepro object hashes differ: %s != %s", directHash, repeatHash)
	}
	r.BreproObjectHash = directHash
	r.BreproTimestamp, err = coffTimestamp(directObj)
	if err != nil {
		return r, err
	}
	if r.BreproTimestamp != 0 {
		return r, fmt.Errorf("/Brepro COFF timestamp = %d, want 0", r.BreproTimestamp)
	}

	utf8Obj := filepath.Join(pathDir, "utf8 response.obj")
	compilerUTF8 := filepath.Join(pathDir, "compiler utf8.rsp")
	compilerLines := []string{"/nologo", "/c", "/Brepro", "/Fo" + quote(utf8Obj), quote(source)}
	if err := os.WriteFile(compilerUTF8, []byte(strings.Join(compilerLines, "\n")+"\n"), 0o600); err != nil {
		return r, err
	}
	if _, err := run(p.ClangCL, "", nil, "@"+compilerUTF8); err != nil {
		return r, err
	}
	r.UTF8Response["compiler"] = true
	utf16Obj := filepath.Join(pathDir, "utf16 response.obj")
	compilerUTF16 := filepath.Join(pathDir, "compiler utf16.rsp")
	if err := writeUTF16(compilerUTF16, []string{"/nologo", "/c", "/Brepro", "/Fo" + quote(utf16Obj), quote(source)}); err != nil {
		return r, err
	}
	if _, err := run(p.ClangCL, "", nil, "@"+compilerUTF16); err != nil {
		return r, err
	}
	r.UTF16Response["compiler"] = true

	archive := filepath.Join(pathDir, "probe archive.lib")
	archiveRsp := filepath.Join(pathDir, "archive utf8.rsp")
	if err := os.WriteFile(archiveRsp, []byte("rcsD\n"+quote(archive)+"\n"+quote(directObj)+"\n"), 0o600); err != nil {
		return r, err
	}
	if _, err := run(p.LLVMAr, "", nil, "@"+archiveRsp); err != nil {
		return r, err
	}
	r.UTF8Response["archive"] = true
	archive16 := filepath.Join(pathDir, "probe archive utf16.lib")
	archiveRsp16 := filepath.Join(pathDir, "archive utf16.rsp")
	if err := writeUTF16(archiveRsp16, []string{"rcsD", quote(archive16), quote(directObj)}); err != nil {
		return r, err
	}
	if _, err := run(p.LLVMAr, "", nil, "@"+archiveRsp16); err == nil {
		r.UTF16Response["archive"] = true
	} else {
		r.ResponseNotes["archive_utf16"] = err.Error()
	}

	image := filepath.Join(pathDir, "probe image.exe")
	linkRsp := filepath.Join(pathDir, "link utf8.rsp")
	linkLines := []string{"/nologo", "/nodefaultlib", "/entry:mainCRTStartup", "/subsystem:console", "/out:" + quote(image), quote(directObj)}
	if err := os.WriteFile(linkRsp, []byte(strings.Join(linkLines, "\n")+"\n"), 0o600); err != nil {
		return r, err
	}
	if _, err := run(p.LLDLink, "", nil, "@"+linkRsp); err != nil {
		return r, err
	}
	r.UTF8Response["link"] = true
	image16 := filepath.Join(pathDir, "probe image utf16.exe")
	linkRsp16 := filepath.Join(pathDir, "link utf16.rsp")
	linkLines[4] = "/out:" + quote(image16)
	if err := writeUTF16(linkRsp16, linkLines); err != nil {
		return r, err
	}
	if _, err := run(p.LLDLink, "", nil, "@"+linkRsp16); err != nil {
		return r, err
	}
	r.UTF16Response["link"] = true

	if runtime.GOOS != "windows" {
		libArchive := filepath.Join(pathDir, "llvm lib argv0 personality.lib")
		if _, err := run(p.LLVMAr, "llvm-lib", nil, "/nologo", "/out:"+libArchive, directObj); err != nil {
			return r, err
		}
		if _, err := os.Stat(libArchive); err != nil {
			return r, fmt.Errorf("llvm-lib argv[0] personality did not create archive: %w", err)
		}
		r.LLVMLibArgv0 = true
	}
	aliasName := "llvm-lib"
	if runtime.GOOS == "windows" {
		aliasName += ".exe"
	}
	aliasPath := filepath.Join(pathDir, aliasName)
	if err := createAlias(p.LLVMAr, aliasPath); err != nil {
		return r, fmt.Errorf("create llvm-lib alias: %w", err)
	}
	aliasArchive := filepath.Join(pathDir, "llvm lib alias personality.lib")
	if _, err := run(aliasPath, "", nil, "/nologo", "/out:"+aliasArchive, directObj); err != nil {
		return r, err
	}
	if _, err := os.Stat(aliasArchive); err != nil {
		return r, fmt.Errorf("llvm-lib alias personality did not create archive: %w", err)
	}
	r.LLVMLibAlias = true
	return r, nil
}

func main() {
	p := paths{}
	outputDir := flag.String("output-dir", "", "optional retained probe directory")
	flag.StringVar(&p.ClangCL, "clang-cl", "", "path to clang-cl")
	flag.StringVar(&p.LLVMAr, "llvm-ar", "", "path to llvm-ar")
	flag.StringVar(&p.LLDLink, "lld-link", "", "path to lld-link")
	flag.Parse()
	r, err := probe(p, *outputDir)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	encoded, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println(string(encoded))
}
