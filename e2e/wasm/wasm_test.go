package wasm

import (
	"context"
	"os"
	"testing"

	"github.com/bazelbuild/rules_go/go/runfiles"
	"github.com/tetratelabs/wazero"
)

var wasmBlobRlocationpath string

func loadWasmBytes(t *testing.T) []byte {
	t.Helper()
	if wasmBlobRlocationpath == "" {
		t.Fatalf("wasm blob rlocationpath not set")
	}

	path, err := runfiles.Rlocation(wasmBlobRlocationpath)
	if err != nil {
		t.Fatalf("resolve runfile failed: %v", err)
	}

	bytes, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read wasm blob failed: %v", err)
	}

	return bytes
}

func TestWasmBinaryLoadsAndRuns(t *testing.T) {
	ctx := context.Background()
	runtime := wazero.NewRuntime(ctx)
	t.Cleanup(func() {
		_ = runtime.Close(ctx)
	})

	compiled, err := runtime.CompileModule(ctx, loadWasmBytes(t))
	if err != nil {
		t.Fatalf("compile failed: %v", err)
	}

	module, err := runtime.InstantiateModule(ctx, compiled, wazero.NewModuleConfig())
	if err != nil {
		t.Fatalf("instantiate failed: %v", err)
	}

	add := module.ExportedFunction("add")
	if add == nil {
		t.Fatalf("add export not found")
	}

	results, err := add.Call(ctx, 7, 5)
	if err != nil {
		t.Fatalf("call failed: %v", err)
	}

	if len(results) != 1 || results[0] != 12 {
		t.Fatalf("unexpected result: %v", results)
	}
}
