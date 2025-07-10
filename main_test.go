package main

import (
	"crypto/rand" // ADD THIS LINE
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"sort"
	"testing"
)

// --- Test Helper Functions ---

// createTestFile is a helper to create a file with specific content for a test.
func createTestFile(t *testing.T, path string, content string) {
	t.Helper()
	// Ensure parent directory exists
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatalf("Failed to create parent directory for %s: %v", path, err)
	}
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("Failed to write test file %s: %v", path, err)
	}
}

// createLargeTestFile helps create files for testing the partial hash logic.
func createLargeTestFile(t *testing.T, path string, size int, firstChunkByte, secondChunkByte byte) {
	t.Helper()
	content := make([]byte, size)
	// Fill the first part (which will be partially hashed)
	for i := 0; i < PartialHashSize; i++ {
		content[i] = firstChunkByte
	}
	// Fill the rest of the file
	for i := PartialHashSize; i < size; i++ {
		content[i] = secondChunkByte
	}
	createTestFile(t, path, string(content))
}

// ADD THIS NEW HELPER FUNCTION
// createComplexTestFile creates a test file with a distinct header and a
// payload that can be repeated to create large files.
func createComplexTestFile(t *testing.T, path string, header []byte, payload []byte, repeatPayload int) {
	t.Helper()

	// Ensure parent directory exists
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatalf("Failed to create parent directory for %s: %v", path, err)
	}

	file, err := os.Create(path)
	if err != nil {
		t.Fatalf("Failed to create test file %s: %v", path, err)
	}
	defer file.Close()

	// Write the header
	if _, err := file.Write(header); err != nil {
		t.Fatalf("Failed to write header to %s: %v", path, err)
	}

	// Write the repeated payload
	for i := 0; i < repeatPayload; i++ {
		if _, err := file.Write(payload); err != nil {
			t.Fatalf("Failed to write payload to %s: %v", path, err)
		}
	}
}

// --- Main Test Suite ---

