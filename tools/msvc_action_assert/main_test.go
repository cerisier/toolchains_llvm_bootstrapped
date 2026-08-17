package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func fixture() graph {
	return graph{
		PathFragments: []pathFragment{
			{ID: "1", Label: "external"},
			{ID: "2", Label: "clang-cl", ParentID: "1"},
			{ID: "3", Label: "probe.cc"},
			{ID: "4", Label: "probe.obj"},
		},
		Artifacts:     []artifact{{ID: "10", PathFragmentID: "3"}, {ID: "11", PathFragmentID: "4"}},
		DepSetOfFiles: []depSet{{ID: "20", DirectArtifactIds: []identifier{"10"}}},
		Actions: []action{{
			Mnemonic: "CppCompile", Arguments: []string{"external/clang-cl", "/c", "probe.cc", "@probe.rsp"},
			EnvironmentVariables: []keyValue{{Key: "VSLANG", Value: "1033"}}, InputDepSetIds: []identifier{"20"},
			OutputIds: []identifier{"11"}, ExecutionPlatform: "@llvm//:rbe_linux_x86_64",
			ParamFiles: []paramFile{{ExecPath: "probe.rsp", Arguments: []string{"/MD", "/Brepro"}}},
		}},
	}
}

func intPointer(value int) *int { return &value }

func TestIdentifierAcceptsNumbersAndStrings(t *testing.T) {
	var values struct {
		Number identifier `json:"number"`
		String identifier `json:"string"`
	}
	if err := json.Unmarshal([]byte(`{"number": 42, "string": "43"}`), &values); err != nil {
		t.Fatal(err)
	}
	if values.Number != "42" || values.String != "43" {
		t.Fatalf("got %+v", values)
	}
}

func TestAssertGraph(t *testing.T) {
	err := assertGraph(fixture(), specification{Assertions: []assertion{{
		Mnemonic: "CppCompile", ExecutableContains: "clang-cl", ArgvContains: []string{"/MD", "/Brepro"},
		ArgvAbsent: []string{"-Wl,"}, InputsContain: []string{"probe.cc"}, OutputsContain: []string{"probe.obj"},
		ArgvOccurrences:           map[string]int{"/MD": 1, "/MT": 0},
		ExpectedParamFiles:        intPointer(1),
		ParamFilesContain:         []string{"probe.rsp"},
		ExecutionPlatformContains: "linux_x86_64", Environment: map[string]string{"VSLANG": "1033"},
	}}})
	if err != nil {
		t.Fatal(err)
	}
}

func TestAssertGraphFailureIsActionable(t *testing.T) {
	err := assertGraph(fixture(), specification{Assertions: []assertion{{Mnemonic: "CppCompile", ArgvContains: []string{"/MT"}}}})
	if err == nil || !strings.Contains(err.Error(), "argv does not contain") {
		t.Fatalf("got %v", err)
	}
}

func TestAssertGraphRejectsBadSiblingAction(t *testing.T) {
	g := fixture()
	g.Actions = append(g.Actions, action{
		Mnemonic: "CppCompile", Arguments: []string{"external/clang++", "-c", "probe.cc"},
		InputDepSetIds: []identifier{"20"}, OutputIds: []identifier{"11"},
	})
	err := assertGraph(g, specification{Assertions: []assertion{{
		Mnemonic: "CppCompile", ExpectedMatches: intPointer(2), ExecutableContains: "clang-cl",
	}}})
	if err == nil || !strings.Contains(err.Error(), "selected action 2/2 failed") {
		t.Fatalf("got %v", err)
	}
}

func TestAssertGraphSupportsZeroMatches(t *testing.T) {
	err := assertGraph(fixture(), specification{Assertions: []assertion{{
		Mnemonic: "CppCompile", SelectorArgvContains: []string{"-Wl,"}, ExpectedMatches: intPointer(0),
	}}})
	if err != nil {
		t.Fatal(err)
	}
}

func TestAssertGraphRejectsEmptySpecification(t *testing.T) {
	if err := assertGraph(fixture(), specification{}); err == nil || !strings.Contains(err.Error(), "at least one assertion") {
		t.Fatalf("got %v", err)
	}
}

func TestStrictSpecificationRejectsUnknownFields(t *testing.T) {
	path := filepath.Join(t.TempDir(), "spec.json")
	if err := os.WriteFile(path, []byte(`{"assertion": []}`), 0o600); err != nil {
		t.Fatal(err)
	}
	var spec specification
	if err := readJSON(path, &spec, true); err == nil || !strings.Contains(err.Error(), "unknown field") {
		t.Fatalf("got %v", err)
	}
}

func TestAssertGraphRequiresExactSelectionCount(t *testing.T) {
	g := fixture()
	g.Actions = append(g.Actions, g.Actions[0])
	err := assertGraph(g, specification{Assertions: []assertion{{Mnemonic: "CppCompile"}}})
	if err == nil || !strings.Contains(err.Error(), "selected 2 actions, want 1") {
		t.Fatalf("got %v", err)
	}
}

func TestAssertGraphRequiresExactArgumentOccurrences(t *testing.T) {
	g := fixture()
	g.Actions[0].ParamFiles[0].Arguments = append(g.Actions[0].ParamFiles[0].Arguments, "/MD")
	err := assertGraph(g, specification{Assertions: []assertion{{
		Mnemonic: "CppCompile", ArgvOccurrences: map[string]int{"/MD": 1},
	}}})
	if err == nil || !strings.Contains(err.Error(), `argv contains "/MD" 2 times, want 1`) {
		t.Fatalf("got %v", err)
	}
}

func TestAssertGraphChecksParamFileArguments(t *testing.T) {
	g := fixture()
	g.Actions[0].ParamFiles[0].Arguments = append(g.Actions[0].ParamFiles[0].Arguments, "-Wl,--bad")
	err := assertGraph(g, specification{Assertions: []assertion{{
		Mnemonic: "CppCompile", ArgvAbsent: []string{"-Wl,"},
	}}})
	if err == nil || !strings.Contains(err.Error(), `argv unexpectedly contains "-Wl,"`) {
		t.Fatalf("got %v", err)
	}
}

func TestAssertGraphIgnoresUnreferencedParamFileMetadata(t *testing.T) {
	g := fixture()
	g.Actions[0].ParamFiles = append(g.Actions[0].ParamFiles, paramFile{
		ExecPath: "probe.cppmap", Arguments: []string{"-Wl,--not-an-argument"},
	})
	err := assertGraph(g, specification{Assertions: []assertion{{
		Mnemonic: "CppCompile", ArgvAbsent: []string{"-Wl,"}, ExpectedParamFiles: intPointer(1),
		ParamFilesAbsent: []string{"cppmap"},
	}}})
	if err != nil {
		t.Fatal(err)
	}
}

func TestResolveRejectsCycles(t *testing.T) {
	g := graph{DepSetOfFiles: []depSet{{ID: "1", TransitiveDepSetIds: []identifier{"1"}}}, Actions: []action{{InputDepSetIds: []identifier{"1"}}}}
	if _, err := resolve(g); err == nil || !strings.Contains(err.Error(), "cycle") {
		t.Fatalf("got %v", err)
	}
}
