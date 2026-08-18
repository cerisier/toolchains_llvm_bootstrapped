package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type keyValue struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

type identifier string

func (id *identifier) UnmarshalJSON(data []byte) error {
	var text string
	if err := json.Unmarshal(data, &text); err == nil {
		*id = identifier(text)
		return nil
	}
	var number json.Number
	if err := json.Unmarshal(data, &number); err != nil {
		return fmt.Errorf("identifier must be a string or number: %w", err)
	}
	*id = identifier(number.String())
	return nil
}

type paramFile struct {
	ExecPath  string   `json:"execPath"`
	Arguments []string `json:"arguments"`
}

type action struct {
	Mnemonic             string       `json:"mnemonic"`
	Arguments            []string     `json:"arguments"`
	EnvironmentVariables []keyValue   `json:"environmentVariables"`
	InputDepSetIds       []identifier `json:"inputDepSetIds"`
	OutputIds            []identifier `json:"outputIds"`
	ExecutionPlatform    string       `json:"executionPlatform"`
	ParamFiles           []paramFile  `json:"paramFiles"`
}

type artifact struct {
	ID             identifier `json:"id"`
	PathFragmentID identifier `json:"pathFragmentId"`
}

type depSet struct {
	ID                  identifier   `json:"id"`
	DirectArtifactIds   []identifier `json:"directArtifactIds"`
	TransitiveDepSetIds []identifier `json:"transitiveDepSetIds"`
}

type pathFragment struct {
	ID       identifier `json:"id"`
	Label    string     `json:"label"`
	ParentID identifier `json:"parentId"`
}

type graph struct {
	Actions       []action       `json:"actions"`
	Artifacts     []artifact     `json:"artifacts"`
	DepSetOfFiles []depSet       `json:"depSetOfFiles"`
	PathFragments []pathFragment `json:"pathFragments"`
}

type assertion struct {
	Mnemonic                  string            `json:"mnemonic"`
	SelectorArgvContains      []string          `json:"selector_argv_contains"`
	SelectorInputsContain     []string          `json:"selector_inputs_contain"`
	SelectorOutputsContain    []string          `json:"selector_outputs_contain"`
	ExpectedMatches           *int              `json:"expected_matches"`
	ExecutableContains        string            `json:"executable_contains"`
	ArgvContains              []string          `json:"argv_contains"`
	ArgvAbsent                []string          `json:"argv_absent"`
	ArgvOccurrences           map[string]int    `json:"argv_occurrences"`
	ExpectedParamFiles        *int              `json:"expected_param_files"`
	ParamFilesContain         []string          `json:"param_files_contain"`
	ParamFilesAbsent          []string          `json:"param_files_absent"`
	InputsContain             []string          `json:"inputs_contain"`
	InputsAbsent              []string          `json:"inputs_absent"`
	OutputsContain            []string          `json:"outputs_contain"`
	ExecutionPlatformContains string            `json:"execution_platform_contains"`
	Environment               map[string]string `json:"environment"`
}

type specification struct {
	Assertions []assertion `json:"assertions"`
}

type resolvedAction struct {
	action
	Inputs  []string
	Outputs []string
}

