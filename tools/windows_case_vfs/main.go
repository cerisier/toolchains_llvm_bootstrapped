package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type stringList []string

func (values *stringList) String() string { return strings.Join(*values, ",") }

func (values *stringList) Set(value string) error {
	*values = append(*values, value)
	return nil
}

type entry struct {
	Type             string   `json:"type"`
	Name             string   `json:"name"`
	ExternalContents string   `json:"external-contents,omitempty"`
	Contents         []*entry `json:"contents,omitempty"`
}

type overlay struct {
	Version          int      `json:"version"`
	CaseSensitive    bool     `json:"case-sensitive"`
	UseExternalNames bool     `json:"use-external-names"`
	Roots            []*entry `json:"roots"`
}

func preferredName(left, right string) (string, error) {
	lower := strings.ToLower(left)
	if lower != strings.ToLower(right) {
		return "", fmt.Errorf("internal case-fold mismatch: %q and %q", left, right)
	}
	if left == lower {
		return left, nil
	}
	if right == lower {
		return right, nil
	}
	return "", fmt.Errorf("ambiguous case-insensitive SDK entries %q and %q", left, right)
}

func directoryEntry(path, virtualName string) (*entry, error) {
	directoryEntries, err := os.ReadDir(path)
	if err != nil {
		return nil, err
	}

	byFoldedName := make(map[string]os.DirEntry, len(directoryEntries))
	for _, candidate := range directoryEntries {
		folded := strings.ToLower(candidate.Name())
		current, exists := byFoldedName[folded]
		if !exists {
			byFoldedName[folded] = candidate
			continue
		}
		preferred, err := preferredName(current.Name(), candidate.Name())
		if err != nil {
			return nil, fmt.Errorf("%s: %w", path, err)
		}
		if preferred == candidate.Name() {
			byFoldedName[folded] = candidate
		}
	}

	names := make([]string, 0, len(byFoldedName))
	for name := range byFoldedName {
		names = append(names, name)
	}
	sort.Strings(names)

	result := &entry{Type: "directory", Name: filepath.ToSlash(virtualName)}
	for _, folded := range names {
		candidate := byFoldedName[folded]
		fullPath := filepath.Join(path, candidate.Name())
		info, err := os.Stat(fullPath)
		if err != nil {
			return nil, err
		}
		if info.IsDir() {
			if candidate.Type()&os.ModeSymlink != 0 {
				return nil, fmt.Errorf("unsupported SDK directory symlink %s", fullPath)
			}
			child, err := directoryEntry(fullPath, candidate.Name())
			if err != nil {
				return nil, err
			}
			result.Contents = append(result.Contents, child)
			continue
		}
		if !info.Mode().IsRegular() {
			return nil, fmt.Errorf("unsupported SDK entry %s with mode %s", fullPath, info.Mode())
		}
		result.Contents = append(result.Contents, &entry{
			Type:             "file",
			Name:             candidate.Name(),
			ExternalContents: filepath.ToSlash(fullPath),
		})
	}
	return result, nil
}

func generate(roots []string) ([]byte, error) {
	if len(roots) == 0 {
		return nil, errors.New("at least one -root is required")
	}
	sort.Strings(roots)
	result := overlay{Version: 0, CaseSensitive: false, UseExternalNames: false}
	for _, root := range roots {
		item, err := directoryEntry(root, root)
		if err != nil {
			return nil, fmt.Errorf("walk %s: %w", root, err)
		}
		result.Roots = append(result.Roots, item)
	}
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(data, '\n'), nil
}

func main() {
	var roots stringList
	var output string
	flag.Var(&roots, "root", "SDK include directory to represent (repeatable)")
	flag.StringVar(&output, "output", "", "output VFS overlay path")
	flag.Parse()
	if output == "" {
		fmt.Fprintln(os.Stderr, "-output is required")
		os.Exit(2)
	}
	data, err := generate(roots)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if err := os.WriteFile(output, data, 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