func TestDuplicateFinder(t *testing.T) {
	t.Run("Simple Duplicates", func(t *testing.T) {
		tempDir := t.TempDir()
		pathA := filepath.Join(tempDir, "file_A.txt")
		pathB := filepath.Join(tempDir, "file_B.txt")
		pathC := filepath.Join(tempDir, "sub", "file_C.txt")

		createTestFile(t, pathA, "hello world")
		createTestFile(t, pathB, "unique file")
		createTestFile(t, pathC, "hello world")

		duplicates, err := runFinder(tempDir)
		if err != nil {
			t.Fatalf("runFinder failed: %v", err)
		}

		if len(duplicates) != 1 {
			t.Fatalf("Expected 1 set of duplicates, but got %d", len(duplicates))
		}

		for _, paths := range duplicates {
			sort.Strings(paths) // Sort for deterministic comparison
			expected := []string{pathA, pathC}
			sort.Strings(expected)
			if !reflect.DeepEqual(paths, expected) {
				t.Errorf("Expected duplicate set %v, but got %v", expected, paths)
			}
		}
	})

	t.Run("No Duplicates", func(t *testing.T) {
		tempDir := t.TempDir()
		createTestFile(t, filepath.Join(tempDir, "unique1.dat"), "abc")
		createTestFile(t, filepath.Join(tempDir, "unique2.dat"), "def")
		createTestFile(t, filepath.Join(tempDir, "unique3.dat"), "ghi")

		duplicates, err := runFinder(tempDir)
		if err != nil {
			t.Fatalf("runFinder failed: %v", err)
		}

		if len(duplicates) != 0 {
			t.Errorf("Expected 0 duplicates, but found %d", len(duplicates))
		}
	})

	// REPLACE THE OLD "Partial vs Full Hash Mismatch" t.Run BLOCK WITH THIS ONE

	t.Run("Large Files with Difference only at the End", func(t *testing.T) {
		tempDir := t.TempDir()
		pathA := filepath.Join(tempDir, "large_A.bin")
		pathB := filepath.Join(tempDir, "large_B.bin")

		// Create a large, identical first part that is > PARTIAL_HASH_SIZE
		// This will ensure they match in Phase 2.
		firstPart := make([]byte, PartialHashSize*2)
		if _, err := rand.Read(firstPart); err != nil {
			t.Fatalf("Failed to generate random data: %v", err)
		}

		// The "payload" will be the single byte that makes them different at the end.
		// We use createComplexTestFile with the large firstPart as the "header".
		createComplexTestFile(t, pathA, firstPart, []byte{'A'}, 1)
		createComplexTestFile(t, pathB, firstPart, []byte{'B'}, 1)

		duplicates, err := runFinder(tempDir)
		if err != nil {
			t.Fatalf("runFinder failed: %v", err)
		}

		if len(duplicates) != 0 {
			t.Errorf("Expected 0 duplicates, but found %d for large files that differ only at the very end", len(duplicates))
		}
	})

	t.Run("Ignores Special Files (Symlinks)", func(t *testing.T) {
		if runtime.GOOS == "windows" {
			t.Skip("Skipping symlink test on Windows as it requires special privileges")
		}
		tempDir := t.TempDir()
		pathA := filepath.Join(tempDir, "regular_file.txt")
		symlinkPath := filepath.Join(tempDir, "symlink_to_file")

		createTestFile(t, pathA, "i am a file")
		if err := os.Symlink(pathA, symlinkPath); err != nil {
			t.Fatalf("Failed to create symlink: %v", err)
		}

		duplicates, err := runFinder(tempDir)
		if err != nil {
			t.Fatalf("runFinder failed: %v", err)
		}

		if len(duplicates) != 0 {
			t.Errorf("Expected 0 duplicates, but found %d. The symlink might have been processed incorrectly.", len(duplicates))
		}
	})

	t.Run("Ignores Zero-Byte Files", func(t *testing.T) {
		tempDir := t.TempDir()
		createTestFile(t, filepath.Join(tempDir, "empty1.tmp"), "")
		createTestFile(t, filepath.Join(tempDir, "empty2.tmp"), "")
		createTestFile(t, filepath.Join(tempDir, "not_empty.txt"), "content")

		duplicates, err := runFinder(tempDir)
		if err != nil {
			t.Fatalf("runFinder failed: %v", err)
		}

		if len(duplicates) != 0 {
			t.Errorf("Expected 0 duplicates, but found %d. Zero-byte files might have been processed.", len(duplicates))
		}
	})

	// ADD THESE NEW t.Run BLOCKS INSIDE THE TestDuplicateFinder FUNCTION

	t.Run("Files with Identical Payload but Different Headers", func(t *testing.T) {
		tempDir := t.TempDir()
		headerA := []byte("HEADER_VERSION_1")
		headerB := []byte("HEADER_VERSION_2")

		// Generate a random payload to simulate binary data
		payload := make([]byte, 1024)
		if _, err := rand.Read(payload); err != nil {
			t.Fatalf("Failed to generate random payload: %v", err)
		}

		// Files have different headers, so they are not duplicates
		createComplexTestFile(t, filepath.Join(tempDir, "fileA.dat"), headerA, payload, 10)
		createComplexTestFile(t, filepath.Join(tempDir, "fileB.dat"), headerB, payload, 10)

		duplicates, err := runFinder(tempDir)
		if err != nil {
			t.Fatalf("runFinder failed: %v", err)
		}

		if len(duplicates) != 0 {
			t.Errorf("Expected 0 duplicates, but found %d. Files with different headers were incorrectly matched.", len(duplicates))
		}
	})

	t.Run("Files with Identical Headers but Different Payloads", func(t *testing.T) {
		tempDir := t.TempDir()
		header := []byte("COMMON_HEADER")

		payloadA := make([]byte, 1024)
		if _, err := rand.Read(payloadA); err != nil {
			t.Fatalf("Failed to generate random payload A: %v", err)
		}
		payloadB := make([]byte, 1024)
		if _, err := rand.Read(payloadB); err != nil {
			t.Fatalf("Failed to generate random payload B: %v", err)
		}

		// Files have different payloads, so they are not duplicates
		createComplexTestFile(t, filepath.Join(tempDir, "fileA.dat"), header, payloadA, 10)
		createComplexTestFile(t, filepath.Join(tempDir, "fileB.dat"), header, payloadB, 10)

		duplicates, err := runFinder(tempDir)
		if err != nil {
			t.Fatalf("runFinder failed: %v", err)
		}

		if len(duplicates) != 0 {
			t.Errorf("Expected 0 duplicates, but found %d. Files with different payloads were incorrectly matched.", len(duplicates))
		}
	})
}

// TestPhase3RaceCondition specifically tests the fix for files changing during scan.
func TestPhase3RaceCondition(t *testing.T) {
	tempDir := t.TempDir()
	pathA := filepath.Join(tempDir, "race_A.txt")
	pathB := filepath.Join(tempDir, "race_B.txt")

	// 1. Setup initial state: two identical files
	originalContent := "original content"
	createTestFile(t, pathA, originalContent)
	createTestFile(t, pathB, originalContent)

	// 2. Manually construct the input for Phase 3, as it would be after Phase 2
	// We need the partial hash and original size to create the key.
	partialHash, err := calculateHash(pathA, true)
	if err != nil {
		t.Fatalf("Could not calculate partial hash for test setup: %v", err)
	}
	originalSize := len(originalContent)
	key := fmt.Sprintf("%d-%s", originalSize, partialHash)
	candidates := map[string][]string{
		key: {pathA, pathB},
	}

	// 3. Simulate the race condition: modify one of the files *before* phase 3
	if err := os.WriteFile(pathB, []byte("modified content"), 0644); err != nil {
		t.Fatalf("Failed to modify test file to simulate race condition: %v", err)
	}

	// 4. Execute Phase 3
	duplicates := phase3FindDuplicatesByFullHash(candidates, runtime.NumCPU())

	// 5. Assert the result
	if len(duplicates) != 0 {
		t.Errorf("Expected 0 duplicates after race condition, but found %d. The size check failed.", len(duplicates))
	}
}
