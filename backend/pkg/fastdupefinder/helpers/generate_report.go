package helpers

import (
	"log"
	"os"
	"path/filepath"
	"sort"

	reporttypes "github.com/maxthedon/fast-dupe-finder/pkg/fastdupefinder/types/report_types"
)

// calculateFolderSize calculates the total size of all files in a folder recursively.
func calculateFolderSize(folderPath string) int64 {
	var totalSize int64

	err := filepath.Walk(folderPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			// Skip files/folders we can't access
			return nil
		}
		if !info.IsDir() {
			totalSize += info.Size()
		}
		return nil
	})

	if err != nil {
		log.Printf("Warning: Could not calculate size for folder %s: %v", folderPath, err)
		return 0
	}

	return totalSize
}

// GenerateReport formats all findings into a optimized JSON structure.
// Focuses on essential data while minimizing memory usage and generation time.
func GenerateReport(
	filteredFileDuplicates,
	filteredFolderDuplicates,
	allFileDuplicates,
	allFolderDuplicates map[string][]string) reporttypes.ReportOutput {

	// Helper function to convert a map of file duplicates to a slice of FileSet.
	// Truncates hash to 12 characters to save memory (sufficient for display).
	convertFileMapToSets := func(dupes map[string][]string) ([]reporttypes.FileSet, int64) {
		var totalWasted int64 = 0
		sets := make([]reporttypes.FileSet, 0, len(dupes))
		for hash, paths := range dupes {
			var sizeBytes int64
			if len(paths) > 0 {
				info, err := os.Stat(paths[0])
				if err == nil {
					sizeBytes = info.Size()
					// Wasted space is (count - 1) * size for this set
					if len(paths) > 1 {
						totalWasted += sizeBytes * int64(len(paths)-1)
					}
				} else {
					log.Printf("Warning: Could not stat file %s to get size: %v", paths[0], err)
					sizeBytes = -1 // Indicate error
				}
			}
			// Truncate hash to first 12 characters to save memory
			truncatedHash := hash
			if len(hash) > 12 {
				truncatedHash = hash[:12]
			}
			sets = append(sets, reporttypes.FileSet{
				Hash:      truncatedHash,
				Paths:     paths,
				SizeBytes: sizeBytes,
			})
		}
		// Sort by hash for deterministic output
		sort.Slice(sets, func(i, j int) bool { return sets[i].Hash < sets[j].Hash })
		return sets, totalWasted
	}

	// Helper function to convert a map of folder duplicates to a slice of FolderSet.
	// Truncates signature to 12 characters to save memory.
	convertFolderMapToSets := func(dupes map[string][]string) []reporttypes.FolderSet {
		sets := make([]reporttypes.FolderSet, 0, len(dupes))
		for signature, paths := range dupes {
			// Calculate folder size by getting the size of the first folder
			var sizeBytes int64
			if len(paths) > 0 {
				sizeBytes = calculateFolderSize(paths[0])
			}
			// Truncate signature to first 12 characters to save memory
			truncatedSignature := signature
			if len(signature) > 12 {
				truncatedSignature = signature[:12]
			}
			sets = append(sets, reporttypes.FolderSet{
				Signature: truncatedSignature,
				Paths:     paths,
				SizeBytes: sizeBytes,
			})
		}
		// Sort by signature for deterministic output
		sort.Slice(sets, func(i, j int) bool { return sets[i].Signature < sets[j].Signature })
		return sets
	}

	// Generate only the essential data - no raw data to save memory
	finalFileSets, wastedSpace := convertFileMapToSets(filteredFileDuplicates)
	topLevelFolderSets := convertFolderMapToSets(filteredFolderDuplicates)

	// Assemble the optimized JSON object with minimal fields
	return reporttypes.ReportOutput{
		Summary: reporttypes.SummaryInfo{
			FileSets:         len(filteredFileDuplicates),
			FolderSets:       len(filteredFolderDuplicates),
			WastedSpaceBytes: wastedSpace,
		},
		FileDuplicates:   finalFileSets,
		FolderDuplicates: topLevelFolderSets,
	}
}