func readJSON(path string, value any, strict bool) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if !strict {
		if err := json.Unmarshal(data, value); err != nil {
			return fmt.Errorf("parse %s: %w", path, err)
		}
		return nil
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(value); err != nil {
		return fmt.Errorf("parse %s: %w", path, err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); err != io.EOF {
		if err == nil {
			return fmt.Errorf("parse %s: unexpected trailing JSON value", path)
		}
		return fmt.Errorf("parse %s: %w", path, err)
	}
	return nil
}

func resolve(g graph) ([]resolvedAction, error) {
	fragments := map[identifier]pathFragment{}
	for _, f := range g.PathFragments {
		fragments[f.ID] = f
	}
	var pathFor func(identifier, map[identifier]bool) (string, error)
	pathFor = func(id identifier, visiting map[identifier]bool) (string, error) {
		if id == "" {
			return "", nil
		}
		if visiting[id] {
			return "", fmt.Errorf("path fragment cycle at %s", id)
		}
		f, ok := fragments[id]
		if !ok {
			return "", fmt.Errorf("unknown path fragment %s", id)
		}
		visiting[id] = true
		parent, err := pathFor(f.ParentID, visiting)
		delete(visiting, id)
		if err != nil {
			return "", err
		}
		if parent == "" {
			return f.Label, nil
		}
		return parent + "/" + f.Label, nil
	}
	artifacts := map[identifier]string{}
	for _, a := range g.Artifacts {
		path, err := pathFor(a.PathFragmentID, map[identifier]bool{})
		if err != nil {
			return nil, err
		}
		artifacts[a.ID] = path
	}
	sets := map[identifier]depSet{}
	for _, s := range g.DepSetOfFiles {
		sets[s.ID] = s
	}
	var collect func(identifier, map[identifier]bool, map[string]bool) error
	collect = func(id identifier, visiting map[identifier]bool, found map[string]bool) error {
		if visiting[id] {
			return fmt.Errorf("depset cycle at %s", id)
		}
		s, ok := sets[id]
		if !ok {
			return fmt.Errorf("unknown depset %s", id)
		}
		visiting[id] = true
		for _, artifactID := range s.DirectArtifactIds {
			path, ok := artifacts[artifactID]
			if !ok {
				return fmt.Errorf("unknown artifact %s", artifactID)
			}
			found[path] = true
		}
		for _, child := range s.TransitiveDepSetIds {
			if err := collect(child, visiting, found); err != nil {
				return err
			}
		}
		delete(visiting, id)
		return nil
	}
	resolved := make([]resolvedAction, 0, len(g.Actions))
	for _, a := range g.Actions {
		inputs := map[string]bool{}
		for _, setID := range a.InputDepSetIds {
			if err := collect(setID, map[identifier]bool{}, inputs); err != nil {
				return nil, err
			}
		}
		r := resolvedAction{action: a}
		for path := range inputs {
			r.Inputs = append(r.Inputs, path)
		}
		for _, id := range a.OutputIds {
			path, ok := artifacts[id]
			if !ok {
				return nil, fmt.Errorf("unknown output artifact %s", id)
			}
			r.Outputs = append(r.Outputs, path)
		}
		sort.Strings(r.Inputs)
		sort.Strings(r.Outputs)
		resolved = append(resolved, r)
	}
	return resolved, nil
}

func contains(values []string, needle string) bool {
	for _, value := range values {
		if strings.Contains(value, needle) {
			return true
		}
	}
	return false
}

func countContains(values []string, needle string) int {
	count := 0
	for _, value := range values {
		if strings.Contains(value, needle) {
			count++
		}
	}
	return count
}

func referencedParamFiles(r resolvedAction) []paramFile {
	var referenced []paramFile
	for _, file := range r.ParamFiles {
		for _, argument := range r.Arguments {
			if strings.Trim(strings.TrimPrefix(argument, "@"), `"`) == file.ExecPath && strings.HasPrefix(argument, "@") {
				referenced = append(referenced, file)
				break
			}
		}
	}
	return referenced
}

func effectiveArguments(r resolvedAction) []string {
	arguments := append([]string{}, r.Arguments...)
	for _, file := range referencedParamFiles(r) {
		arguments = append(arguments, file.Arguments...)
	}
	return arguments
}

func opaqueParamFilePaths(r resolvedAction) []string {
	referenced := map[string]bool{}
	for _, file := range referencedParamFiles(r) {
		referenced[file.ExecPath] = true
	}
	var opaque []string
	for _, argument := range r.Arguments {
		if !strings.HasPrefix(argument, "@") {
			continue
		}
		path := strings.Trim(strings.TrimPrefix(argument, "@"), `"`)
		if !referenced[path] {
			opaque = append(opaque, path)
		}
	}
	sort.Strings(opaque)
	return opaque
}

func paramFilePaths(r resolvedAction) []string {
	found := map[string]bool{}
	for _, file := range referencedParamFiles(r) {
		found[file.ExecPath] = true
	}
	// Bazel 9's JSON aquery output records virtual parameter files only as
	// @argv entries even with --include_param_files. Preserve full argument
	// inspection when metadata is available, while still verifying the real
	// response-file protocol when it is not.
	for _, argument := range r.Arguments {
		if strings.HasPrefix(argument, "@") {
			found[strings.Trim(strings.TrimPrefix(argument, "@"), `"`)] = true
		}
	}
	paths := make([]string, 0, len(found))
	for path := range found {
		paths = append(paths, path)
	}
	sort.Strings(paths)
	return paths
}

func selectedWithoutArguments(r resolvedAction, want assertion) bool {
	if want.Mnemonic != "" && r.Mnemonic != want.Mnemonic {
		return false
	}
	for _, needle := range want.SelectorInputsContain {
		if !contains(r.Inputs, needle) {
			return false
		}
	}
	for _, needle := range want.SelectorOutputsContain {
		if !contains(r.Outputs, needle) {
			return false
		}
	}
	return true
}

func selected(r resolvedAction, want assertion) (bool, error) {
	if !selectedWithoutArguments(r, want) {
		return false, nil
	}
	if len(want.SelectorArgvContains) > 0 {
		if opaque := opaqueParamFilePaths(r); len(opaque) > 0 {
			return false, fmt.Errorf("cannot verify argv selectors: response file contents unavailable for %s", strings.Join(opaque, ", "))
		}
	}
	arguments := effectiveArguments(r)
	for _, needle := range want.SelectorArgvContains {
		if !contains(arguments, needle) {
			return false, nil
		}
	}
	return true, nil
}

func match(r resolvedAction, want assertion) error {
	arguments := effectiveArguments(r)
	if want.Mnemonic != "" && r.Mnemonic != want.Mnemonic {
		return fmt.Errorf("mnemonic: got %q, want %q", r.Mnemonic, want.Mnemonic)
	}
	if want.ExecutableContains != "" && (len(r.Arguments) == 0 || !strings.Contains(r.Arguments[0], want.ExecutableContains)) {
		return fmt.Errorf("executable does not contain %q", want.ExecutableContains)
	}
	if len(want.ArgvContains) > 0 || len(want.ArgvAbsent) > 0 || len(want.ArgvOccurrences) > 0 {
		if opaque := opaqueParamFilePaths(r); len(opaque) > 0 {
			return fmt.Errorf("cannot verify argv assertions: response file contents unavailable for %s", strings.Join(opaque, ", "))
		}
	}
	for _, needle := range want.ArgvContains {
		if !contains(arguments, needle) {
			return fmt.Errorf("argv does not contain %q", needle)
		}
	}
	for _, needle := range want.ArgvAbsent {
		if contains(arguments, needle) {
			return fmt.Errorf("argv unexpectedly contains %q", needle)
		}
	}
	for needle, expected := range want.ArgvOccurrences {
		if actual := countContains(arguments, needle); actual != expected {
			return fmt.Errorf("argv contains %q %d times, want %d", needle, actual, expected)
		}
	}
	if want.ExpectedParamFiles != nil {
		if *want.ExpectedParamFiles < 0 {
			return errors.New("expected_param_files must be nonnegative")
		}
		if actual := len(paramFilePaths(r)); actual != *want.ExpectedParamFiles {
			return fmt.Errorf("action references %d param files, want %d", actual, *want.ExpectedParamFiles)
		}
	}
	paths := paramFilePaths(r)
	for _, needle := range want.ParamFilesContain {
		if !contains(paths, needle) {
			return fmt.Errorf("param file paths do not contain %q", needle)
		}
	}
	for _, needle := range want.ParamFilesAbsent {
		if contains(paths, needle) {
			return fmt.Errorf("param file paths unexpectedly contain %q", needle)
		}
	}
	for _, needle := range want.InputsContain {
		if !contains(r.Inputs, needle) {
			return fmt.Errorf("inputs do not contain %q", needle)
		}
	}
	for _, needle := range want.InputsAbsent {
		if contains(r.Inputs, needle) {
			return fmt.Errorf("inputs unexpectedly contain %q", needle)
		}
	}
	for _, needle := range want.OutputsContain {
		if !contains(r.Outputs, needle) {
			return fmt.Errorf("outputs do not contain %q", needle)
		}
	}
	if want.ExecutionPlatformContains != "" && !strings.Contains(r.ExecutionPlatform, want.ExecutionPlatformContains) {
		return fmt.Errorf("execution platform %q does not contain %q", r.ExecutionPlatform, want.ExecutionPlatformContains)
	}
	environment := map[string]string{}
	for _, pair := range r.EnvironmentVariables {
		environment[pair.Key] = pair.Value
	}
	for key, value := range want.Environment {
		if environment[key] != value {
			return fmt.Errorf("environment %s: got %q, want %q", key, environment[key], value)
		}
	}
	return nil
}

func assertionNeedsArguments(want assertion) bool {
	return len(want.SelectorArgvContains) > 0 || len(want.ArgvContains) > 0 || len(want.ArgvAbsent) > 0 || len(want.ArgvOccurrences) > 0
}

func assertGraphWithParamFileRoot(g graph, spec specification, paramFileRoot *string) error {
	if len(spec.Assertions) == 0 {
		return errors.New("specification must contain at least one assertion")
	}
	actions, err := resolve(g)
	if err != nil {
		return err
	}
	for i, want := range spec.Assertions {
		var selectedActions []resolvedAction
		for _, action := range actions {
			if paramFileRoot != nil && assertionNeedsArguments(want) && selectedWithoutArguments(action, want) {
				if err := hydrateParamFiles(&action, *paramFileRoot); err != nil {
					return fmt.Errorf("assertion %d response-file loading failed: %w", i+1, err)
				}
			}
			selected, err := selected(action, want)
			if err != nil {
				return fmt.Errorf("assertion %d selection failed: %w", i+1, err)
			}
			if selected {
				selectedActions = append(selectedActions, action)
			}
		}
		expected := 1
		if want.ExpectedMatches != nil {
			expected = *want.ExpectedMatches
			if expected < 0 {
				return fmt.Errorf("assertion %d expected_matches must be nonnegative", i+1)
			}
		}
		if len(selectedActions) != expected {
			return fmt.Errorf("assertion %d selected %d actions, want %d", i+1, len(selectedActions), expected)
		}
		for actionIndex, action := range selectedActions {
			if err := match(action, want); err != nil {
				return fmt.Errorf("assertion %d selected action %d/%d failed: %w", i+1, actionIndex+1, len(selectedActions), err)
			}
		}
	}
	return nil
}

func assertGraph(g graph, spec specification) error {
	return assertGraphWithParamFileRoot(g, spec, nil)
}

func hydrateParamFiles(action *resolvedAction, root string) error {
	known := map[string]bool{}
	for _, file := range action.ParamFiles {
		known[file.ExecPath] = true
	}
	for _, argument := range action.Arguments {
		if !strings.HasPrefix(argument, "@") {
			continue
		}
		path := strings.Trim(strings.TrimPrefix(argument, "@"), `"`)
		if known[path] {
			continue
		}
		contents, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(path)))
		if err != nil {
			return fmt.Errorf("%s response file %s is unavailable: run the owning bazel build with --materialize_param_files: %w", action.Mnemonic, path, err)
		}
		lines := strings.Split(strings.ReplaceAll(string(contents), "\r\n", "\n"), "\n")
		if len(lines) > 0 && lines[len(lines)-1] == "" {
			lines = lines[:len(lines)-1]
		}
		action.ParamFiles = append(action.ParamFiles, paramFile{ExecPath: path, Arguments: lines})
		known[path] = true
	}
	return nil
}

func run(aqueryPath, specPath, paramFileRoot string) error {
	if aqueryPath == "" || specPath == "" {
		return errors.New("both -aquery and -spec are required")
	}
	var g graph
	var spec specification
	if err := readJSON(aqueryPath, &g, false); err != nil {
		return err
	}
	if err := readJSON(specPath, &spec, true); err != nil {
		return err
	}
	return assertGraphWithParamFileRoot(g, spec, &paramFileRoot)
}

func main() {
	aqueryPath := flag.String("aquery", "", "path to bazel aquery --include_param_files --output=jsonproto output")
	paramFileRoot := flag.String("param-file-root", ".", "directory from which relative response-file paths are resolved")
	specPath := flag.String("spec", "", "path to the JSON assertion specification")
	flag.Parse()
	if err := run(*aqueryPath, *specPath, *paramFileRoot); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
