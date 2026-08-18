package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestGenerateCaseInsensitiveOverlay(t *testing.T) {
	root := t.TempDir()
	if err := os.Mkdir(filepath.Join(root, "Nested"), 0o755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"Windows.h", filepath.Join("Nested", "Ole2.h")} {
		if err := os.WriteFile(filepath.Join(root, name), []byte(name), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	data, err := generate([]string{root})
	if err != nil {
		t.Fatal(err)
	}
	var parsed overlay
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatal(err)
	}
	if parsed.CaseSensitive {
		t.Fatal("overlay must provide Windows case-insensitive lookup")
	}
	if parsed.UseExternalNames {
		t.Fatal("dependency paths must retain their virtual, execroot-relative names")
	}
	if len(parsed.Roots) != 1 || len(parsed.Roots[0].Contents) != 2 {
		t.Fatalf("unexpected overlay roots: %#v", parsed.Roots)
	}
}

func TestPreferredNameChoosesLowercaseAlias(t *testing.T) {
	got, err := preferredName("Windows.h", "windows.h")
	if err != nil {
		t.Fatal(err)
	}
	if got != "windows.h" {
		t.Fatalf("preferredName() = %q, want lowercase alias", got)
	}
}

func TestPreferredNameRejectsAmbiguousEntries(t *testing.T) {
	if _, err := preferredName("FOO.h", "Foo.h"); err == nil {
		t.Fatal("expected ambiguous case-only entries to be rejected")
	}
}

func TestGenerateFollowsTransformedHeaderSymlink(t *testing.T) {
	root := t.TempDir()
	original := filepath.Join(root, "Windows.h")
	if err := os.WriteFile(original, []byte("windows"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(original, filepath.Join(root, "windows.h")); err != nil {
		t.Skipf("file symlinks unavailable: %v", err)
	}
	data, err := generate([]string{root})
	if err != nil {
		t.Fatal(err)
	}
	var parsed overlay
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatal(err)
	}
	if got := parsed.Roots[0].Contents[0].Name; got != "windows.h" {
		t.Fatalf("transformed entry = %q, want lowercase alias", got)
	}
}
