package fastdupefinder

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
)

// Global cancellation flag
var scanCancelled bool
var cancelMutex sync.RWMutex

// SetCancelled sets the cancellation flag
func SetCancelled(cancelled bool) {
	cancelMutex.Lock()
	defer cancelMutex.Unlock()
	scanCancelled = cancelled
}

// IsCancelled checks if scan is cancelled
func IsCancelled() bool {
	cancelMutex.RLock()
	defer cancelMutex.RUnlock()
	return scanCancelled
}

// Phase5FilterResults takes the results from the previous phases and filters out
// nested duplicate folders and files that are inside those folders.
func Phase5FilterResults(folderDuplicates map[string][]string, fileDuplicates map[string][]string) (map[string][]string, map[string][]string) {
	// Update progress with minimal logging
	status.UpdateDetailedStatus("phase5", 85.0, "Filtering nested duplicates", len(fileDuplicates), len(folderDuplicates), 0, len(fileDuplicates)+len(folderDuplicates), "Duplicates")

	// Check for cancellation early
	if IsCancelled() {
		return make(map[string][]string), make(map[string][]string)
	}

	// Filter folders first
	filteredFolderDuplicates := filterNestedFolders(folderDuplicates)

	// Check for cancellation before processing files
	if IsCancelled() {
		return make(map[string][]string), make(map[string][]string)
	}

	// Filter files using the filtered folders
	filteredFilesInDuplicateFolders := filterFilesWithinDuplicateFolders(fileDuplicates, filteredFolderDuplicates)

	return filteredFilesInDuplicateFolders, filteredFolderDuplicates
}

// filterNestedFolders takes a map of duplicate folders and removes any sets
// that are subdirectories of another duplicate folder set.
// For example, if ["/a/src", "/b/src"] is a duplicate set, and
// ["/a/src/utils", "/b/src/utils"] is another, this function will
// remove the latter set, keeping only the top-level one.
func filterNestedFolders(folderDuplicates map[string][]string) map[string][]string {
	// Step 1: Create a master set of all individual duplicate folder paths for quick lookups.
	// Using a map[string]struct{} is the idiomatic way to create a set in Go.
	allDuplicatePaths := make(map[string]struct{})
	for _, paths := range folderDuplicates {
		for _, path := range paths {
			// Clean the path to handle cases like "dir/." vs "dir"
			cleanedPath := filepath.Clean(path)
			allDuplicatePaths[cleanedPath] = struct{}{}
		}
	}

	// Step 2: Iterate through the original duplicate sets and decide which ones to keep.
	filteredResults := make(map[string][]string)

	for signature, paths := range folderDuplicates {
		// We only need to check one path from the set, as all paths in a set
		// share the same parent-child relationship with other sets.
		if len(paths) == 0 {
			continue // Should not happen, but defensive check.
		}
		pathToCheck := filepath.Clean(paths[0])

		// Walk upwards from the current path to see if any of its parents
		// are also in the master set of duplicate folders.
		isNested := false
		parent := filepath.Dir(pathToCheck)

		// Loop until we reach the root of the filesystem (e.g., filepath.Dir("/") is "/").
		for parent != pathToCheck {
			if _, exists := allDuplicatePaths[parent]; exists {
				// This folder's parent is also a duplicate. Therefore, this set is nested.
				isNested = true
				break // No need to check further up.
			}
			pathToCheck = parent
			parent = filepath.Dir(pathToCheck)
		}

		// Step 3: If the set was not found to be nested, add it to our final results.
		if !isNested {
			filteredResults[signature] = paths
		}
	}

	return filteredResults
}

// filterFilesWithinDuplicateFolders removes file duplicates that exist inside
// the folders that have already been identified as top-level duplicates.
// This helps to de-clutter the final report, as users are typically more
// interested in the duplicate folders themselves rather than every file inside them.
func filterFilesWithinDuplicateFolders(
	fileDuplicates map[string][]string,
	filteredFolderDuplicates map[string][]string,
) map[string][]string {

	// Step 1: Create a fast lookup set of all top-level duplicate folder paths.
	// We add a path separator to the end to ensure we only match directories,
	// preventing false positives where a file path might share a prefix with a
	// folder name (e.g., /data/project vs /data/project-archive).
	duplicateFolderSet := make(map[string]struct{})
	for _, paths := range filteredFolderDuplicates {
		for _, path := range paths {
			// Ensure path is clean and has a trailing separator for prefix matching.
			folderPrefix := filepath.Clean(path) + string(os.PathSeparator)
			duplicateFolderSet[folderPrefix] = struct{}{}
		}
	}

	// If there are no duplicate folders, there's nothing to filter.
	if len(duplicateFolderSet) == 0 {
		return fileDuplicates
	}

	// Step 2: Build the new map of file duplicates, excluding the nested files.
	// Use goroutines to process in parallel for better performance
	finalFileDuplicates := make(map[string][]string)
	var mu sync.Mutex
	var wg sync.WaitGroup

	// Convert map keys to slice for easier distribution
	hashes := make([]string, 0, len(fileDuplicates))
	for hash := range fileDuplicates {
		hashes = append(hashes, hash)
	}

	// Use more workers for better performance, but limit to avoid overwhelming the system
	numWorkers := runtime.NumCPU()
	if numWorkers > len(hashes) {
		numWorkers = len(hashes) // Don't create more workers than we have work
	}
	if numWorkers > 8 {
		numWorkers = 8 // Cap at 8 workers to avoid too much overhead
	}
	if numWorkers == 0 {
		numWorkers = 1
	}

	// Create work channel
	hashChan := make(chan string, numWorkers*2) // Buffered channel for better performance

	// Send all hashes to the channel
	go func() {
		defer close(hashChan)
		for _, hash := range hashes {
			if IsCancelled() {
				return
			}
			hashChan <- hash
		}
	}()

	// Start worker goroutines
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			localResults := make(map[string][]string)

			for hash := range hashChan {
				// Check for cancellation periodically
				if IsCancelled() {
					return
				}

				paths := fileDuplicates[hash]
				var keptPaths []string

				// Filter out files that are inside duplicate folders
				for _, filePath := range paths {
					isNested := false
					// Check if the file's path starts with any of the duplicate folder paths.
					for folderPrefix := range duplicateFolderSet {
						if strings.HasPrefix(filePath, folderPrefix) {
							isNested = true
							break // The file is inside a duplicate folder; no need to check others.
						}
					}

					// If the file is not nested within any duplicate folder, add it to our list.
					if !isNested {
						keptPaths = append(keptPaths, filePath)
					}
				}

				// After filtering, if the group still has more than one file,
				// it's still a valid set of duplicates. Add it to the local results.
				if len(keptPaths) > 1 {
					localResults[hash] = keptPaths
				}
			}

			// Merge local results with final results (less frequent locking)
			if len(localResults) > 0 {
				mu.Lock()
				for hash, paths := range localResults {
					finalFileDuplicates[hash] = paths
				}
				mu.Unlock()
			}
		}()
	}

	wg.Wait()

	// Check for cancellation one final time
	if IsCancelled() {
		return make(map[string][]string)
	}

	return finalFileDuplicates
}
