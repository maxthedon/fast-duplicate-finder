package fastdupefinder

import (
	"fmt"
	"runtime"

	"github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/status"
)

// RunFinder orchestrates the entire duplicate finding process.
func RunFinder(RootDir string) (map[string][]string, map[string][]string, map[string][]string, map[string][]string, error) {
	return RunFinderWithConfig(RootDir, 0) // 0 means auto-detect
}

// RunFinderWithConfig orchestrates the entire duplicate finding process with custom CPU configuration.
// If cpuCores is 0 or negative, it will auto-detect and use all available CPU cores.
func RunFinderWithConfig(RootDir string, cpuCores int) (map[string][]string, map[string][]string, map[string][]string, map[string][]string, error) {
	// Determine number of workers
	var numWorkers int
	if cpuCores <= 0 {
		numWorkers = runtime.NumCPU() // Auto-detect
	} else {
		numWorkers = cpuCores
		// Ensure we don't exceed available CPUs
		if numWorkers > runtime.NumCPU() {
			numWorkers = runtime.NumCPU()
		}
	}

	// Reset cancellation flag at start
	SetCancelled(false)

	// Phase 1: Group by size (0-20%)
	status.UpdateStatus("phase1", 0.0, "Scanning files", 0, 0)
	if IsCancelled() {
		return nil, nil, nil, nil, fmt.Errorf("scan cancelled by user")
	}
	potentialDupesBySize := Phase1GroupBySize(RootDir, numWorkers)

	// Phase 2: Filter by partial hash (20-40%)
	status.UpdateStatus("phase2", 20.0, "Computing partial hashes", 0, 0)
	if IsCancelled() {
		return nil, nil, nil, nil, fmt.Errorf("scan cancelled by user")
	}
	potentialDupesByPartialHash := Phase2FilterByPartialHash(potentialDupesBySize, numWorkers)

	// Phase 3: Find duplicates by full hash (40-60%)
	status.UpdateStatus("phase3", 40.0, "Computing full hashes", 0, 0)
	if IsCancelled() {
		return nil, nil, nil, nil, fmt.Errorf("scan cancelled by user")
	}
	allFileDuplicates := Phase3FindDuplicatesByFullHash(potentialDupesByPartialHash, numWorkers)

	// Phase 4: Find duplicate folders (60-80%)
	status.UpdateStatus("phase4", 60.0, "Analyzing folders", len(allFileDuplicates), 0)
	if IsCancelled() {
		return nil, nil, nil, nil, fmt.Errorf("scan cancelled by user")
	}
	allFolderDuplicates := Phase4FindDuplicateFolders(allFileDuplicates)

	// Phase 5: Filter results (80-100%)
	status.UpdateStatus("phase5", 80.0, "Filtering results", len(allFileDuplicates), len(allFolderDuplicates))
	if IsCancelled() {
		return nil, nil, nil, nil, fmt.Errorf("scan cancelled by user")
	}
	filteredFileDuplicates, filteredFolderDuplicates := Phase5FilterResults(allFolderDuplicates, allFileDuplicates)

	// Final completion check
	if IsCancelled() {
		return nil, nil, nil, nil, fmt.Errorf("scan cancelled by user")
	}

	status.UpdateStatus("completed", 100.0, "Search completed", len(filteredFileDuplicates), len(filteredFolderDuplicates))

	return filteredFileDuplicates, filteredFolderDuplicates, allFileDuplicates, allFolderDuplicates, nil
}
