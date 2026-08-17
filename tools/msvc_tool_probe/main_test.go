package main

import (
	"os"
	"runtime"
	"testing"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

func env(t *testing.T, name string) string {
	t.Helper()
	value := os.Getenv(name)
	if value == "" {
		t.Fatalf("%s is not set", name)
	}
	path, err := runfiles.Rlocation(value)
	if err != nil {
		t.Fatalf("resolve %s runfile %q: %v", name, value, err)
	}
	return path
}

func TestDirectToolsAndProtocols(t *testing.T) {
	r, err := probe(paths{
		ClangCL: env(t, "CLANG_CL"), LLVMAr: env(t, "LLVM_AR"),
		LLDLink: env(t, "LLD_LINK"),
	}, "")
	if err != nil {
		t.Fatal(err)
	}
	if !r.DependencyFile || !r.ShowIncludes || !r.LLVMLibAlias || r.BreproTimestamp != 0 {
		t.Fatalf("incomplete result: %+v", r)
	}
	if runtime.GOOS != "windows" && !r.LLVMLibArgv0 {
		t.Fatalf("argv[0] personality probe failed: %+v", r)
	}
	for _, family := range []string{"compiler", "archive", "link"} {
		if !r.UTF8Response[family] {
			t.Errorf("UTF-8 response probe missing for %s", family)
		}
	}
	for _, family := range []string{"compiler", "link"} {
		if !r.UTF16Response[family] {
			t.Errorf("UTF-16 response probe missing for %s", family)
		}
	}
}
