package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCopyDirectoryLowercasesFileBasenames(t *testing.T) {
	source := filepath.Join(t.TempDir(), "source")
	output := filepath.Join(t.TempDir(), "output")
	if err := os.MkdirAll(filepath.Join(source, "Nested"), 0o755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"Kernel32.Lib", filepath.Join("Nested", "Uuid.Lib")} {
		if err := os.WriteFile(filepath.Join(source, name), []byte(name), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := copyDirectory(source, output); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"kernel32.lib", filepath.Join("Nested", "uuid.lib")} {
		if _, err := os.Stat(filepath.Join(output, name)); err != nil {
			t.Fatal(err)
		}
	}
}

func TestPreferredNameChoosesLowercaseAlias(t *testing.T) {
	got, err := preferredName("Kernel32.Lib", "kernel32.lib")
	if err != nil {
		t.Fatal(err)
	}
	if got != "kernel32.lib" {
		t.Fatalf("preferredName() = %q, want lowercase alias", got)
	}
}
