package fastdupefinder

import (
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/helpers"
	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
	"golang.org/x/sync/errgroup"
)

// Phase4FindDuplicateFolders identifies duplicate folders based on the file duplicates found.
// This version is optimized to run concurrently, significantly speeding up the analysis
// of large directory structures.
func Phase4FindDuplicateFolders(FileDuplicates map[string][]string) map[string][]string {
	status.UpdateDetailedStatus("phase4", 60.0, "Preparing to analyze folders", len(FileDuplicates), 0, 0, 0, "Files")

	// Step 1: Create a thread-safe reverse map for quick hash lookups (path -> hash).
	// This is needed for concurrent access in the next steps.
	pathToHashMap := &sync.Map{}
	fileCount := 0
	for hash, paths := range FileDuplicates {
		for _, path := range paths {
			pathToHashMap.Store(path, hash)
			fileCount++
		}
	}

	// Step 2: Identify all candidate folders and sort them by depth (deepest first).
	// Sorting deepest first is a key optimization that maximizes cache hits during
	// recursive signature calculation, making the concurrent processing more efficient.
	candidateFoldersSet := make(map[string]struct{})
	for _, paths := range FileDuplicates {
		for _, path := range paths {
			dir := filepath.Dir(path)
			candidateFoldersSet[dir] = struct{}{}
		}
	}

	candidateFolders := make([]string, 0, len(candidateFoldersSet))
	for dir := range candidateFoldersSet {
		candidateFolders = append(candidateFolders, dir)
	}

	sort.Slice(candidateFolders, func(i, j int) bool {
		return strings.Count(candidateFolders[i], string(os.PathSeparator)) > strings.Count(candidateFolders[j], string(os.PathSeparator))
	})

	// Step 3 & 4: Concurrently get signatures and group folders.
	// We use thread-safe maps and an errgroup to manage concurrent workers.
	folderSignatureCache := &sync.Map{}
	signatureToFoldersMap := struct {
		sync.Mutex
		m map[string][]string
	}{m: make(map[string][]string)}

	var processedFolders int64
	totalFolders := len(candidateFolders)
	var g errgroup.Group
	// Limit concurrency to a multiple of CPU cores to balance I/O and CPU work.
	g.SetLimit(runtime.NumCPU() * 2)

	for _, folderPath := range candidateFolders {
		fp := folderPath
		g.Go(func() error {
			// GetFolderSignature must be thread-safe.
			signature, isDuplicable := helpers.GetFolderSignature(fp, pathToHashMap, folderSignatureCache)
			if isDuplicable {
				signatureToFoldersMap.Lock()
				signatureToFoldersMap.m[signature] = append(signatureToFoldersMap.m[signature], fp)
				signatureToFoldersMap.Unlock()
			}

			// Atomically update progress for thread-safe reporting.
			currentProcessed := atomic.AddInt64(&processedFolders, 1)

			if currentProcessed%100 == 0 {
				progress := 60.0 + (float64(currentProcessed)/float64(totalFolders))*20.0 // Phase 4 runs from 60% to 80%
				status.UpdateDetailedStatus("phase4", progress, "Analyzing folders", fileCount, 0, int(currentProcessed), totalFolders, "Folders")
			}
			return nil
		})
	}

	// Wait for all folder processing goroutines to complete.
	if err := g.Wait(); err != nil {
		// In this implementation, goroutines don't return errors, but this is good practice.
	}

	// Step 5: Filter out unique folders (those with only one path for a signature).
	finalMap := make(map[string][]string)
	signatureToFoldersMap.Lock()
	defer signatureToFoldersMap.Unlock()
	for signature, paths := range signatureToFoldersMap.m {
		if len(paths) >= 2 {
			finalMap[signature] = paths
		}
	}

	return finalMap
}
