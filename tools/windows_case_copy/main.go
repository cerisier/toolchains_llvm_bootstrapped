package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

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

func copyFile(source, destination string) error {
	input, err := os.Open(source)
	if err != nil {
		return err
	}
	defer input.Close()
	output, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	if _, err := io.Copy(output, input); err != nil {
		output.Close()
		return err
	}
	return output.Close()
}

func copyDirectory(source, destination string) error {
	if err := os.MkdirAll(destination, 0o755); err != nil {
		return err
	}
	entries, err := os.ReadDir(source)
	if err != nil {
		return err
	}
	byFoldedName := make(map[string]os.DirEntry, len(entries))
	for _, candidate := range entries {
		folded := strings.ToLower(candidate.Name())
		current, exists := byFoldedName[folded]
		if !exists {
			byFoldedName[folded] = candidate
			continue
		}
		preferred, err := preferredName(current.Name(), candidate.Name())
		if err != nil {
			return fmt.Errorf("%s: %w", source, err)
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
	for _, folded := range names {
		candidate := byFoldedName[folded]
		sourcePath := filepath.Join(source, candidate.Name())
		info, err := os.Stat(sourcePath)
		if err != nil {
			return err
		}
		if info.IsDir() {
			if err := copyDirectory(sourcePath, filepath.Join(destination, candidate.Name())); err != nil {
				return err
			}
			continue
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("unsupported SDK entry %s with mode %s", sourcePath, info.Mode())
		}
		if err := copyFile(sourcePath, filepath.Join(destination, folded)); err != nil {
			return err
		}
	}
	return nil
}

func main() {
	var source, output string
	flag.StringVar(&source, "source", "", "source directory")
	flag.StringVar(&output, "output", "", "output directory")
	flag.Parse()
	if source == "" || output == "" {
		fmt.Fprintln(os.Stderr, "-source and -output are required")
		os.Exit(2)
	}
	if err := copyDirectory(source, output); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
